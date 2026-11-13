import os
import firebase_admin
from firebase_admin import credentials, firestore

_SERVICE_ACCOUNT_PATH = os.getenv(
    "FIREBASE_SERVICE_ACCOUNT", "serviceAccountKey.json"
)

_app = None


def get_firestore_client():
    """Lazily initializes the Firebase Admin app and returns a Firestore
    client. The service account key must never be committed to source
    control — load it from an env var / secret manager in production."""
    global _app
    if _app is None:
        cred = credentials.Certificate(_SERVICE_ACCOUNT_PATH)
        _app = firebase_admin.initialize_app(cred)
    return firestore.client()