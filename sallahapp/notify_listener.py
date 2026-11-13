"""
SALLAH — push-notification listener, REST-only version.

Earlier versions used the google-cloud-firestore library, which talks
to Firestore over gRPC (a binary HTTP/2 streaming protocol). On this
network, gRPC's TCP handshake to Google's servers was being blocked/
dropped outright (confirmed: "tcp handshaker shutdown" after a 5-minute
timeout) — while your Flutter app, which uses plain REST/HTTPS for
Firestore, has been working the entire time. This version uses that
same plain REST approach via `requests`, matching what already works.

SETUP:
    pip install requests google-auth firebase-admin

    Keep firebase-key.json next to this file (same as before) — it's
    still used, just for messaging (FCM) and for the REST auth token.

RUN:
    python notify_listener_rest.py
"""

import time
from datetime import datetime, timezone

import requests
import firebase_admin
from firebase_admin import credentials, messaging
from google.oauth2 import service_account
from google.auth.transport.requests import Request as GoogleAuthRequest

SERVICE_ACCOUNT_FILE = "firebase-key.json"
PROJECT_ID = "sallahapp-63361"
BASE_URL = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents"

# ---------------------------------------------------------------
# Auth: get a bearer token via plain HTTPS (not gRPC)
# ---------------------------------------------------------------
_creds = service_account.Credentials.from_service_account_file(
    SERVICE_ACCOUNT_FILE,
    scopes=["https://www.googleapis.com/auth/datastore"],
)


def _access_token() -> str:
    if not _creds.valid:
        _creds.refresh(GoogleAuthRequest())
    return _creds.token


def _headers() -> dict:
    return {"Authorization": f"Bearer {_access_token()}"}


# ---------------------------------------------------------------
# Firestore REST value <-> plain Python dict conversion
# ---------------------------------------------------------------
def _decode_value(v: dict):
    if "stringValue" in v:
        return v["stringValue"]
    if "integerValue" in v:
        return int(v["integerValue"])
    if "doubleValue" in v:
        return float(v["doubleValue"])
    if "booleanValue" in v:
        return v["booleanValue"]
    if "timestampValue" in v:
        return v["timestampValue"]  # ISO string — good enough for comparisons here
    if "nullValue" in v:
        return None
    if "mapValue" in v:
        return _decode_fields(v["mapValue"].get("fields", {}))
    if "arrayValue" in v:
        return [_decode_value(x) for x in v["arrayValue"].get("values", [])]
    return None


def _decode_fields(fields: dict) -> dict:
    return {k: _decode_value(v) for k, v in fields.items()}


def _decode_doc(doc: dict) -> dict:
    data = _decode_fields(doc.get("fields", {}))
    data["_id"] = doc["name"].rsplit("/", 1)[-1]
    return data


# ---------------------------------------------------------------
# FCM sending (unchanged — this part already worked over REST-like
# HTTPS calls via firebase-admin's own messaging module)
# ---------------------------------------------------------------
firebase_admin.initialize_app(credentials.Certificate(SERVICE_ACCOUNT_FILE))


def log(message: str) -> None:
    ts = datetime.now(timezone.utc).strftime("%H:%M:%S")
    print(f"[{ts}] {message}", flush=True)


def send_to_token(token, title, body, data=None):
    if not token:
        return
    try:
        messaging.send(
            messaging.Message(
                token=token,
                notification=messaging.Notification(title=title, body=body),
                data={k: str(v) for k, v in (data or {}).items()},
            )
        )
        log(f"✅ sent '{title}' -> ...{token[-8:]}")
    except Exception as e:  # noqa: BLE001
        log(f"⚠️  failed to send to ...{token[-8:] if token else '?'}: {e}")


def send_to_tokens(tokens, title, body, data=None):
    clean = list({t for t in tokens if t})
    if not clean:
        return
    for i in range(0, len(clean), 500):
        chunk = clean[i : i + 500]
        try:
            resp = messaging.send_each_for_multicast(
                messaging.MulticastMessage(
                    tokens=chunk,
                    notification=messaging.Notification(title=title, body=body),
                    data={k: str(v) for k, v in (data or {}).items()},
                )
            )
            log(f"✅ sent '{title}' to {resp.success_count}/{len(chunk)} technicians")
        except Exception as e:  # noqa: BLE001
            log(f"⚠️  multicast failed: {e}")


# ---------------------------------------------------------------
# Notification triggers
# ---------------------------------------------------------------
def on_request_created(request_id: str, data: dict) -> None:
    skill_id = str(data.get("serviceType", "")).replace("sos_", "")
    if not skill_id:
        return
    resp = requests.get(f"{BASE_URL}/technicians", headers=_headers(), timeout=15)
    resp.raise_for_status()
    docs = [_decode_doc(d) for d in resp.json().get("documents", [])]
    tokens = [
        t.get("fcmToken")
        for t in docs
        if t.get("isOnline") and skill_id in (t.get("skills") or [])
    ]
    send_to_tokens(
        tokens,
        "🔔 Nouvelle demande près de vous",
        f"{data.get('serviceLabel', 'Service')} — budget {data.get('budgetMAD', '?')} MAD",
        {"type": "new_request", "requestId": request_id},
    )


def on_offer_created(request_id: str, offer: dict) -> None:
    resp = requests.get(f"{BASE_URL}/requests/{request_id}", headers=_headers(), timeout=15)
    if resp.status_code != 200:
        return
    request = _decode_doc(resp.json())
    client_resp = requests.get(
        f"{BASE_URL}/users/{request['clientId']}", headers=_headers(), timeout=15
    )
    if client_resp.status_code != 200:
        return
    client = _decode_doc(client_resp.json())
    token = client.get("fcmToken")
    total = (offer.get("priceMAD") or 0) + (offer.get("transportFeeMAD") or 0)
    send_to_token(
        token,
        "💬 Nouvelle offre reçue",
        f"{offer.get('techName', 'Un technicien')} propose {total} MAD",
        {"type": "new_offer", "requestId": request_id},
    )


