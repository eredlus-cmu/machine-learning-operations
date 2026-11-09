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
exit 1
