from pathlib import Path


# ---------------------------------------------------------
# File paths
# ---------------------------------------------------------

ML_DIR = Path(__file__).resolve().parent

DATASET_PATH = ML_DIR / "dataset" / "transactions.csv"


# ---------------------------------------------------------
# SpendSense expense categories
# ---------------------------------------------------------

EXPENSE_CATEGORIES = [
    "Food",
    "Travel",
    "Shopping",
    "Bills",
    "Entertainment",
    "Home",
    "Personal Care",
    "Financial",
]


# ---------------------------------------------------------
# Original dataset category → SpendSense category
# ---------------------------------------------------------

CATEGORY_MAPPING = {
    # Food
    "Restaurants": "Food",
    "Fast Food": "Food",
    "Coffee Shops": "Food",
    "Groceries": "Food",
    "Alcohol & Bars": "Food",
    "Food & Dining": "Food",

    # Travel
    "Gas & Fuel": "Travel",

    # Shopping
    "Shopping": "Shopping",
    "Electronics & Software": "Shopping",

    # Bills
    "Utilities": "Bills",
    "Internet": "Bills",
    "Mortgage & Rent": "Bills",
    "Mobile Phone": "Bills",
    "Auto Insurance": "Bills",
    "Television": "Bills",

    # Entertainment
    "Music": "Entertainment",
    "Movies & Dvds": "Entertainment",
    "Entertainment": "Entertainment",

    # Home
    "Home Improvement": "Home",

    # Personal Care
    "Haircut": "Personal Care",

    # Financial
    "Credit Card Payment": "Financial",
}


# ---------------------------------------------------------
# Transaction types used for expense classification
# ---------------------------------------------------------

EXPENSE_TRANSACTION_TYPE = "debit"