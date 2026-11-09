"""Contract tests for the FastAPI inference server."""
import json
import os
import subprocess
import time
from pathlib import Path
import pytest
import requests

GOLDEN = Path(__file__).parent / "golden"
URL = os.environ.get("INFERENCE_URL", "http://127.0.0.1:8000")


def _u(p):
    return f"{URL.rstrip('/')}{p}"


@pytest.fixture(scope="module")
def live_server():
    if not URL.startswith(("http://127.0.0.1", "http://localhost")):
        yield None
        return
    try:
        if requests.get(_u("/health"), timeout=2).status_code == 200:
            yield None
            return
    except requests.RequestException:
        pass
    root = Path(__file__).resolve().parents[1]
    if not (root / "mlruns").exists() and not (root / "mlflow.db").exists():
        pytest.skip("No local MLflow store")
    env = os.environ.copy()
    env.setdefault("MLFLOW_TRACKING_URI", f"file://{root / 'mlruns'}")
    env.setdefault("MODEL_ALIAS", "beta")
    proc = subprocess.Popen(
        ["uvicorn", "app:app", "--host", "127.0.0.1", "--port", "8000"],
        cwd=str(root / "src/inference"),
        env={**env, "PYTHONPATH": str(root / "src/inference")},
    )
    for _ in range(30):
        try:
            if requests.get(_u("/health"), timeout=1).status_code == 200:
                break
        except requests.RequestException:
            time.sleep(1)
    else:
        proc.terminate()
        pytest.fail("server not healthy")
    yield proc
    proc.terminate()
    proc.wait(timeout=10)


def test_health(live_server):
    r = requests.get(_u("/health"), timeout=10)
    assert r.status_code == 200
    assert r.json()["model_loaded"]


def test_version(live_server):
    r = requests.get(_u("/version"), timeout=10)
    assert r.status_code == 200
    b = r.json()
    assert b["model_name"] == "credit_default_model"
    assert b["model_alias"] in ("beta", "prod")


def test_predict(live_server):
    payload = json.loads((GOLDEN / "predict_request.json").read_text())
    r = requests.post(_u("/predict"), json=payload, timeout=30)
    assert r.status_code == 200
    assert r.json()["predictions"] == [1, 0]
