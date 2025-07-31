#
# QuantumArb 2.0 - ML Pipeline: Inference Server
#
# File: src/ml_pipeline/inference_server.py
#
# Description:
# This script creates a high-performance API server to serve predictions from
# our trained XGBoost model. It uses FastAPI for its speed and ease of use.
#
# The server loads the trained model at startup and exposes a `/predict`
# endpoint that accepts real-time feature data and returns a trading signal.
#
# Dependencies:
# pip install fastapi uvicorn python-multipart xgboost pandas
#
# To run locally:
# uvicorn inference_server:app --reload
#

from fastapi import FastAPI
from pydantic import BaseModel
import xgboost as xgb
import pandas as pd
import os

# --- API and Model Setup ---

# Initialize the FastAPI app
app = FastAPI(
    title="QuantumArb 2.0 - ML Inference Server",
    description="Serves predictions from the trained XGBoost price direction model."
)

# Load the trained XGBoost model from the file created by train_model.py
MODEL_FILE = 'xgb_price_predictor.json'
model = xgb.XGBClassifier()

# Check if model file exists before loading
if os.path.exists(MODEL_FILE):
    model.load_model(MODEL_FILE)
    print(f"Model '{MODEL_FILE}' loaded successfully.")
else:
    print(f"ERROR: Model file '{MODEL_FILE}' not found. Please run train_model.py first.")
    # In a real app, you might exit or have a fallback mechanism.


# Define the input data structure using Pydantic for validation
class PredictionFeatures(BaseModel):
    news_sentiment: float
    mavg_spread: float

# Define the output data structure
class PredictionResponse(BaseModel):
    prediction: int # 0 for price down, 1 for price up
    signal: str

# --- API Endpoints ---

@app.get("/", summary="Health Check")
def read_root():
    """
    A simple health check endpoint to confirm the server is running.
    """
    return {"status": "QuantumArb Inference Server is running."}


@app.post("/predict", response_model=PredictionResponse, summary="Get Trading Prediction")
def predict(features: PredictionFeatures):
    """
    Accepts feature data and returns a model prediction.
    """
    # Create a pandas DataFrame from the input features, as XGBoost expects it.
    # The feature names must match those used during training.
    input_df = pd.DataFrame([features.dict()])
    
    # Make a prediction using the loaded model
    prediction_raw = model.predict(input_df)[0]
    prediction_int = int(prediction_raw)

    # Convert the numerical prediction to a human-readable signal
    signal_str = "BUY" if prediction_int == 1 else "SELL"
    
    print(f"Received features: {features.dict()}. Prediction: {signal_str}")

    return PredictionResponse(prediction=prediction_int, signal=signal_str)

