"""Control-plane assertions against explicitly selected local Floci only."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
from local import aws, endpoint

url, environment = endpoint(sys.argv[1]), sys.argv[2]
instances = [i for r in aws(url, "ec2", "describe-instances")["Reservations"] for i in r["Instances"] if i["State"]["Name"] == "running"]
assert len(instances) == (8 if environment == "prod" else 4)
assert all(not i.get("PublicIpAddress") for i in instances)
vpcs = [v for v in aws(url, "ec2", "describe-vpcs")["Vpcs"] if not v.get("IsDefault")]
assert len(vpcs) == 2
databases = aws(url, "rds", "describe-db-instances")["DBInstances"]
assert len(databases) == 2 and all(not db["PubliclyAccessible"] for db in databases)
assert all(db["StorageEncrypted"] for db in databases)
assert len(aws(url, "elbv2", "describe-load-balancers")["LoadBalancers"]) == 1
assert len(aws(url, "logs", "describe-log-groups")["logGroups"]) >= 4
for bucket in aws(url, "s3api", "list-buckets")["Buckets"]:
    config = aws(url, "s3api", "get-public-access-block", "--bucket", bucket["Name"])["PublicAccessBlockConfiguration"]
    assert all(config.values()), bucket["Name"]
print("PASS: local control-plane topology and private resource assertions")
