"""Extract only sanitized attribute differences from an existing local saved plan."""
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
BLOCKED = ("password", "secret_string", "secret_binary", "private_key", "credential", "access_key", "token", "user_data", "policy")
# Reviewed signatures for the pinned Floci 2.1.0 / AWS provider 6.66.0 pair.
# No resource type is trusted wholesale. Every path and replacement is checked.
TAG_PATHS = {("tags", "Name")} | {("tags_all", k) for k in ("Name", "Project", "Environment", "ManagedBy")}
UPDATE_PATHS = {
    "aws_cloudfront_distribution": TAG_PATHS,
    "aws_network_acl": TAG_PATHS,
    "aws_iam_instance_profile": {("tags_all", k) for k in ("Project", "Environment", "ManagedBy")},
    "aws_iam_role": {("permissions_boundary",)},
    "aws_db_instance": {("storage_type",), ("max_allocated_storage",), ("enabled_cloudwatch_logs_exports", 0), ("enabled_cloudwatch_logs_exports", 1)},
    "aws_elasticache_replication_group": {("security_group_ids", 0), ("transit_encryption_mode",)},
}
ENCRYPTION_PATH = ("root_block_device", 0, "encrypted")
# These paths may become unknown ONLY as a consequence of a known replacement.
# A known value change at any of them is still rejected.
EC2_COMPUTED = {(k,) for k in (
    "arn", "availability_zone", "capacity_reservation_specification", "cpu_options",
    "disable_api_stop", "disable_api_termination", "ebs_block_device", "ebs_optimized",
    "enable_primary_ipv6", "enclave_options", "ephemeral_block_device", "host_id",
    "host_resource_group_arn", "id", "instance_initiated_shutdown_behavior",
    "instance_lifecycle", "instance_market_options", "instance_state", "ipv6_address_count",
    "ipv6_addresses", "key_name", "maintenance_options", "monitoring", "network_interface",
    "outpost_arn", "password_data", "placement_group", "placement_group_id",
    "placement_partition_number", "primary_network_interface", "primary_network_interface_id",
    "private_dns", "private_dns_name_options", "private_ip", "public_dns", "public_ip",
    "secondary_network_interface", "secondary_private_ips", "security_groups",
    "spot_instance_request_id", "tenancy", "user_data_base64"
)} | {("root_block_device", 0, k) for k in (
    "device_name", "iops", "kms_key_id", "tags_all", "throughput", "volume_id"
)} | {("metadata_options", 0, "instance_metadata_tags")}


def child(value, key):
    if isinstance(value, dict):
        return value.get(key)
    if isinstance(value, list) and isinstance(key, int) and key < len(value):
        return value[key]
    return None


def differences(before, after, unknown, sensitive_before, sensitive_after, path=()):
    # Never traverse or expose provider-marked sensitive subtrees.
    if sensitive_before is True or sensitive_after is True or any(word in str(p).lower() for p in path for word in BLOCKED):
        if before != after or unknown:
            yield {"path": list(path), "before": "[REDACTED]", "after": "[REDACTED]"}
        return
    if unknown is True:
        yield {"path": list(path), "before": before if not isinstance(before, (dict, list)) else "[collection]", "after": "[UNKNOWN]"}
        return
    if isinstance(before, dict) or isinstance(after, dict):
        for key in sorted(set(before or {}) | set(after or {}) | set(unknown or {})):
            yield from differences(child(before, key), child(after, key), child(unknown, key), child(sensitive_before, key), child(sensitive_after, key), (*path, key))
    elif isinstance(before, list) or isinstance(after, list):
        for key in range(max(len(before or []), len(after or []), len(unknown or []))):
            yield from differences(child(before, key), child(after, key), child(unknown, key), child(sensitive_before, key), child(sensitive_after, key), (*path, key))
    elif before != after:
        yield {"path": list(path), "before": before, "after": after}


def at(value, path):
    for key in path:
        value = child(value, key)
    return value


def ec2_signature(change, paths):
    if change["actions"] != ["delete", "create"] or change.get("replace_paths") != [list(ENCRYPTION_PATH)]:
        return False
    if ENCRYPTION_PATH not in paths:
        return False
    for path in paths:
        before, after = at(change.get("before"), path), at(change.get("after"), path)
        unknown = at(change.get("after_unknown"), path) is True
        if path == ENCRYPTION_PATH:
            valid = before is False and after is True and not unknown
        elif path == ("root_block_device", 0, "volume_size"):
            valid = before == 8 and after == 12 and not unknown
        elif path == ("vpc_security_group_ids", 0):
            valid = before == "sg-default-ca-central-1" and isinstance(after, str) and after.startswith("sg-") and after != before and not unknown
        elif path == ("credit_specification", 0, "cpu_credits"):
            valid = before == "unlimited" and after is None and not unknown
        elif path == ("hibernation",):
            valid = before is False and after is None and not unknown
        elif path in EC2_COMPUTED:
            valid = unknown
            if path in {("user_data_base64",), ("password_data",)}:
                valid = valid and before in (None, "")
        else:
            valid = False
        if not valid:
            return False
    return True


