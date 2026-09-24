"""Publish status counts, never Terraform state, binary plans, or raw API payloads."""
import json
import re
from pathlib import Path
root = Path(__file__).resolve().parents[1]
artifacts = root / ".artifacts"
artifacts.mkdir(exist_ok=True)
log_path = artifacts / "integration.log"
raw = log_path.read_bytes() if log_path.exists() else b""
# Windows PowerShell redirects native output as UTF-16; Linux CI uses UTF-8.
log = raw.decode("utf-16" if raw.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig", errors="replace")
drift = re.search(r"Drift analysis: known=(\d+) unexpected=(\d+)", log)
summary = {
    "target": "Floci only; no real AWS evidence",
    "apply_completed": "Apply complete!" in log,
    "assertions_passed": "PASS: local control-plane" in log,
    "postgresql_transactions_passed": log.count("PASS: local PostgreSQL transaction"),
    "redis_protocol_passed": "PASS: local Redis-compatible" in log,
    "known_drift_resources": int(drift[1]) if drift else None,
    "unexpected_drift_resources": int(drift[2]) if drift else None,
    "integration_passed": "Floci integration and cleanup" in log,
    "drift_detected": bool(drift and (int(drift[1]) + int(drift[2]))),
    "no_drift": "No changes." in log,
    "destroy_completed": "Destroy complete!" in log,
    "errors": log.count("Error:") + log.count("Traceback (most recent call last)"),
}
(artifacts / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
print(json.dumps(summary, indent=2))
