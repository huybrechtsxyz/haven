#!/usr/bin/env bash
# Installs the repository's tools at the versions in VERSIONS.env (the single
# place for them; .github/actions/setup-tools reads the same file in CI).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
set -a
# shellcheck disable=SC1091
. <(grep -E '^[A-Z][A-Z0-9_]*=' "$root/VERSIONS.env")
set +a

arch="$(dpkg --print-architecture)" # amd64 / arm64
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

actual_python="$(python3 -c 'import sys; print(f"{sys.version_info[0]}.{sys.version_info[1]}")')"
if [ "$actual_python" != "$PYTHON_VERSION" ]; then
  echo "WARNING: container Python is $actual_python, VERSIONS.env says $PYTHON_VERSION —"
  echo "         update the image tag in .devcontainer/devcontainer.json."
fi

echo ">>> Installing strata $STRATA_VERSION..."
pip install --quiet "xyz-strata @ git+https://github.com/huybrechtsxyz/strata.git@v${STRATA_VERSION}"

echo ">>> Installing ansible-core $ANSIBLE_CORE_VERSION..."
pip install --quiet "ansible-core==${ANSIBLE_CORE_VERSION}"

echo ">>> Installing Terraform $TERRAFORM_VERSION..."
curl -fsSL -o "$tmp/terraform.zip" \
  "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${arch}.zip"
unzip -q -o "$tmp/terraform.zip" -d "$tmp"
sudo install -m 0755 "$tmp/terraform" /usr/local/bin/terraform

echo ">>> Installing Helm $HELM_VERSION..."
curl -fsSL -o "$tmp/helm.tgz" "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${arch}.tar.gz"
tar -xzf "$tmp/helm.tgz" -C "$tmp"
sudo install -m 0755 "$tmp/linux-${arch}/helm" /usr/local/bin/helm

echo ">>> Installing shell completion..."
strata --install-completion bash 2>/dev/null || true

echo ">>> Versions:"
strata --version
ansible --version | head -1
terraform version | head -1
helm version --short

echo ""
echo ">>> Setup complete. Run 'strata integration list' to check the tools strata uses."
