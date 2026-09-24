"""Fail closed before any OIDC authentication step."""
import os


def validate(enabled, environment, ref, account, repository_private):
    if enabled != "true":
        raise ValueError("AWS deployment is disabled")
    branches = {"dev": "refs/heads/develop", "prod": "refs/heads/main"}
    if environment not in branches or ref != branches[environment]:
        raise ValueError("Branch/environment mismatch")
    if len(account) != 12 or not account.isdigit() or account == "000000000000":
        raise ValueError("Explicit real target account is required")
    if repository_private != "true":
        raise ValueError("Saved plan workflow requires a private deployment repository")


if __name__ == "__main__":
    validate(os.getenv("DEPLOY_ENABLED", ""), os.getenv("TARGET_ENV", ""), os.getenv("GITHUB_REF", ""), os.getenv("TARGET_ACCOUNT", ""), os.getenv("REPOSITORY_PRIVATE", ""))
    print("Deployment gates passed; subsequent steps may request temporary OIDC credentials")
