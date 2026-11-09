#!/usr/bin/env bash
# Train container entrypoint. Runs the full train -> gate -> register flow
# against MLFLOW_TRACKING_URI and writes /artifacts/metrics.json.
set -euo pipefail

: "${MLFLOW_TRACKING_URI:?MLFLOW_TRACKING_URI required}"
export MLFLOW_TRACKING_URI
MODEL_NAME="${MODEL_NAME:-credit_default_model}"
CONFIG="${CONFIG:-config/modelling.json}"

cd /app

bash scripts/download_data.sh
mkdir -p data/output models eval registry /artifacts

python src/training/data_prep.py \
  --data_input_dir data/input \
  --data_output_dir data/output \
  --config_file "$CONFIG"

python src/training/train.py \
  --data_dir data/output \
  --model_dir models \
  --config_file "$CONFIG"

python src/training/evaluate.py \
  --data_dir data/output \
  --model_dir models \
  --eval_dir eval \
  --config_file "$CONFIG"

EVAL_DIR=eval pytest -q tests/test_model_gate.py

python src/training/register.py \
  --model_dir models \
  --eval_dir eval \
  --registry_dir registry \
  --config_file "$CONFIG" \
  --metrics-out /artifacts/metrics.json

VERSION=$(python3 -c "import json;print(json.load(open('/artifacts/metrics.json'))['model_version'])")
echo "Done: registered ${MODEL_NAME} v${VERSION}"
