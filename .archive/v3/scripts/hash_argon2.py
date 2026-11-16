#!/usr/bin/env python3
"""Post-generate hook for VAULTWARDEN_ADMIN_TOKEN.

Reads the raw generated secret from stdin, hashes it using Vaultwarden's own
Argon2id hashing (via the official `vaultwarden/server` Docker image's `hash`
subcommand), and writes only the resulting PHC-formatted hash string to
stdout.

strata `post_generate` hook contract:
  - stdin:       raw generated value
  - stdout:      transformed value to write to the configured secret store
  - exit code:   0 on success, non-zero on failure
  - never logs or prints the raw or hashed value except the final stdout line
"""

from __future__ import annotations

import re
import subprocess
import sys

DOCKER_IMAGE = "vaultwarden/server"
HASH_PATTERN = re.compile(r"\$argon2(?:id|i|d)\$[^\s]+")
TIMEOUT_SECONDS = 60


def hash_token(raw_token: str) -> str:
    """Hash `raw_token` using vaultwarden's own Argon2 hash command."""
    # `vaultwarden hash` interactively prompts for the password twice
    # (password + confirmation) on stdin.
    stdin_payload = f"{raw_token}\n{raw_token}\n"

    result = subprocess.run(
        [
            "docker",
            "run",
            "--rm",
            "-i",
            DOCKER_IMAGE,
            "/vaultwarden",
            "hash",
            "--preset",
            "owasp",
        ],
        input=stdin_payload,
        capture_output=True,
        text=True,
        timeout=TIMEOUT_SECONDS,
    )

    if result.returncode != 0:
        raise RuntimeError(
            f"vaultwarden hash exited with code {result.returncode}: {result.stderr.strip()}"
        )

    match = HASH_PATTERN.search(result.stdout)
    if not match:
        raise RuntimeError("could not find an Argon2 hash in vaultwarden hash output")

    return match.group(0)


def main() -> int:
    raw_token = sys.stdin.read().strip()
    if not raw_token:
        print("error: no input received on stdin", file=sys.stderr)
        return 1

    try:
        hashed = hash_token(raw_token)
    except (RuntimeError, subprocess.SubprocessError, FileNotFoundError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print(hashed)
    return 0


if __name__ == "__main__":
    sys.exit(main())
