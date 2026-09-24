"""Isolated Floci lifecycle. Never loads AWS profiles or calls public AWS endpoints."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import urllib.parse
import http.client
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import threading
from contextlib import contextmanager
from drift import write_reports

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / ".local"
SERVICES = ["ec2", "elbv2", "acm", "rds", "elasticache", "s3", "s3control", "cloudfront", "secretsmanager", "logs", "iam", "sts", "route53", "kms"]
PROXY_URL = None


@contextmanager
def local_proxy(url):
    """Resolve SDK account-prefixed localhost names without DNS/hosts changes.

    Every forwarded byte goes to the explicitly selected loopback port.
    Public HTTP hosts and all HTTPS CONNECT requests are refused.
    """
    global PROXY_URL
    target = urllib.parse.urlsplit(endpoint(url))

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def forward(self):
            request = urllib.parse.urlsplit(self.path)
            if request.scheme != "http" or request.hostname not in ("localhost", "127.0.0.1", "000000000000.localhost", "000000000000.127.0.0.1") or request.port != target.port:
                self.send_error(403, "Only the selected Floci loopback endpoint is permitted")
                return
            if self.headers.get("Transfer-Encoding"):
                self.send_error(501, "Chunked proxy uploads are not supported by this test harness")
                return
            body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
            headers = {k: v for k, v in self.headers.items() if k.lower() not in ("proxy-connection", "connection")}
            connection = http.client.HTTPConnection("127.0.0.1", target.port, timeout=30)
            try:
                path = request.path + ("?" + request.query if request.query else "")
                connection.request(self.command, path, body=body, headers=headers)
                response = connection.getresponse()
                data = response.read()
                self.send_response(response.status)
                for key, value in response.getheaders():
                    if key.lower() not in ("transfer-encoding", "connection", "content-length"):
                        self.send_header(key, value)
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                if self.command != "HEAD":
                    self.wfile.write(data)
            except (OSError, http.client.HTTPException):
                self.send_error(502, "Selected Floci endpoint unavailable")
            finally:
                connection.close()

        do_GET = do_POST = do_PUT = do_DELETE = do_HEAD = do_PATCH = forward

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    PROXY_URL = f"http://127.0.0.1:{server.server_port}"
    try:
        yield
    finally:
        PROXY_URL = None
        server.shutdown()
        server.server_close()


def local_env():
    env = {k: v for k, v in os.environ.items() if not k.upper().startswith(("AWS_", "TF_VAR_", "TF_CLI_ARGS")) and k.upper() != "TF_CLI_CONFIG_FILE"}
    env.update(AWS_ACCESS_KEY_ID="test", AWS_SECRET_ACCESS_KEY="test", AWS_DEFAULT_REGION="ca-central-1",
               AWS_REGION="ca-central-1", AWS_EC2_METADATA_DISABLED="true", AWS_CONFIG_FILE=os.devnull,
               AWS_SHARED_CREDENTIALS_FILE=os.devnull, AWS_PAGER="", TF_IN_AUTOMATION="1",
               HTTP_PROXY="http://127.0.0.1:9", HTTPS_PROXY="http://127.0.0.1:9", NO_PROXY="localhost,127.0.0.1")
    if PROXY_URL:
        env.update(HTTP_PROXY=PROXY_URL, NO_PROXY="")
    env.update(http_proxy=env["HTTP_PROXY"], https_proxy=env["HTTPS_PROXY"], no_proxy=env["NO_PROXY"])
    return env


def endpoint(value):
    parsed = urllib.parse.urlsplit(value)
    if parsed.scheme != "http" or parsed.hostname not in ("localhost", "127.0.0.1") or not parsed.port or parsed.path not in ("", "/") or parsed.username or parsed.query or parsed.fragment:
        raise ValueError("Only an explicit HTTP loopback endpoint with a port is permitted")
    return value.rstrip("/")


def run(args, cwd=ROOT, capture=False, allowed=(0,), extra_env=None):
    env = local_env()
    if args[0] == "aws":
        if "--endpoint-url" not in args or "--region" not in args or "--profile" in args:
            raise RuntimeError("AWS-compatible commands require explicit local endpoint/region and no profile")
        endpoint(args[args.index("--endpoint-url") + 1])
        if args[args.index("--region") + 1] != "ca-central-1":
            raise RuntimeError("Local commands must use ca-central-1")
    if args[0] == "terraform" and args[1] in ("apply", "destroy", "plan"):
        directory = Path(cwd)
        owner = json.loads((directory / "owner.json").read_text())
        check_owner(directory, endpoint(owner["endpoint"]))
        expected = provider_config(owner["environment"].removeprefix("bootstrap-"), owner["endpoint"])
        if json.loads((directory / "providers.tf.json").read_text()) != expected or (directory / "backend.tf").exists():
            raise RuntimeError("Unsafe local provider/backend configuration")
        print(f"Local safety: {owner['endpoint']} | fake credentials | ca-central-1 | no AWS profiles", flush=True)
    if env["AWS_ACCESS_KEY_ID"] != "test" or env["AWS_SECRET_ACCESS_KEY"] != "test" or "AWS_PROFILE" in env:
        raise RuntimeError("Unsafe local credentials")
    # Docker emits normal progress on stderr; combine it for streamed logs so
    # Windows PowerShell does not turn successful progress into NativeCommandError.
    output_options = {"capture_output": True} if capture else {"stderr": subprocess.STDOUT}
    result = subprocess.run(args, cwd=cwd, env=env | (extra_env or {}), text=True, **output_options)
    if result.returncode not in allowed:
        if capture:
            print(result.stdout, result.stderr, file=sys.stderr)
        raise RuntimeError(f"Command failed ({result.returncode}): {' '.join(map(str, args))}")
    return result


def aws(url, service, *args):
    return json.loads(run(["aws", "--endpoint-url", endpoint(url), "--region", "ca-central-1", "--output", "json", service, *args], capture=True).stdout or "{}")


def provider_config(environment, url):
    return {"provider": {"aws": {
        "region": "ca-central-1", "access_key": "test", "secret_key": "test",
        "skip_credentials_validation": True, "skip_metadata_api_check": True,
        "skip_requesting_account_id": False, "s3_use_path_style": True,
        "allowed_account_ids": ["000000000000"],
        "endpoints": [{service: url for service in SERVICES}],
        "default_tags": [{"tags": {"Project": "pmp", "Environment": environment, "ManagedBy": "Terraform"}}]
    }}}


def prepare(environment, url):
    directory = WORK / environment
    directory.mkdir(parents=True, exist_ok=True)
    if (directory / "terraform.tfstate").exists():
        state = json.loads((directory / "terraform.tfstate").read_text())
        if state.get("resources"):
            raise RuntimeError("Existing local resources: clean up before preparing another run")
    for source in ROOT.glob("*.tf"):
        if source.name not in ("backend.tf", "providers.tf"):
            shutil.copy2(source, directory / source.name)
    for name in ("modules", "templates"):
        shutil.copytree(ROOT / name, directory / name, dirs_exist_ok=True)
    shutil.copy2(ROOT / ".terraform.lock.hcl", directory / ".terraform.lock.hcl")
    shutil.copy2(ROOT / "environments" / environment / "terraform.tfvars", directory / "terraform.tfvars")
    (directory / "providers.tf.json").write_text(json.dumps(provider_config(environment, url), indent=2))
    (directory / "local.auto.tfvars.json").write_text(json.dumps({
        "account_id": "000000000000", "ami_id": "ami-00000000000000000", "domain_name": "example.test",
        "hosted_zone_id": "ZLOCAL", "workload_boundary_arn": "arn:aws:iam::000000000000:policy/local-boundary"
    }, indent=2))
    # Disposal is local-only. AWS PROD protections remain unchanged in source.
    (directory / "modules/ingress/local_override.tf.json").write_text(json.dumps({"resource": {"aws_lb": {"this": {"enable_deletion_protection": False}}}}))
    (directory / "modules/network/local_override.tf.json").write_text(json.dumps({"resource": {"aws_subnet": {"this": {"availability_zone_id": '${replace(each.value.az, "cac1-", "ca-central-1-")}'}}}}))
    data_overrides = {"resource": {
        "aws_db_instance": {"this": {"deletion_protection": False, "skip_final_snapshot": True}},
        "aws_secretsmanager_secret": {"application": {"recovery_window_in_days": 0}},
        "aws_elasticache_user": {"default": {"count": 0}, "app": {"count": 0}},
        "aws_elasticache_user_group": {"this": {"count": 0, "user_ids": []}},
        "aws_elasticache_replication_group": {"this": {"user_group_ids": []}}
    }, "output": {"redis_iam_resources": {"value": ["${aws_elasticache_replication_group.this.arn}"]}}}
    (directory / "modules/data/local_override.tf.json").write_text(json.dumps(data_overrides))
    (directory / "local_fixtures.tf.json").write_text(json.dumps({"resource": {"aws_route53_zone": {"local": {"name": "example.test"}}}}))
    (directory / "ingress_override.tf.json").write_text(json.dumps({"module": {"ingress": {"zone_id": "${aws_route53_zone.local.zone_id}"}}}))
    (directory / "owner.json").write_text(json.dumps({"endpoint": url, "environment": environment}))
    return directory


def check_owner(directory, url):
    resolved = directory.resolve()
    if not resolved.is_relative_to(WORK.resolve()):
        raise RuntimeError("Working directory escapes .local")
    owner = json.loads((directory / "owner.json").read_text())
    if owner["endpoint"] != url:
        raise RuntimeError("Endpoint does not match resource ownership")


def cleanup(environment, url):
    directory = WORK / environment
    check_owner(directory, url)
    # Floci 2.1.0 returns UserNotFoundFault, whereas the provider expects
    # UserNotFound. Forget only a user whose absence was explicitly verified.
    state_file = directory / "terraform.tfstate"
    if state_file.exists():
        state = json.loads(state_file.read_text())
        for resource in state.get("resources", []):
            if resource["type"] != "aws_elasticache_user":
                continue
            for instance in resource["instances"]:
                user = instance["attributes"]["id"]
                result = run(["aws", "--endpoint-url", url, "--region", "ca-central-1", "elasticache", "describe-users", "--user-id", user], capture=True, allowed=(0, 254))
                if result.returncode == 254 and "UserNotFoundFault" in result.stderr:
                    address = f'{resource["module"]}.aws_elasticache_user.{resource["name"]}'
                    run(["terraform", "state", "rm", address], cwd=directory)
    run(["terraform", "destroy", "-auto-approve", "-input=false", "-no-color"], cwd=directory)


def capabilities(url):
    checks = {"ec2": ["describe-vpcs"], "s3api": ["list-buckets"], "elbv2": ["describe-load-balancers"],
              "rds": ["describe-db-instances"], "elasticache": ["describe-replication-groups"],
              "cloudfront": ["list-distributions"], "acm": ["list-certificates"],
              "secretsmanager": ["list-secrets"], "logs": ["describe-log-groups"], "iam": ["list-roles"]}
    report = {}
    for service, args in checks.items():
        aws(url, service, *args)
        report[service] = "read API responsive; provisioning not established"
    print(json.dumps(report, indent=2))


def integration(environment, url):
    if urllib.parse.urlsplit(url).port == 4566:
        raise RuntimeError("Lifecycle tests require dedicated Floci; port 4566 is reserved for existing user resources")
    ensure_emulator(url)
    directory = prepare(environment, url)
    run(["terraform", "init", "-input=false", "-no-color", f"-plugin-dir={ROOT / '.terraform/providers'}"], cwd=directory)
    try:
        run(["terraform", "apply", "-auto-approve", "-input=false", "-no-color", "-parallelism=4"], cwd=directory)
        run([sys.executable, str(ROOT / "tests/integration/assertions.py"), url, environment])
        run([sys.executable, str(ROOT / "tests/integration/protocols.py"), url, environment])
        plan = run(["terraform", "plan", "-input=false", "-no-color", "-detailed-exitcode", "-out=drift.tfplan"], cwd=directory, allowed=(0, 2))
        result = json.loads(run(["terraform", "show", "-json", "drift.tfplan"], cwd=directory, capture=True).stdout)
        counts = write_reports(result, directory)
        if counts["unexpected"]:
            raise RuntimeError("Unexpected drift detected; inspect sanitized drift-details.json")
        print("PASS: unexpected drift gate (known Floci incompatibilities are not AWS drift)", flush=True)
    finally:
        cleanup(environment, url)
    print(f"PASS: {environment} Floci integration and cleanup", flush=True)


def ensure_emulator(url):
    port = urllib.parse.urlsplit(endpoint(url)).port
    if port == 4566:
        raise RuntimeError("The existing user emulator is never managed by lifecycle tests")
    run(["docker", "compose", "-p", "pmp-integration", "-f", "compose.floci.yml", "up", "-d", "--wait", "--wait-timeout", "120"], extra_env={"FLOCI_PORT": str(port)})


def bootstrap_integration(environment, url):
    if urllib.parse.urlsplit(url).port == 4566:
        raise RuntimeError("Bootstrap tests also require the dedicated Floci instance")
    ensure_emulator(url)
    name = f"bootstrap-{environment}"
    directory = WORK / name
    directory.mkdir(parents=True, exist_ok=True)
    state = directory / "terraform.tfstate"
    if state.exists() and json.loads(state.read_text()).get("resources"):
        raise RuntimeError("Bootstrap test resources remain; use cleanup-bootstrap first")
    for file in (ROOT / "bootstrap").iterdir():
        if file.is_file() and file.name not in ("providers.tf", "backend.tf"):
            shutil.copy2(file, directory / file.name)
    (directory / "providers.tf.json").write_text(json.dumps(provider_config(environment, url)))
    (directory / "local.auto.tfvars.json").write_text(json.dumps({"environment": environment, "account_id": "000000000000", "github_repository": "example/aws-multi-vpc-platform", "hosted_zone_id": "ZLOCAL"}))
    (directory / "local_override.tf.json").write_text(json.dumps({"resource": {
        "aws_s3_bucket": {"state": {"lifecycle": {"prevent_destroy": False}}},
        "aws_kms_key": {"state": {"lifecycle": {"prevent_destroy": False}, "deletion_window_in_days": 7}}
    }}))
    (directory / "owner.json").write_text(json.dumps({"endpoint": url, "environment": name}))
    run(["terraform", "init", "-input=false", "-no-color", f"-plugin-dir={ROOT / '.terraform/providers'}"], cwd=directory)
    try:
        run(["terraform", "apply", "-auto-approve", "-input=false", "-no-color"], cwd=directory)
        bucket = f"state-pmp-{environment}-00000000000001-ca-central-1"
        assert aws(url, "s3api", "get-bucket-versioning", "--bucket", bucket)["Status"] == "Enabled"
        assert all(aws(url, "s3api", "get-public-access-block", "--bucket", bucket)["PublicAccessBlockConfiguration"].values())
        rules = aws(url, "s3api", "get-bucket-encryption", "--bucket", bucket)["ServerSideEncryptionConfiguration"]["Rules"]
        assert rules[0]["ApplyServerSideEncryptionByDefault"]["SSEAlgorithm"] == "aws:kms"
        policy = json.loads(aws(url, "s3api", "get-bucket-policy", "--bucket", bucket)["Policy"])
        statements = {statement["Sid"]: statement for statement in policy["Statement"]}
        assert statements["RequireKmsEncryption"]["Condition"]["StringNotEquals"]["s3:x-amz-server-side-encryption"] == "aws:kms"
        assert statements["RequireStateKmsKey"]["Condition"]["ArnNotEquals"]["s3:x-amz-server-side-encryption-aws-kms-key-id"] == rules[0]["ApplyServerSideEncryptionByDefault"]["KMSMasterKeyID"]
        print("PASS: local bootstrap encryption/versioning/public-access/KMS-policy configuration (not enforcement proof)")
    finally:
        cleanup(name, url)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["preflight", "capabilities", "integration", "bootstrap", "cleanup", "cleanup-bootstrap", "assert-clean"])
    parser.add_argument("--endpoint", default="http://localhost:4566")
    parser.add_argument("--environment", choices=["dev", "prod"], default="dev")
    parser.add_argument("--read-only", action="store_true")
    parser.add_argument("--owned-only", action="store_true")
    args = parser.parse_args()
    url = endpoint(args.endpoint)
    with local_proxy(url):
        dispatch(args, url)


def dispatch(args, url):
    if args.command == "preflight":
        for tool in ("terraform", "aws", "docker"):
            if not shutil.which(tool):
                raise RuntimeError(f"Missing {tool}")
        aws(url, "ec2", "describe-vpcs")
        print("Local endpoint and required commands available")
    elif args.command == "capabilities":
        capabilities(url)
    elif args.command == "integration":
        integration(args.environment, url)
    elif args.command == "bootstrap":
        bootstrap_integration(args.environment, url)
    elif args.command in ("cleanup", "cleanup-bootstrap"):
        if not args.owned_only:
            raise RuntimeError("Cleanup requires --owned-only")
        cleanup(f"bootstrap-{args.environment}" if args.command == "cleanup-bootstrap" else args.environment, url)
    else:
        for file in WORK.glob("*/terraform.tfstate"):
            if json.loads(file.read_text()).get("resources"):
                raise RuntimeError(f"Resources remain in {file}")
        print("Local Terraform states have no remaining resources")


if __name__ == "__main__":
    main()
