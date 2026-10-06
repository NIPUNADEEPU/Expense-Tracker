from pathlib import Path
import sys

import joblib


# ---------------------------------------------------------
# Project paths
# ---------------------------------------------------------

ML_DIR = Path(__file__).resolve().parent

MODEL_PATH = ML_DIR / "expense_model.pkl"
VECTORIZER_PATH = ML_DIR / "tfidf_vectorizer.pkl"


# ---------------------------------------------------------
# Load trained model and TF-IDF vectorizer
# ---------------------------------------------------------

model = joblib.load(MODEL_PATH)
vectorizer = joblib.load(VECTORIZER_PATH)


# ---------------------------------------------------------
# Get transaction description
# ---------------------------------------------------------

if len(sys.argv) < 2:
    print("Please provide a transaction description.")
    print('Example: python predict.py "pizza hut"')
    sys.exit(1)


description = " ".join(sys.argv[1:])


# ---------------------------------------------------------
# Convert description to TF-IDF
# ---------------------------------------------------------

description_tfidf = vectorizer.transform([description])


# ---------------------------------------------------------
# Predict category
# ---------------------------------------------------------

prediction = model.predict(description_tfidf)[0]

probabilities = model.predict_proba(description_tfidf)[0]

confidence = max(probabilities)


# ---------------------------------------------------------
# Display result
# ---------------------------------------------------------

print(f"Description: {description}")
print(f"Predicted category: {prediction}")
print(f"Confidence: {confidence:.2f}")