def update_signature(resource_type, change, paths):
    if change["actions"] != ["update"] or change.get("replace_paths") or not paths or not paths <= UPDATE_PATHS.get(resource_type, set()):
        return False
    for path in paths:
        before, after = at(change.get("before"), path), at(change.get("after"), path)
        if at(change.get("after_unknown"), path):
            return False
        if path[0] in ("tags", "tags_all"):
            valid = before is None and isinstance(after, str) and bool(after)
        elif path == ("permissions_boundary",):
            valid = before == "" and isinstance(after, str) and after.startswith("arn:aws:iam::000000000000:policy/")
        elif path == ("storage_type",):
            valid = before == "gp2" and after == "gp3"
        elif path == ("max_allocated_storage",):
            valid = before == 0 and after == 100
        elif path[0] == "enabled_cloudwatch_logs_exports":
            valid = before is None and after == ("postgresql", "upgrade")[path[1]]
        elif path == ("security_group_ids", 0):
            valid = before is None and isinstance(after, str) and after.startswith("sg-")
        elif path == ("transit_encryption_mode",):
            valid = before == "" and after == "required"
        else:
            valid = False
        if not valid:
            return False
    return True


def configuration_resources(module, prefix=""):
    result = {prefix + r["address"]: r for r in module.get("resources", [])}
    for name, call in module.get("module_calls", {}).items():
        result.update(configuration_resources(call.get("module", {}), prefix + f"module.{name}."))
    return result


def analyze(plan):
    changes = {r["address"]: r for r in plan.get("resource_changes", []) if r["change"]["actions"] != ["no-op"]}
    config = configuration_resources(plan.get("configuration", {}).get("root_module", {}))
    reports = {}
    for address, resource in changes.items():
        change = resource["change"]
        attributes = list(differences(change.get("before"), change.get("after"), change.get("after_unknown"), change.get("before_sensitive"), change.get("after_sensitive")))
        paths = {tuple(d["path"]) for d in attributes}
        known = ec2_signature(change, paths) if resource["type"] == "aws_instance" else update_signature(resource["type"], change, paths)
        reports[address] = {"address": address, "actions": change["actions"], "replace_paths": change.get("replace_paths", []),
                            "changed_attributes": attributes, "classification": "known_emulator_incompatibility" if known else "UNEXPECTED",
                            "signature": "floci-2.1.0/" + resource["type"] if known else None}
    # Resolve attachment dependency only after the entire EC2 signature passed.
    for address, resource in changes.items():
        if resource["type"] != "aws_lb_target_group_attachment":
            continue
        change = resource["change"]
        paths = {tuple(d["path"]) for d in reports[address]["changed_attributes"]}
        base = address.split("[")[0]
        references = config.get(base, {}).get("expressions", {}).get("target_id", {}).get("references", [])
        if set(references) != {"aws_instance.app", "each.key"} or "index" not in resource:
            continue
        parent = base.rsplit("aws_lb_target_group_attachment.", 1)[0]
        instance_address = parent + "aws_instance.app[" + json.dumps(resource["index"]) + "]"
        instance = changes.get(instance_address)
        if not instance or reports[instance_address]["classification"] != "known_emulator_incompatibility":
            continue
        if (change["actions"] == ["delete", "create"] and change.get("replace_paths") == [["target_id"]]
                and paths <= {("target_id",), ("id",)} and ("target_id",) in paths
                and at(change.get("before"), ("target_id",)) == at(instance["change"].get("before"), ("id",))
                and all(at(change.get("after_unknown"), p) is True for p in paths)):
            reports[address].update(classification="known_emulator_incompatibility", signature="floci-2.1.0/ec2-target-cascade", caused_by=instance_address)
    return list(reports.values())


def write_reports(plan, directory):
    report = analyze(plan)
    (directory / "drift-details.json").write_text(json.dumps(report, indent=2) + "\n")
    (directory / "drift-summary.json").write_text(json.dumps([{k: r[k] for k in ("address", "actions", "classification")} for r in report], indent=2) + "\n")
    counts = {"known": sum(r["classification"] == "known_emulator_incompatibility" for r in report),
              "unexpected": sum(r["classification"] == "UNEXPECTED" for r in report)}
    (directory / "drift-counts.json").write_text(json.dumps(counts, indent=2) + "\n")
    print(f"Drift analysis: known={counts['known']} unexpected={counts['unexpected']}; known differences remain visible")
    return counts


def main():
    environment = sys.argv[1]
    if environment not in ("dev", "prod"):
        raise ValueError("Only local dev/prod saved plans are supported")
    directory = ROOT / ".local" / environment
    # terraform show is offline; raw JSON stays in process memory only.
    result = subprocess.run(["terraform", "show", "-json", "drift.tfplan"], cwd=directory, capture_output=True, check=True)
    plan = json.loads(result.stdout)
    counts = write_reports(plan, directory)
    sys.exit(1 if counts["unexpected"] else 0)


if __name__ == "__main__":
    main()
