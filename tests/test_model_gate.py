"""Model validation gate."""
import json
import os
import sys
from pathlib import Path
import pytest

ROOT = Path(__file__).resolve().parents[1]
EVAL_DIR = Path(os.environ.get("EVAL_DIR", ROOT / "eval"))


def test_model_gate_passes():
    ef = EVAL_DIR / "credit_default_eval.json"
    if not ef.exists():
        pytest.skip(f"missing {ef}")
    with open(ROOT / "config" / "modelling.json") as f:
        threshold = json.load(f)["eval"]["min_accuracy"]
    with open(ef) as f:
        acc = float(json.load(f)["accuracy"])
    assert acc >= threshold, f"accuracy {acc} < {threshold}"


if __name__ == "__main__":
    try:
        test_model_gate_passes()
    except Exception as e:
        print(e, file=sys.stderr)
        sys.exit(1)
    sys.exit(0)
