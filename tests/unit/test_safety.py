import importlib.util
from pathlib import Path
import unittest
import http.client
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import threading
import urllib.parse
import sys
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))


def module(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "scripts" / f"{name}.py")
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


class SafetyTests(unittest.TestCase):
    def test_inherited_profiles_and_cli_overrides_are_removed(self):
        local = module("local")
        with patch.dict(local.os.environ, {"AWS_PROFILE": "forbidden-test-profile", "AWS_SESSION_TOKEN": "not-for-use", "TF_CLI_ARGS_plan": "-var=unsafe=true"}):
            env = local.local_env()
        self.assertNotIn("AWS_PROFILE", env)
        self.assertNotIn("AWS_SESSION_TOKEN", env)
        self.assertNotIn("TF_CLI_ARGS_plan", env)
        self.assertEqual(env["AWS_CONFIG_FILE"], local.os.devnull)
        self.assertEqual(env["AWS_SHARED_CREDENTIALS_FILE"], local.os.devnull)
        self.assertEqual(env["AWS_REGION"], "ca-central-1")

    def test_aws_commands_fail_before_execution_without_local_context(self):
        local = module("local")
        with patch.object(local.subprocess, "run") as execute:
            for args in (["aws", "sts", "get-caller-identity"],
                         ["aws", "--endpoint-url", "https://ec2.ca-central-1.amazonaws.com", "--region", "ca-central-1", "ec2", "describe-vpcs"],
                         ["aws", "--endpoint-url", "http://localhost:4567", "--region", "us-east-1", "ec2", "describe-vpcs"]):
                with self.subTest(args=args), self.assertRaises((RuntimeError, ValueError)):
                    local.run(args)
            execute.assert_not_called()

    def test_proxy_forwards_only_selected_loopback(self):
        local = module("local")
        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass
            def do_GET(self):
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"local-only")
        server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        try:
            with local.local_proxy(f"http://localhost:{server.server_port}"):
                proxy = urllib.parse.urlsplit(local.PROXY_URL)
                for target, expected in [(f"http://000000000000.localhost:{server.server_port}/", 200),
                                         ("http://s3.ca-central-1.amazonaws.com/", 403),
                                         ("http://localhost:1/", 403)]:
                    connection = http.client.HTTPConnection(proxy.hostname, proxy.port)
                    connection.request("GET", target)
                    response = connection.getresponse()
                    self.assertEqual(response.status, expected)
                    response.read()
                    connection.close()
        finally:
            server.shutdown()
            server.server_close()

    def test_local_endpoint_rejects_remote_and_ambiguous_urls(self):
        local = module("local")
        for url in ["https://ec2.ca-central-1.amazonaws.com", "http://127.0.0.1.evil:4566", "http://user@localhost:4566", "http://localhost:4566/path", "http://localhost", "http://localhost:4566?x=1"]:
            with self.subTest(url=url), self.assertRaises(ValueError):
                local.endpoint(url)
        self.assertEqual(local.endpoint("http://localhost:4566"), "http://localhost:4566")

    def test_environment_uses_fake_credentials(self):
        env = module("local").local_env()
        self.assertEqual(env["AWS_ACCESS_KEY_ID"], "test")
        self.assertEqual(env["AWS_SECRET_ACCESS_KEY"], "test")
        self.assertNotIn("AWS_PROFILE", env)
        self.assertNotIn("AWS_SESSION_TOKEN", env)
        self.assertEqual(env["HTTPS_PROXY"], "http://127.0.0.1:9")
        self.assertEqual(env["NO_PROXY"], "localhost,127.0.0.1")

    def test_deployment_fail_closed(self):
        gate = module("deployment_gate").validate
        valid = ["true", "prod", "refs/heads/main", "123456789012", "true"]
        gate(*valid)
        for index, bad in [(0, ""), (0, "false"), (1, "local"), (2, "refs/heads/develop"), (3, "000000000000"), (4, "false")]:
            args = valid.copy()
            args[index] = bad
            with self.subTest(args=args), self.assertRaises(ValueError):
                gate(*args)


if __name__ == "__main__":
    unittest.main()
