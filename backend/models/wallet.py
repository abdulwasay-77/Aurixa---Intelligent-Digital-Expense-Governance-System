"""
AURIXA Backend - Wallet Pydantic Models
Request and response schemas for Wallet and Transaction management
"""

from pydantic import BaseModel, Field, validator
from typing import Optional, List
from datetime import datetime


# ========================================================================
# Wallet Models
# ========================================================================

class WalletResponse(BaseModel):
    """Response model for a digital wallet"""
    wallet_id: int
    user_id: int
    currency_code: str
    currency_symbol: str
    balance: float
    wallet_type: str  # PRIMARY, SAVINGS, FOREIGN
    is_active: bool
    created_at: datetime


class WalletListResponse(BaseModel):
    """Response model for list of wallets"""
    wallets: List[WalletResponse]
    total_balance_usd: float
    primary_wallet_balance: float


class CreateWalletRequest(BaseModel):
    """Request model for creating a new wallet"""
    currency_code: str = Field(default="USD", pattern="^(PKR|USD|EUR|GBP)$")
    wallet_type: str = Field(default="SAVINGS", pattern="^(PRIMARY|SAVINGS|FOREIGN)$")
    initial_balance: float = Field(default=0, ge=0)


# ========================================================================
# Transaction Models
# ========================================================================

class TransactionResponse(BaseModel):
    """Response model for a transaction"""
    txn_id: int
    user_id: int
    wallet_id: int
    wallet_currency: Optional[str] = None
    category_name: Optional[str] = None
    subscription_name: Optional[str] = None
    amount: float
    amount_usd: Optional[float] = None
    txn_type: str  # DEBIT, CREDIT, REFUND
    description: Optional[str] = None
    txn_date: datetime
    is_recurring: bool
    is_anomaly: bool


class TransactionListResponse(BaseModel):
    """Response model for paginated transaction list"""
    transactions: List[TransactionResponse]
    total_count: int
    total_debits: float
    total_credits: float
    page: int
    page_size: int


class CreateTransactionRequest(BaseModel):
    """Request model for creating a new transaction"""
    wallet_id: int
    amount: float = Field(..., gt=0)
    txn_type: str = Field(..., pattern="^(DEBIT|CREDIT|REFUND)$")
    description: Optional[str] = Field(None, max_length=255)
    category_name: Optional[str] = None
    subscription_id: Optional[int] = None
    
    @validator('amount')
    def validate_amount(cls, v):
        if v <= 0:
            raise ValueError('Amount must be greater than 0')
        return v


class TopUpRequest(BaseModel):
    """Request model for topping up wallet"""
    wallet_id: int
    amount: float = Field(..., gt=0)
    payment_method: Optional[str] = Field(None, max_length=50)
    description: Optional[str] = Field(None, max_length=255)


# ========================================================================
# Transfer Models
# ========================================================================

class TransferRequest(BaseModel):
    """Request model for transferring between wallets"""
    from_wallet_id: int
    to_wallet_id: int
    amount: float = Field(..., gt=0)
    description: Optional[str] = None


class TransferResponse(BaseModel):
    """Response model for transfer operation"""
    from_transaction_id: int
    to_transaction_id: int
    amount: float
    from_currency: str
    to_currency: str
    converted_amount: float
    message: str


# ========================================================================
# Balance Models
# ========================================================================

class BalanceSummaryResponse(BaseModel):
    """Response model for balance summary"""
    total_balance: float
    total_balance_usd: float
    primary_wallet_balance: float
    savings_wallet_balance: float
    foreign_wallet_balance: float
    currency_breakdown: dict


class MonthlySpendingResponse(BaseModel):
    """Response model for monthly spending report"""
    month: str
    total_spent: float
    subscription_spent: float
    other_spent: float
    transaction_count: int