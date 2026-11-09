#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"
TF_DIR="${TF_DIR:-$ROOT/infra/terraform}"
TERRAFORM_BIN="${TERRAFORM_BIN:-terraform}"
OUT="$(cd "$TF_DIR" && "$TERRAFORM_BIN" output -json)"
jq -n --argjson out "$OUT" '{
  resource_group: $out.resource_group_name.value,
  location: $out.location.value,
  mlflow_private_ip: $out.mlflow_private_ip.value,
  mlflow_uri: $out.mlflow_uri.value,
  beta_vm_ip: $out.beta_vm_ip.value,
  beta_vm_name: $out.beta_vm_name.value,
  prod_vm_ip: $out.prod_vm_ip.value,
  prod_vm_name: $out.prod_vm_name.value,
  runner_vm_name: $out.runner_vm_name.value,
  acr_name: $out.acr_name.value,
  acr_login_server: $out.acr_login_server.value,
  acr_id: $out.acr_id.value,
  subnet_id: $out.subnet_id.value,
  train_uai_id: $out.train_uai_id.value,
  unique_prefix: $out.unique_prefix.value
}' > "$ROOT/meta.json"
echo "Wrote $ROOT/meta.json"
