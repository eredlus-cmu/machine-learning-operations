#!/usr/bin/env bash
set -euo pipefail
: "${RESOURCE_GROUP:?}"; : "${LOCATION:?}"; : "${SUBNET_ID:?}"
: "${ACR_NAME:?}"; : "${MLFLOW_TRACKING_URI:?}"; : "${SSH_PUBLIC_KEY:?}"
: "${TRAIN_UAI_ID:?TRAIN_UAI_ID required}"
: "${TRAIN_IMAGE:?TRAIN_IMAGE required}"
RUN_ID="${RUN_ID:-$(date +%s)}"
VM="train-eph-${RUN_ID}"
# Bsv2 family is often quota 0 on teaching subs; D2s_v7 is 2 vCPUs in a different family.
VM_SIZE="${VM_SIZE:-Standard_D2s_v7}"
DIR="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$DIR/.." && pwd)"
CI="${ROOT}/infra/terraform/cloud-init/docker-install.yml"

cleanup() {
  az vm delete -g "$RESOURCE_GROUP" -n "$VM" --yes 2>/dev/null || true
  for i in $(seq 1 12); do
    az network nic delete -g "$RESOURCE_GROUP" -n "${VM}VMNic" 2>/dev/null && break
    sleep 10
  done
  az disk list -g "$RESOURCE_GROUP" --query "[?contains(name,'${VM}_')].id" -o tsv 2>/dev/null \
    | xargs -r -I{} az disk delete --ids {} --yes 2>/dev/null || true
  for i in $(seq 1 12); do
    az network public-ip delete -g "$RESOURCE_GROUP" -n "${VM}PublicIP" 2>/dev/null && break
    sleep 10
  done
}
trap cleanup EXIT

# TODO(task1): Create $VM in $RESOURCE_GROUP (image Ubuntu 22.04, size $VM_SIZE,
# subnet $SUBNET_ID, identity $TRAIN_UAI_ID, cloud-init $CI). Wait for cloud-init.
# On the VM: az login --identity, az acr login, docker pull $TRAIN_IMAGE, docker run
# it with MLFLOW_TRACKING_URI (and IMAGE_SHA if set) so train_entrypoint registers a
# model, then copy metrics.json ({"model_version": "N"}) to $ROOT/metrics.json.
#
# The grader counts VMs in this resource group before, during, and after the workflow.
# The trap deletes $VM when this script exits — keep that, or after==before will fail.

az vm create -g "$RESOURCE_GROUP" -n "$VM" -l "$LOCATION" \
  --image Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest \
  --size "$VM_SIZE" --admin-username azureuser --ssh-key-values "$SSH_PUBLIC_KEY" \
  --subnet "$SUBNET_ID" --public-ip-sku Standard \
  --assign-identity "$TRAIN_UAI_ID" \
  --custom-data "$CI" -o none

timeout 600 az vm run-command invoke -g "$RESOURCE_GROUP" -n "$VM" --command-id RunShellScript \
  --scripts "sudo cloud-init status --wait" -o none

set +e
az vm run-command invoke -g "$RESOURCE_GROUP" -n "$VM" --command-id RunShellScript \
  --scripts '#!/usr/bin/env bash
set -euo pipefail
az login --identity
az acr login --name "$ACR_NAME"
docker pull "$TRAIN_IMAGE"
mkdir -p /opt/artifacts
docker run --rm \
  -v /opt/artifacts:/artifacts \
  -e MLFLOW_TRACKING_URI="$MLFLOW_TRACKING_URI" \
  -e IMAGE_SHA="${IMAGE_SHA:-}" \
  "$TRAIN_IMAGE"
cat /opt/artifacts/metrics.json
' \
  --parameters ACR_NAME="$ACR_NAME" TRAIN_IMAGE="$TRAIN_IMAGE" \
    MLFLOW_TRACKING_URI="$MLFLOW_TRACKING_URI" IMAGE_SHA="${IMAGE_SHA:-}" \
  --query "value[0].message" -o tsv > "$ROOT/train_stdout.log"
AZ_RC=$?
set -e

if [[ $AZ_RC -ne 0 ]]; then
  echo "=== train run-command failed (az exit $AZ_RC) ===" >&2
  cat "$ROOT/train_stdout.log" >&2 || true
  exit 1
fi

echo "=== train stdout (tail) ==="; tail -25 "$ROOT/train_stdout.log"
grep -oE '\{"model_version": ?"[^"]+"\}' "$ROOT/train_stdout.log" > "$ROOT/metrics.json" || true

if ! python3 -c "import json; d=json.load(open('$ROOT/metrics.json')); assert d.get('model_version')" 2>/dev/null; then
  echo "=== train pipeline failed (no valid metrics.json); full train stdout: ===" >&2
  cat "$ROOT/train_stdout.log" >&2 || true
  exit 1
fi

exit 0
