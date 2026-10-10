from pathlib import Path

import joblib
from fastapi import FastAPI
from pydantic import BaseModel


# ---------------------------------------------------------
# Project paths
# ---------------------------------------------------------

BASE_DIR = Path(__file__).resolve().parent.parent
ML_DIR = BASE_DIR / "ml"

MODEL_PATH = ML_DIR / "expense_model.pkl"
VECTORIZER_PATH = ML_DIR / "tfidf_vectorizer.pkl"


# ---------------------------------------------------------
# Load trained model and TF-IDF vectorizer ONCE
# ---------------------------------------------------------

model = joblib.load(MODEL_PATH)
vectorizer = joblib.load(VECTORIZER_PATH)


# ---------------------------------------------------------
# FastAPI app
# ---------------------------------------------------------

app = FastAPI(title="SpendSense ML API")


# ---------------------------------------------------------
# Request model
# ---------------------------------------------------------

class PredictionRequest(BaseModel):
    description: str


# ---------------------------------------------------------
# Prediction endpoint
# ---------------------------------------------------------

@app.post("/predict")
def predict(request: PredictionRequest):
    description = request.description.strip()

    if not description:
        return {
            "category": "Unknown",
            "confidence": 0.0
        }

    description_tfidf = vectorizer.transform([description])

    prediction = model.predict(description_tfidf)[0]

    probabilities = model.predict_proba(description_tfidf)[0]

    confidence = float(max(probabilities))

    return {
        "category": str(prediction),
        "confidence": round(confidence, 2)
    }