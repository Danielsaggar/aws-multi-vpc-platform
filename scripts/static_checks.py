"""Run pinned Docker linters without AWS access."""
from pathlib import Path
import subprocess
import sys
import shutil
import tempfile

root = Path(__file__).resolve().parents[1]
(root / ".artifacts").mkdir(exist_ok=True)
# Scan only Git-visible source, excluding generated state and dependency trees.
# Include untracked new implementation files so pre-commit checks are meaningful.
snapshot = Path(tempfile.mkdtemp(prefix="source-check-", dir=root / ".artifacts"))
files = subprocess.check_output(["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"], cwd=root).decode().split("\0")
for name in files:
    if name and (root / name).is_file():
        target = snapshot / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(root / name, target)
mount = f"type=bind,source={snapshot},target=/src,readonly"
commands = [
    ["rhysd/actionlint:1.7.7", "-color", "/src/.github/workflows/ci.yml", "/src/.github/workflows/integration-floci.yml", "/src/.github/workflows/deploy-aws.yml"],
    ["zricethezav/gitleaks:v8.24.2", "dir", "/src", "--config", "/src/.gitleaks.toml", "--redact", "--no-banner"],
]
for directory in [".", "bootstrap", *[str(p.relative_to(root)).replace("\\", "/") for p in (root / "modules").iterdir() if p.is_dir()]]:
    commands.append(["ghcr.io/terraform-linters/tflint:v0.61.0", f"--chdir=/src/{directory}", "--config=/src/.tflint.hcl"])
failed = False
for command in commands:
    print("CHECK", " ".join(command), flush=True)
    result = subprocess.run(["docker", "run", "--rm", "--mount", mount, *command])
    print("EXIT", result.returncode, flush=True)
    failed = failed or result.returncode != 0
sys.exit(1 if failed else 0)
