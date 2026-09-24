"""Smoke the emulator's actual database engines; not an AWS network/TLS test."""
import json
from pathlib import Path
import subprocess
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
from local import aws, endpoint, run

url, environment = endpoint(sys.argv[1]), sys.argv[2]
names = run(["docker", "ps", "--format", "{{.Names}}"], capture=True).stdout.splitlines()
databases = aws(url, "rds", "describe-db-instances")["DBInstances"]
assert len(databases) == 2
for db in databases:
    resource_id = db["DbiResourceId"]
    matches = [name for name in names if name.startswith(f"floci-rds-{resource_id}-")]
    if len(matches) != 1:
        raise RuntimeError(f"Expected one owned database engine for {db['DBInstanceIdentifier']}")
    sql = "BEGIN; CREATE TEMP TABLE smoke(value integer); INSERT INTO smoke VALUES (42); SELECT value FROM smoke; ROLLBACK;"
    result = run(["docker", "exec", matches[0], "psql", "-U", db["MasterUsername"], "-d", db["DBName"], "-tA", "-v", "ON_ERROR_STOP=1", "-c", sql], capture=True)
    assert "42" in result.stdout.splitlines()
    print(f"PASS: local PostgreSQL transaction for {db['DBInstanceIdentifier']}")
group = f"redis-pmp-{environment}-01-ca-central-1"
groups = aws(url, "elasticache", "describe-replication-groups")["ReplicationGroups"]
assert any(g["ReplicationGroupId"] == group for g in groups)
cache = f"floci-valkey-{group}"
assert cache in names
try:
    run(["docker", "exec", cache, "valkey-cli", "SET", "app:integration", "smoke"], capture=True)
    result = run(["docker", "exec", cache, "valkey-cli", "GET", "app:integration"], capture=True)
    assert result.stdout.strip() == "smoke"
finally:
    run(["docker", "exec", cache, "valkey-cli", "DEL", "app:integration"], capture=True)
print("PASS: local Redis-compatible SET/GET/DEL (container protocol only; no IAM/TLS/network certification)")
