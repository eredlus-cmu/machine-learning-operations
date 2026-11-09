# Description: Register the current model if the current
# model is better than the last.

import argparse
import json
import os

import joblib
import mlflow


def parse_args():
    """Parse input arguments"""

    parser = argparse.ArgumentParser()
    parser.add_argument("--model_dir", type=str, help="model directory")
    parser.add_argument(
        "--registry_dir", type=str, help="model registry directory"
    )
    parser.add_argument(
        "--eval_dir", type=str, help="evaluation result directory"
    )
    parser.add_argument("--config_file", type=str, help="config file path")
    parser.add_argument(
        "--metrics-out",
        type=str,
        default="/artifacts/metrics.json",
        help="path to write model_version JSON",
    )

    args = parser.parse_args()

    return args


def main(args):
    """Main function to register the model if the current model
    is better than the last"""

    # Read config file
    with open(args.config_file, "r") as f:
        config = json.load(f)
    model_config = config["model"]
    print(
        "Model config:", ", ".join(f"{k}={v}" for k, v in model_config.items())
    )
    eval_config = config["eval"]
    print(
        "Eval config:", ", ".join(f"{k}={v}" for k, v in eval_config.items())
    )
    registry_config = config["registry"]
    print(
        "Registry config:",
        ", ".join(f"{k}={v}" for k, v in registry_config.items()),
    )

    # Read evaluation flag
    eval_path = os.path.join(
        args.eval_dir, eval_config["better_than_last_file"]
    )
    with open(eval_path, "r") as f:
        better_than_last = int(f.read())

    # Register the model if the current model is better than the last
    if better_than_last == 1:
        mlflow.log_metric("better_than_last", better_than_last)

        print("Registering ", registry_config["model_name"])

        model_path = os.path.join(args.model_dir, model_config["model_file"])
        model = joblib.load(model_path)

        mlflow.sklearn.log_model(
            sk_model=model,
            artifact_path=model_config["model_name"],
            serialization_format="cloudpickle",
        )
        mlflow.set_tag(
            "train_image", os.environ.get("IMAGE_SHA", "unknown")
        )
        run_id = mlflow.active_run().info.run_id
        model_uri = f"runs:/{run_id}/{model_config['model_name']}"

        registered = mlflow.register_model(
            model_uri, registry_config["model_name"]
        )
        print(
            f"Registered {registered.name} v{registered.version}"
        )

        out = args.metrics_out
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, "w") as f:
            json.dump({"model_version": str(registered.version)}, f)
            f.write("\n")
    else:
        print("Model is not better than the last. Skip registering")


if __name__ == "__main__":
    args = parse_args()
    print(
        "Input argument:", ", ".join(f"{k}={v}" for k, v in vars(args).items())
    )
    mlflow.set_experiment("credit_default")
    mlflow.start_run(run_name="Credit_Default_Model_Registering")
    main(args)
    mlflow.end_run()
