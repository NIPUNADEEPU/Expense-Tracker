import csv
import re

from config import (
    CATEGORY_MAPPING,
    DATASET_PATH,
    EXPENSE_TRANSACTION_TYPE,
    SUPPLEMENTARY_DATASET_PATH,
)


def clean_description(description):
    """
    Clean a transaction description so it is easier for the ML model
    to learn useful text patterns.
    """

    description = str(description).lower()

    # Replace anything that is not a letter or number with a space.
    description = re.sub(r"[^a-z0-9\s]", " ", description)

    # Replace multiple spaces with one space.
    description = re.sub(r"\s+", " ", description)

    return description.strip()


def load_original_data():
    """
    Load the original transaction dataset.

    Only debit transactions are used for expense classification.
    Credit transactions remain in the original CSV and are not deleted.
    """

    prepared_data = []

    with open(DATASET_PATH, "r", encoding="utf-8", newline="") as file:
        reader = csv.DictReader(file)

        for row in reader:
            transaction_type = row["Transaction Type"].strip().lower()
            original_category = row["Category"].strip()

            # Use only debit transactions for expense classification.
            if transaction_type != EXPENSE_TRANSACTION_TYPE:
                continue

            # Skip any category that does not have a mapping.
            if original_category not in CATEGORY_MAPPING:
                continue

            description = clean_description(row["Description"])

            # Skip empty descriptions.
            if not description:
                continue

            spend_sense_category = CATEGORY_MAPPING[original_category]

            prepared_data.append(
                {
                    "description": description,
                    "category": spend_sense_category,
                }
            )

    return prepared_data


def load_supplementary_data():
    """
    Load additional labelled transaction examples.

    These examples are already labelled using the agreed
    SpendSense categories.
    """

    prepared_data = []

    with open(
        SUPPLEMENTARY_DATASET_PATH,
        "r",
        encoding="utf-8",
        newline="",
    ) as file:
        reader = csv.DictReader(file)

        for row in reader:
            description = clean_description(row["Description"])
            category = row["Category"].strip()

            # Skip empty descriptions.
            if not description:
                continue

            # Only accept our agreed SpendSense categories.
            if category not in CATEGORY_MAPPING.values():
                continue

            prepared_data.append(
                {
                    "description": description,
                    "category": category,
                }
            )

    return prepared_data


def load_and_prepare_data():
    """
    Load and combine the original and supplementary datasets.
    """

    original_data = load_original_data()
    supplementary_data = load_supplementary_data()

    return original_data + supplementary_data


if __name__ == "__main__":
    data = load_and_prepare_data()

    print("Preprocessing completed successfully.")
    print(f"Training-ready transactions: {len(data)}")

    print("\nFirst 5 prepared transactions:")

    for row in data[:5]:
        print(
            f"Description: {row['description']} "
            f"-> Category: {row['category']}"
        )