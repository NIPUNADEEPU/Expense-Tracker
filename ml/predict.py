import sys
import joblib


# ---------------------------------------------------------
# Load trained model and TF-IDF vectorizer
# ---------------------------------------------------------

model = joblib.load("ml/expense_model.pkl")
vectorizer = joblib.load("ml/tfidf_vectorizer.pkl")


# ---------------------------------------------------------
# Get transaction description
# ---------------------------------------------------------

if len(sys.argv) < 2:
    print("Please provide a transaction description.")
    print('Example: python ml/predict.py "pizza hut"')
    sys.exit(1)

description = " ".join(sys.argv[1:])


# ---------------------------------------------------------
# Convert description into TF-IDF features
# ---------------------------------------------------------

description_tfidf = vectorizer.transform([description])


# ---------------------------------------------------------
# Predict category
# ---------------------------------------------------------

prediction = model.predict(description_tfidf)[0]


# ---------------------------------------------------------
# Calculate prediction confidence
# ---------------------------------------------------------

probabilities = model.predict_proba(description_tfidf)[0]
confidence = max(probabilities)


# ---------------------------------------------------------
# Display result
# ---------------------------------------------------------

print(f"Description: {description}")
print(f"Predicted category: {prediction}")
print(f"Confidence: {confidence:.2f}")