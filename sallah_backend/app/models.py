from datetime import datetime
from enum import Enum
from pydantic import BaseModel, Field


class TransactionType(str, Enum):
    topup = "topup"
    commission_deduction = "commission_deduction"
    refund = "refund"


class WalletTopupRequest(BaseModel):
    tech_id: str
    amount_mad: float = Field(gt=0)
    method: str  # 'bank_transfer' | 'wafacash' | 'cash_plus' | 'in_app'


class WalletTransaction(BaseModel):
    txn_id: str
    tech_id: str
    amount_mad: float
    type: TransactionType
    description: str
    timestamp: datetime


class CommissionDeductionRequest(BaseModel):
    request_id: str
    tech_id: str
    price_quote_mad: float = Field(gt=0)


class CommissionDeductionResult(BaseModel):
    txn_id: str
    tech_id: str
    commission_mad: float
    new_wallet_balance: float
    request_id: str