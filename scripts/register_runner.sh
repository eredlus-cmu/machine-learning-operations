#!/usr/bin/env bash
# One-time: register the self-hosted GHA runner on the runner VM.
# Requires: gh logged in, az logged in, terraform outputs.
set -euo pipefail
: "${GITHUB_REPO:?GITHUB_REPO required (e.g. octocat/machine-learning-operations)}"
: "${RESOURCE_GROUP:?}"; : "${RUNNER_VM_NAME:?}"
RUNNER_VERSION="${RUNNER_VERSION:-2.338.0}"
TOKEN=$(gh api -X POST "repos/${GITHUB_REPO}/actions/runners/registration-token" -q .token)
az vm run-command invoke -g "$RESOURCE_GROUP" -n "$RUNNER_VM_NAME" --command-id RunShellScript \
  --scripts '#!/usr/bin/env bash
set -euo pipefail
cd /opt/actions-runner
if [[ -f .runner ]]; then
  echo "Runner already registered"
  exit 0
fi
curl -fsSL -o actions-runner.tar.gz \
  "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"
tar xzf actions-runner.tar.gz
chown -R azureuser:azureuser /opt/actions-runner
sudo -u azureuser ./config.sh --unattended \
  --url "https://github.com/${GITHUB_REPO}" \
  --token "${TOKEN}" \
  --labels vnet \
  --name "mlops-vnet-runner"
./svc.sh install azureuser
./svc.sh start
echo "Runner registered"
' \
  --parameters GITHUB_REPO="$GITHUB_REPO" TOKEN="$TOKEN" RUNNER_VERSION="$RUNNER_VERSION"
