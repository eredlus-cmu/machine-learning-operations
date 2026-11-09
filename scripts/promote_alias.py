#!/usr/bin/env python3
"""Set a model registry alias (beta/prod) on a model version."""
import argparse
import os
import sys

from mlflow.tracking import MlflowClient


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--model-name", required=True)
    p.add_argument("--version", required=True, type=int)
    p.add_argument("--alias", required=True)
    return p.parse_args()


def main():
    args = parse_args()
    uri = os.environ.get("MLFLOW_TRACKING_URI")
    if not uri:
        print("MLFLOW_TRACKING_URI is required", file=sys.stderr)
        sys.exit(1)
    import mlflow

    mlflow.set_tracking_uri(uri)
    MlflowClient().set_registered_model_alias(
        args.model_name, args.alias, str(args.version)
    )
    print(f"Aliased {args.model_name} v{args.version} -> {args.alias}")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(exc, file=sys.stderr)
        sys.exit(1)
