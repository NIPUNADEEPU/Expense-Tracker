from pathlib import Path

from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, classification_report
from sklearn.model_selection import train_test_split
import joblib

from preprocess import load_original_data, load_supplementary_data


# ---------------------------------------------------------
# Project paths
# ---------------------------------------------------------

ML_DIR = Path(__file__).resolve().parent

MODEL_PATH = ML_DIR / "expense_model.pkl"
VECTORIZER_PATH = ML_DIR / "tfidf_vectorizer.pkl"


# ---------------------------------------------------------
# Load original and supplementary data
# ---------------------------------------------------------

original_data = load_original_data()
supplementary_data = load_supplementary_data()

original_descriptions = [
    row["description"]
    for row in original_data
]

original_categories = [
    row["category"]
    for row in original_data
]

supplementary_descriptions = [
    row["description"]
    for row in supplementary_data
]

supplementary_categories = [
    row["category"]
    for row in supplementary_data
]

print("Original dataset:", len(original_data))
print("Supplementary examples:", len(supplementary_data))


# ---------------------------------------------------------
# Split original data into training and testing sets
# ---------------------------------------------------------

X_train, X_test, y_train, y_test = train_test_split(
    original_descriptions,
    original_categories,
    test_size=0.20,
    random_state=42,
    stratify=original_categories,
)

print("\nOriginal train/test split completed.")
print(f"Original training transactions: {len(X_train)}")
print(f"Original testing transactions: {len(X_test)}")


# ---------------------------------------------------------
# Add supplementary examples only to training data
# ---------------------------------------------------------

X_train = X_train + supplementary_descriptions
y_train = y_train + supplementary_categories

print("\nSupplementary examples added to training data.")
print(f"Final training transactions: {len(X_train)}")
print(f"Final testing transactions: {len(X_test)}")


# ---------------------------------------------------------
# Create TF-IDF features
# ---------------------------------------------------------

vectorizer = TfidfVectorizer(
    ngram_range=(1, 2),
)

X_train_tfidf = vectorizer.fit_transform(X_train)
X_test_tfidf = vectorizer.transform(X_test)

print("\nTF-IDF feature creation completed successfully.")
print(
    f"Number of TF-IDF features: "
    f"{len(vectorizer.get_feature_names_out())}"
)


# ---------------------------------------------------------
# Train Logistic Regression model
# ---------------------------------------------------------

model = LogisticRegression(
    max_iter=1000,
    class_weight="balanced",
)

model.fit(X_train_tfidf, y_train)

print("\nImproved model training completed successfully.")


# ---------------------------------------------------------
# Evaluate the model
# ---------------------------------------------------------

y_pred = model.predict(X_test_tfidf)

accuracy = accuracy_score(y_test, y_pred)

print("\nImproved Model Evaluation")
print("-------------------------")
print(f"Accuracy: {accuracy * 100:.2f}%")

print("\nClassification Report")
print("---------------------")

print(
    classification_report(
        y_test,
        y_pred,
        zero_division=0,
    )
)


# ---------------------------------------------------------
# Show incorrect predictions
# ---------------------------------------------------------

print("\nIncorrect Predictions")
print("---------------------")

mistakes = 0

for description, actual, predicted in zip(
    X_test,
    y_test,
    y_pred,
):
    if actual != predicted:
        mistakes += 1

        print(f"Description: {description}")
        print(f"Actual: {actual} | Predicted: {predicted}")
        print()


print(f"Total mistakes: {mistakes}")


# ---------------------------------------------------------
# Save final model and TF-IDF vectorizer
# ---------------------------------------------------------

joblib.dump(model, MODEL_PATH)
joblib.dump(vectorizer, VECTORIZER_PATH)

print("\nFinal model files saved successfully.")
print(f"Saved: {MODEL_PATH}")
print(f"Saved: {VECTORIZER_PATH}")