_STATUS_MESSAGES = {
    "accepted": ("technicians", "✅ Le client vous a choisi", "Préparez-vous à intervenir"),
    "en_route": ("users", "🚗 Votre technicien est en route", "Il arrive bientôt"),
    "in_progress": ("users", "🔧 Le travail a commencé", "Votre technicien est sur place"),
    "completed": ("users", "🎉 Mission terminée !", "Notez votre expérience et gagnez un crédit"),
}


def on_report_created(report_id: str, report: dict) -> None:
    resp = requests.get(f"{BASE_URL}/admins", headers=_headers(), timeout=15)
    if resp.status_code != 200:
        return
    admins = [_decode_doc(d) for d in resp.json().get("documents", [])]
    tokens = [a.get("fcmToken") for a in admins]
    is_urgent = report.get("urgent") is True
    title = "🚨🚨 URGENCE — action immédiate requise" if is_urgent else "🚩 Nouveau signalement"
    send_to_tokens(
        tokens,
        title,
        f"{report.get('reason', 'Signalement')} — {report.get('comment', '')[:80]}",
        {"type": "urgent_report" if is_urgent else "new_report", "requestId": report_id},
    )


def on_status_changed(request_id: str, data: dict, new_status: str) -> None:
    entry = _STATUS_MESSAGES.get(new_status)
    if not entry:
        return
    collection, title, body = entry
    doc_id = data["clientId"] if collection == "users" else data.get("techId")
    if not doc_id:
        return
    resp = requests.get(f"{BASE_URL}/{collection}/{doc_id}", headers=_headers(), timeout=15)
    if resp.status_code != 200:
        return
    token = _decode_doc(resp.json()).get("fcmToken")
    send_to_token(token, title, body, {"type": f"status_{new_status}", "requestId": request_id})


# ---------------------------------------------------------------
# Polling loop — plain REST GET calls, no gRPC, no streaming
# ---------------------------------------------------------------
POLL_SECONDS = 4
_last_status: dict[str, str] = {}
_last_offer_ids: set[str] = set()
_last_report_ids: set[str] = set()
_startup_done = False


def poll_requests() -> int:
    resp = requests.get(f"{BASE_URL}/requests", headers=_headers(), timeout=15)
    resp.raise_for_status()
    docs = [_decode_doc(d) for d in resp.json().get("documents", [])]

    for data in docs:
        doc_id = data["_id"]
        status = data.get("status", "")

        if doc_id not in _last_status:
            _last_status[doc_id] = status
            if status == "pending" and _startup_done:
                log(f"  -> new pending request {doc_id}, notifying technicians")
                on_request_created(doc_id, data)
            continue

        if _last_status.get(doc_id) != status:
            log(f"  -> status changed for {doc_id}: {_last_status.get(doc_id)} -> {status}")
            on_status_changed(doc_id, data, status)
            _last_status[doc_id] = status

    return len(docs)


def poll_offers() -> int:
    # collectionGroup query via the :runQuery endpoint (still plain REST/HTTPS)
    body = {
        "structuredQuery": {
            "from": [{"collectionId": "offers", "allDescendants": True}],
        }
    }
    resp = requests.post(f"{BASE_URL}:runQuery", headers=_headers(), json=body, timeout=15)
    resp.raise_for_status()
    results = resp.json()

    found_new = 0
    for row in results:
        doc = row.get("document")
        if not doc:
            continue
        offer_id = doc["name"]
        if offer_id in _last_offer_ids:
            continue
        _last_offer_ids.add(offer_id)
        found_new += 1
        if not _startup_done:
            continue  # don't spam-notify about offers that already existed
        offer = _decode_doc(doc)
        # name looks like: .../requests/{requestId}/offers/{offerId}
        request_id = doc["name"].split("/requests/")[1].split("/offers/")[0]
        log(f"  -> new offer on request {request_id}")
        on_offer_created(request_id, offer)

    return found_new


def poll_reports() -> int:
    resp = requests.get(f"{BASE_URL}/reports", headers=_headers(), timeout=15)
    resp.raise_for_status()
    docs = [_decode_doc(d) for d in resp.json().get("documents", [])]
    found_new = 0
    for data in docs:
        report_id = data["_id"]
        if report_id in _last_report_ids:
            continue
        _last_report_ids.add(report_id)
        found_new += 1
        if not _startup_done:
            continue  # don't spam-notify about reports filed before this run started
        log(f"  -> new report {report_id}: {data.get('reason', '')}")
        on_report_created(report_id, data)
    return found_new


def main() -> None:
    global _startup_done
    log("Starting SALLAH notification listener — REST polling mode (Ctrl+C to stop)…")
    log(f"Project: {PROJECT_ID}")
    log(f"Polling every {POLL_SECONDS}s over plain HTTPS (no gRPC)…")

    tick = 0
    while True:
        tick += 1
        try:
            n_req = poll_requests()
            n_off = poll_offers()
            n_rep = poll_reports()
            if tick == 1:
                log(f"✓ first poll OK — {n_req} request(s), {n_off} offer(s), "
                    f"{n_rep} report(s) indexed (this proves the connection works)")
                _startup_done = True
            elif n_off or n_rep:
                log(f"poll #{tick}: {n_req} request(s) total, {n_off} new offer(s), "
                    f"{n_rep} new report(s)")
        except Exception as e:  # noqa: BLE001
            log(f"❌ ERROR during poll: {e}")
        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    main()