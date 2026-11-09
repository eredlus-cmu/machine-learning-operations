# Description: Train the model.

import argparse
import json
import os

import joblib
import mlflow
import pandas as pd
from sklearn.ensemble import GradientBoostingClassifier


def parse_args():
    """Parse input arguments"""

    parser = argparse.ArgumentParser()
    parser.add_argument("--data_dir", type=str, help="data directory")
    parser.add_argument("--model_dir", type=str, help="model directory")
    parser.add_argument("--config_file", type=str, help="config file path")

    args = parser.parse_args()

    return args


def main(args):
    """Main function to train the model"""

    # Read config file
    with open(args.config_file, "r") as f:
        config = json.load(f)

    data_config = config["data"]
    train_config = config["train"]
    model_config = config["model"]

    print(
        "Data config:", ", ".join(f"{k}={v}" for k, v in data_config.items())
    )
    print(
        "Training config:",
        ", ".join(f"{k}={v}" for k, v in train_config.items()),
    )
    print(
        "Model config:", ", ".join(f"{k}={v}" for k, v in model_config.items())
    )

    # Set file paths
    train_data_path = os.path.join(args.data_dir, data_config["train_file"])
    model_path = os.path.join(args.model_dir, model_config["model_file"])

    # Read training data
    train_df = pd.read_csv(train_data_path)

    # Extract the label column
    y_train = train_df.pop("default payment next month")

    # Convert the dataframe values to array
    X_train = train_df.values

    print(f"Training with data of shape {X_train.shape}")

    # Train the model
    clf = GradientBoostingClassifier(
        n_estimators=train_config["n_estimators"],
        learning_rate=train_config["learning_rate"],
        random_state=train_config.get("random_state", 42),
    )
    clf.fit(X_train, y_train)

    os.makedirs(args.model_dir, exist_ok=True)
    with open(model_path, "wb") as f:
        joblib.dump(clf, f)
        print(f"Model saved at: {model_path}")

    mlflow.log_param(
        "model", "sklearn.ensemble.GradientBoostingClassifier"
    )
    mlflow.log_param("n_estimators", train_config["n_estimators"])
    mlflow.log_param("learning_rate", train_config["learning_rate"])
    mlflow.log_artifact(model_path)


if __name__ == "__main__":
    args = parse_args()
    print(
        "Input argument:", ", ".join(f"{k}={v}" for k, v in vars(args).items())
    )
    mlflow.set_experiment("credit_default")
    mlflow.start_run(run_name="Credit_Default_Model_Training")
    main(args)
    mlflow.end_run()
