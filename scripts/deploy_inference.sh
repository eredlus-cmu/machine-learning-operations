#!/usr/bin/env bash
set -euo pipefail
VM_IP="${1:?}"; IMAGE="${2:?}"; ALIAS="${3:?}"
: "${RESOURCE_GROUP:?}"; : "${MLFLOW_PRIVATE_IP:?}"; : "${ACR_NAME:?}"; : "${VM_NAME:?}"

az vm run-command invoke -g "$RESOURCE_GROUP" -n "$VM_NAME" --command-id RunShellScript \
  --scripts '#!/usr/bin/env bash
set -euo pipefail
az login --identity
az acr login --name "$ACR_NAME"
docker pull "$IMAGE"
docker rm -f inference 2>/dev/null || true
docker run -d --name inference --restart unless-stopped -p 8000:8000 \
  -e MLFLOW_TRACKING_URI="http://${MLFLOW_PRIVATE_IP}:5000" \
  -e MODEL_ALIAS="$ALIAS" \
  -e IMAGE_REF="$IMAGE" "$IMAGE"
' \
  --parameters ACR_NAME="$ACR_NAME" IMAGE="$IMAGE" MLFLOW_PRIVATE_IP="$MLFLOW_PRIVATE_IP" \
    ALIAS="$ALIAS" \
  -o none

for i in $(seq 1 30); do
  curl -fsS "http://${VM_IP}:8000/health" && exit 0
  sleep 5
done

echo "=== Health check failed. Dumping container logs from ${VM_NAME}: ===" >&2
az vm run-command invoke -g "$RESOURCE_GROUP" -n "$VM_NAME" --command-id RunShellScript \
  --scripts "docker logs inference --tail 50" --query "value[0].message" -o tsv >&2 || true
exit 1
