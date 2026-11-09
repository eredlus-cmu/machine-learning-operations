#!/usr/bin/env bash
set -euo pipefail
VM_IP="${1:?}"; IMAGE="${2:?}"; ALIAS="${3:?}"
: "${RESOURCE_GROUP:?}"; : "${MLFLOW_PRIVATE_IP:?}"; : "${ACR_NAME:?}"; : "${VM_NAME:?}"

# TODO(task2): On $VM_NAME, pull $IMAGE from ACR and run it as a container named
# `inference` (the Task 3 submitter looks for that name) publishing :8000, with
#   MLFLOW_TRACKING_URI=http://$MLFLOW_PRIVATE_IP:5000
#   MODEL_ALIAS=$ALIAS
# Wait until http://$VM_IP:8000/health returns 200 (tip: dump docker logs if health check fails).
exit 1
