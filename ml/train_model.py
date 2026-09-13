from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, classification_report
from sklearn.model_selection import train_test_split
import joblib

from preprocess import load_and_prepare_data


# ---------------------------------------------------------
# Load prepared data
# ---------------------------------------------------------

data = load_and_prepare_data()

descriptions = [row["description"] for row in data]
categories = [row["category"] for row in data]


# ---------------------------------------------------------
# Split data into training and testing sets
# ---------------------------------------------------------

X_train, X_test, y_train, y_test = train_test_split(
    descriptions,
    categories,
    test_size=0.20,
    random_state=42,
    stratify=categories,
)

print("Train/test split completed successfully.")
print(f"Total transactions: {len(data)}")
print(f"Training transactions: {len(X_train)}")
print(f"Testing transactions: {len(X_test)}")


# ---------------------------------------------------------
# Create TF-IDF features
# ---------------------------------------------------------

vectorizer = TfidfVectorizer()

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
)

model.fit(X_train_tfidf, y_train)

print("\nModel training completed successfully.")


# ---------------------------------------------------------
# Evaluate the model
# ---------------------------------------------------------

y_pred = model.predict(X_test_tfidf)

accuracy = accuracy_score(y_test, y_pred)

print("\nModel Evaluation")
print("----------------")
print(f"Accuracy: {accuracy * 100:.2f}%")

print("\nClassification Report")
print("---------------------")
print(classification_report(y_test, y_pred, zero_division=0))


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
# Save trained model and TF-IDF vectorizer
# ---------------------------------------------------------

joblib.dump(model, "ml/expense_model.pkl")
joblib.dump(vectorizer, "ml/tfidf_vectorizer.pkl")

print("\nModel files saved successfully.")
print("Saved: ml/expense_model.pkl")
print("Saved: ml/tfidf_vectorizer.pkl")