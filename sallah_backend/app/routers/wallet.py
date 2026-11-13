import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException
from google.cloud.firestore_v1 import Increment, transactional

from ..firebase import get_firestore_client
from ..models import (
    CommissionDeductionRequest,
    CommissionDeductionResult,
    TransactionType,
    WalletTopupRequest,
)

router = APIRouter(prefix="/wallet", tags=["wallet"])

# Business rules from spec section 2.B.2
COMMISSION_RATE = 0.15
LOW_BALANCE_BLOCK_THRESHOLD_MAD = 10.0
MIN_TOPUP_TO_ACCEPT_JOBS_MAD = 50.0


def _new_txn_id() -> str:
    return f"txn_{uuid.uuid4().hex[:12]}"


@router.post("/topup")
def topup_wallet(payload: WalletTopupRequest):
    """Credits a technician's wallet after an external payment
    (bank transfer / Wafacash / Cash Plus / in-app) has been confirmed
    by whatever payment webhook or admin action triggers this call."""
    db = get_firestore_client()
    tech_ref = db.collection("technicians").document(payload.tech_id)
    tech_doc = tech_ref.get()
    if not tech_doc.exists:
        raise HTTPException(status_code=404, detail="Technician not found")

    txn_id = _new_txn_id()
    now = datetime.now(timezone.utc)

    batch = db.batch()
    batch.update(tech_ref, {"walletBalance": Increment(payload.amount_mad)})
    batch.set(
        db.collection("wallet_transactions").document(txn_id),
        {
            "txnId": txn_id,
            "techId": payload.tech_id,
            "amountMAD": payload.amount_mad,
            "type": TransactionType.topup.value,
            "description": f"Top-up via {payload.method}",
            "timestamp": now,
        },
    )
    batch.commit()

    updated_balance = tech_doc.to_dict().get("walletBalance", 0) + payload.amount_mad
    return {"txn_id": txn_id, "new_wallet_balance": updated_balance}


@router.post("/deduct-commission", response_model=CommissionDeductionResult)
def deduct_commission(payload: CommissionDeductionRequest):
    """Called the instant a technician accepts a job. Deducts the fixed
    commission rate from their wallet and blocks future job acceptance
    if the balance falls below the low-balance threshold. This must
    run as a Firestore transaction so two near-simultaneous accepts
    can't double-spend the same balance."""
    db = get_firestore_client()
    tech_ref = db.collection("technicians").document(payload.tech_id)

    commission_mad = round(payload.price_quote_mad * COMMISSION_RATE, 2)
    txn_id = _new_txn_id()
    now = datetime.now(timezone.utc)

    @transactional
    def _run(transaction):
        snapshot = tech_ref.get(transaction=transaction)
        if not snapshot.exists:
            raise HTTPException(status_code=404, detail="Technician not found")

        current_balance = snapshot.to_dict().get("walletBalance", 0)
        if current_balance < MIN_TOPUP_TO_ACCEPT_JOBS_MAD:
            raise HTTPException(
                status_code=402,
                detail="Wallet balance below minimum required to accept jobs",
            )

        new_balance = round(current_balance - commission_mad, 2)

        transaction.update(tech_ref, {
            "walletBalance": new_balance,
            # Once below the block threshold, isOnline is force-flipped
            # off so no further job requests are dispatched to them
            # until they top up again.
            "isOnline": new_balance >= LOW_BALANCE_BLOCK_THRESHOLD_MAD,
        })
        transaction.set(
            db.collection("wallet_transactions").document(txn_id),
            {
                "txnId": txn_id,
                "techId": payload.tech_id,
                "amountMAD": commission_mad,
                "type": TransactionType.commission_deduction.value,
                "description": f"Commission for request {payload.request_id}",
                "timestamp": now,
            },
        )
        return new_balance

    new_balance = _run(db.transaction())

    return CommissionDeductionResult(
        txn_id=txn_id,
        tech_id=payload.tech_id,
        commission_mad=commission_mad,
        new_wallet_balance=new_balance,
        request_id=payload.request_id,
    )


@router.post("/refund")
def refund_client_cancellation(request_id: str, tech_id: str, amount_mad: float):
    """Auto-refund path referenced in Module C: if a client cancels
    after a technician has been dispatched, the commission already
    deducted is credited back to the technician's wallet."""
    db = get_firestore_client()
    tech_ref = db.collection("technicians").document(tech_id)
    txn_id = _new_txn_id()
    now = datetime.now(timezone.utc)

    batch = db.batch()
    batch.update(tech_ref, {"walletBalance": Increment(amount_mad)})
    batch.set(
        db.collection("wallet_transactions").document(txn_id),
        {
            "txnId": txn_id,
            "techId": tech_id,
            "amountMAD": amount_mad,
            "type": TransactionType.refund.value,
            "description": f"Refund for cancelled request {request_id}",
            "timestamp": now,
        },
    )
    batch.commit()
    return {"txn_id": txn_id, "refunded_mad": amount_mad}