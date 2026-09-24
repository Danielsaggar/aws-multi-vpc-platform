"""Ensure drift diagnostics never emit sensitive values or hide replacement deltas."""
from pathlib import Path
import sys
import unittest
import copy

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
from drift import differences, analyze


def resource(kind, before, after, actions=None, replace_paths=None, unknown=None):
    return {"address": f"module.compute.{kind}.app[\"frontsite-1\"]", "type": kind, "index": "frontsite-1",
            "change": {"before": before, "after": after, "actions": actions or ["update"],
                       "replace_paths": replace_paths or [], "after_unknown": unknown or {},
                       "before_sensitive": {}, "after_sensitive": {}}}


def ec2():
    return resource("aws_instance", {"id": "i-local", "root_block_device": [{"encrypted": False}]},
                    {"root_block_device": [{"encrypted": True}]}, ["delete", "create"],
                    [["root_block_device", 0, "encrypted"]], {"id": True})


def known(item):
    return analyze({"resource_changes": [item]})[0]["classification"] == "known_emulator_incompatibility"


class DriftTests(unittest.TestCase):
    def test_iam_boundary_only_is_accepted(self):
        self.assertTrue(known(resource("aws_iam_role", {"permissions_boundary": ""},
                                       {"permissions_boundary": "arn:aws:iam::000000000000:policy/local-boundary"})))

    def test_iam_trust_policy_is_rejected_and_redacted(self):
        item = resource("aws_iam_role", {"assume_role_policy": "old-private"}, {"assume_role_policy": "new-private"})
        report = analyze({"resource_changes": [item]})[0]
        self.assertEqual(report["classification"], "UNEXPECTED")
        self.assertNotIn("private", str(report))

    def test_ec2_encryption_replacement_is_accepted(self):
        self.assertTrue(known(ec2()))

    def test_ec2_ami_is_rejected(self):
        self.assert_ec2_change_rejected("ami", "ami-old", "ami-new")

    def test_ec2_instance_type_is_rejected(self):
        self.assert_ec2_change_rejected("instance_type", "t3.micro", "t3.small")

    def test_ec2_subnet_is_rejected(self):
        self.assert_ec2_change_rejected("subnet_id", "subnet-old", "subnet-new")

    def assert_ec2_change_rejected(self, path, before, after):
        item = ec2()
        item["change"]["before"][path] = before
        item["change"]["after"][path] = after
        self.assertFalse(known(item))

    def test_ec2_security_changes_are_rejected(self):
        for field, before, after in [("associate_public_ip_address", False, True),
                                     ("metadata_options", [{"http_tokens": "required"}], [{"http_tokens": "optional"}]),
                                     ("iam_instance_profile", "restricted", "admin"),
                                     ("user_data", "old-private", "new-private")]:
            with self.subTest(field=field):
                self.assert_ec2_change_rejected(field, before, after)

    def test_wrong_replacement_path_or_encryption_direction_rejected(self):
        item = ec2()
        item["change"]["replace_paths"].append(["ami"])
        self.assertFalse(known(item))
        item = ec2()
        item["change"]["before"]["root_block_device"][0]["encrypted"] = True
        item["change"]["after"]["root_block_device"][0]["encrypted"] = False
        self.assertFalse(known(item))

    def test_computed_unknown_allowed_but_known_mutation_rejected(self):
        item = ec2()
        item["change"]["before"]["public_ip"] = ""
        item["change"]["after_unknown"]["public_ip"] = True
        self.assertTrue(known(item))
        item["change"]["after_unknown"].pop("public_ip")
        item["change"]["after"]["public_ip"] = "192.0.2.1"
        self.assertFalse(known(item))

    def test_update_signatures_fail_closed(self):
        for kind, before, after in [
            ("aws_cloudfront_distribution", {"tags": {}}, {"tags": {"Name": "cdn-local"}}),
            ("aws_iam_instance_profile", {"tags_all": {}}, {"tags_all": {"Project": "pmp"}}),
            ("aws_db_instance", {"storage_type": "gp2"}, {"storage_type": "gp3"}),
            ("aws_elasticache_replication_group", {"transit_encryption_mode": ""}, {"transit_encryption_mode": "required"}),
            ("aws_network_acl", {"tags": {}}, {"tags": {"Name": "acl-local"}}),
        ]:
            with self.subTest(kind=kind):
                item = resource(kind, before, after)
                self.assertTrue(known(item))
                item["change"]["before"]["unreviewed_attribute"] = False
                item["change"]["after"]["unreviewed_attribute"] = True
                self.assertFalse(known(item))

    def test_attachment_requires_verified_ec2_dependency(self):
        instance = ec2()
        attachment = resource("aws_lb_target_group_attachment", {"id": "attachment-local", "target_id": "i-local", "port": 8080},
                              {"port": 8080}, ["delete", "create"], [["target_id"]], {"id": True, "target_id": True})
        config = {"root_module": {"module_calls": {"compute": {"module": {"resources": [{
            "address": "aws_lb_target_group_attachment.app", "expressions": {"target_id": {"references": ["aws_instance.app", "each.key"]}}
        }]}}}}}
        plan = {"resource_changes": [instance, attachment], "configuration": config}
        self.assertTrue(all(r["classification"] == "known_emulator_incompatibility" for r in analyze(plan)))
        for mutation in ("missing", "unknown_ec2", "wrong_target", "port", "reference"):
            with self.subTest(mutation=mutation):
                bad = copy.deepcopy(plan)
                if mutation == "missing":
                    bad["resource_changes"].pop(0)
                elif mutation == "unknown_ec2":
                    bad["resource_changes"][0]["change"]["after"]["ami"] = "ami-other"
                elif mutation == "wrong_target":
                    bad["resource_changes"][1]["change"]["before"]["target_id"] = "i-other"
                elif mutation == "port":
                    bad["resource_changes"][1]["change"]["after"]["port"] = 22
                else:
                    bad["configuration"] = {}
                self.assertEqual(analyze(bad)[-1]["classification"], "UNEXPECTED")

    def test_sensitive_parent_and_forbidden_fields(self):
        before = {"password": "never-output", "nested": {"value": "also-private"}, "user_data": "private-script"}
        after = {"password": "new-private", "nested": {"value": "new-nested"}, "user_data": "new-script"}
        report = list(differences(before, after, {}, {"nested": True}, {}))
        self.assertEqual(len(report), 3)
        self.assertTrue(all(item["before"] == item["after"] == "[REDACTED]" for item in report))

    def test_encryption_delta_and_unknown_id(self):
        report = list(differences({"root_block_device": [{"encrypted": False}], "id": "i-local"},
                                  {"root_block_device": [{"encrypted": True}]}, {"id": True}, {}, {}))
        self.assertIn({"path": ["root_block_device", 0, "encrypted"], "before": False, "after": True}, report)
        self.assertIn({"path": ["id"], "before": "i-local", "after": "[UNKNOWN]"}, report)


if __name__ == "__main__":
    unittest.main()
