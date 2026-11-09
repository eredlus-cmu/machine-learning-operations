"""FastAPI inference server. Load weights from MLflow by registry alias."""
from contextlib import asynccontextmanager
import os
from typing import Any, Dict, List, Optional
import mlflow
import mlflow.pyfunc
import pandas as pd
from fastapi import FastAPI, HTTPException, Response
from pydantic import BaseModel

MODEL_NAME = os.environ.get("MODEL_NAME", "credit_default_model")
MODEL_ALIAS = os.environ.get("MODEL_ALIAS", "prod")
TRACKING_URI = os.environ.get("MLFLOW_TRACKING_URI", "file:./mlruns")
IMAGE_REF = os.environ.get("IMAGE_REF", "unknown")
_model: Optional[mlflow.pyfunc.PyFuncModel] = None
_model_version: Optional[str] = None
_model_alias: Optional[str] = None


class PredictRequest(BaseModel):
    instances: List[List[float]]


class PredictResponse(BaseModel):
    predictions: List[Any]


def load_model() -> None:
    global _model, _model_version, _model_alias
    mlflow.set_tracking_uri(TRACKING_URI)
    # TODO(task2): resolve MODEL_ALIAS on MODEL_NAME in the registry and
    # load models:/{MODEL_NAME}@{MODEL_ALIAS}.
    # Set _model, _model_version, _model_alias.
    # /version must return those fields so the grader can match alias
    # promotion.
    raise NotImplementedError("load model by registry alias")


@asynccontextmanager
async def lifespan(_app: FastAPI):
    load_model()
    yield


app = FastAPI(
    title="Credit Default Inference",
    version="1.0.0",
    lifespan=lifespan,
)


@app.get("/health")
def health(response: Response) -> Dict[str, Any]:
    if not _model:
        response.status_code = 503
    return {
        "status": "ok" if _model else "unhealthy",
        "model_loaded": _model is not None,
    }


@app.get("/version")
def version() -> Dict[str, str]:
    if not _model:
        raise HTTPException(503, "Model not loaded")
    return {
        "model_name": MODEL_NAME,
        "model_version": str(_model_version),
        "model_alias": str(_model_alias),
        "image": IMAGE_REF,
    }


@app.post("/predict", response_model=PredictResponse)
def predict(request: PredictRequest) -> PredictResponse:
    if not _model:
        raise HTTPException(503, "Model not loaded")
    preds = _model.predict(pd.DataFrame(request.instances))
    if hasattr(preds, "tolist"):
        preds = preds.tolist()
    return PredictResponse(predictions=preds)
