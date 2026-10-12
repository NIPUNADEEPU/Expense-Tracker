from pathlib import Path
import sys

import joblib
from fastapi import FastAPI
from pydantic import BaseModel
from sklearn import __version__ as sklearn_version


# ---------------------------------------------------------
# Project paths
# ---------------------------------------------------------

BASE_DIR = Path(__file__).resolve().parent.parent
ML_DIR = BASE_DIR / "ml"
sys.path.insert(0, str(ML_DIR))

from preprocess import clean_description

MODEL_PATH = ML_DIR / "expense_model.pkl"
VECTORIZER_PATH = ML_DIR / "tfidf_vectorizer.pkl"


# ---------------------------------------------------------
# Load trained model and TF-IDF vectorizer ONCE
# ---------------------------------------------------------

model = joblib.load(MODEL_PATH)
vectorizer = joblib.load(VECTORIZER_PATH)

CATEGORY_ALIASES = {
    'food': 'Food',
    'food & dining': 'Food',
    'travel': 'Travel',
    'shopping': 'Shopping',
    'bills': 'Bills',
    'utilities': 'Bills',
    'entertainment': 'Entertainment',
    'home': 'Home',
    'personal care': 'Personal Care',
    'personalcare': 'Personal Care',
    'financial': 'Financial',
    'finance': 'Financial',
}


def normalize_prediction_label(label):
    label = str(label).strip()
    if not label:
        return 'Unknown'

    normalized = label.replace('_', ' ').replace('-', ' ')
    normalized = ' '.join(normalized.split())
    lowered = normalized.lower()

    return CATEGORY_ALIASES.get(lowered, normalized)


print(f"Loaded model and vectorizer with scikit-learn {sklearn_version}")


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
    description = clean_description(request.description)

    if not description:
        return {
            "category": "Unknown",
            "confidence": 0.0
        }

    description_tfidf = vectorizer.transform([description])

    prediction = model.predict(description_tfidf)[0]
    category = normalize_prediction_label(prediction)

    probabilities = model.predict_proba(description_tfidf)[0]

    confidence = float(max(probabilities))

    return {
        "category": category,
        "confidence": round(confidence, 2)
    }
