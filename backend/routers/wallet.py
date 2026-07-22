"""
AURIXA Backend - Wallet Routes
Handles digital wallets, transactions, and fund transfers
"""

from fastapi import APIRouter, HTTPException, Depends, Header, Query
from fastapi import status as http_status
from typing import List, Optional
from datetime import datetime, date

from models.wallet import (
    WalletResponse, WalletListResponse, CreateWalletRequest,
    TransactionResponse, TransactionListResponse, CreateTransactionRequest,
    TopUpRequest, TransferRequest, TransferResponse,
    BalanceSummaryResponse, MonthlySpendingResponse
)
from models.user import MessageResponse
from database import db
from auth import auth_manager

router = APIRouter(prefix="/api/wallet", tags=["Wallet"])


# ========================================================================
# Helper Functions
# ========================================================================

async def get_current_user_id(authorization: str = Header(None)):
    """Extract user_id from JWT token"""
    if not authorization:
        raise HTTPException(
            status_code=http_status.HTTP_401_UNAUTHORIZED,
            detail="Missing authorization header"
        )
    
    parts = authorization.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(
            status_code=http_status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authorization header format. Use 'Bearer <token>'"
        )
    
    token = parts[1]
    user_id = auth_manager.get_user_id_from_token(token)
    
    if not user_id:
        raise HTTPException(
            status_code=http_status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token"
        )
    
    return user_id


def get_currency_id(currency_code: str) -> int:
    """Get currency_id from currency code"""
    result = db.execute_query(
        "SELECT currency_id FROM CURRENCIES WHERE code = :code",
        {"code": currency_code}
    )
    if not result:
        raise HTTPException(status_code=400, detail=f"Invalid currency code: {currency_code}")
    return result[0][0]


def get_currency_info(currency_id: int) -> tuple:
    """Get currency code and symbol"""
    result = db.execute_query(
        "SELECT code, symbol FROM CURRENCIES WHERE currency_id = :currency_id",
        {"currency_id": currency_id}
    )
    if not result:
        return "USD", "$"
    return result[0][0], result[0][1]


def get_category_id(category_name: str) -> Optional[int]:
    """Get category_id from category name"""
    if not category_name:
        return None
    result = db.execute_query(
        "SELECT category_id FROM EXPENSE_CATEGORIES WHERE name = :name",
        {"name": category_name}
    )
    return result[0][0] if result else None


def convert_currency(amount: float, from_currency: str, to_currency: str) -> float:
    """Convert amount between currencies using CONVERT_CURRENCY function"""
    try:
        result = db.execute_query(
            "SELECT CONVERT_CURRENCY(:amount, :from_code, :to_code) FROM DUAL",
            {"amount": amount, "from_code": from_currency, "to_code": to_currency}
        )
        return float(result[0][0]) if result else amount
    except Exception:
        return amount


def get_user_primary_wallet(user_id: int) -> Optional[int]:
    """Get user's primary wallet ID"""
    result = db.execute_query(
        "SELECT wallet_id FROM DIGITAL_WALLETS WHERE user_id = :user_id AND wallet_type = 'PRIMARY' AND is_active = 'Y'",
        {"user_id": user_id}
    )
    return result[0][0] if result else None


# ========================================================================
# Wallet Endpoints
# ========================================================================

@router.get("", response_model=WalletListResponse)
async def get_wallets(user_id: int = Depends(get_current_user_id)):
    """
    Get all wallets for the authenticated user.
    """
    result = db.execute_query(
        """SELECT w.wallet_id, w.user_id, w.currency_id, c.code, c.symbol,
                  w.balance, w.wallet_type, w.is_active, w.created_at
           FROM DIGITAL_WALLETS w
           JOIN CURRENCIES c ON w.currency_id = c.currency_id
           WHERE w.user_id = :user_id
           ORDER BY CASE w.wallet_type WHEN 'PRIMARY' THEN 1 WHEN 'SAVINGS' THEN 2 ELSE 3 END""",
        {"user_id": user_id}
    )
    
    wallets = []
    total_balance_usd = 0
    primary_balance = 0
    
    for row in result:
        wallet_id, user_id, currency_id, code, symbol, balance, wallet_type, is_active, created_at = row
        wallets.append(WalletResponse(
            wallet_id=wallet_id,
            user_id=user_id,
            currency_code=code,
            currency_symbol=symbol,
            balance=float(balance),
            wallet_type=wallet_type,
            is_active=is_active == 'Y',
            created_at=created_at
        ))
        
        # Convert to USD for total
        usd_balance = convert_currency(float(balance), code, "USD")
        total_balance_usd += usd_balance
        
        if wallet_type == 'PRIMARY':
            primary_balance = float(balance)
    
    return WalletListResponse(
        wallets=wallets,
        total_balance_usd=round(total_balance_usd, 2),
        primary_wallet_balance=round(primary_balance, 2)
    )


@router.post("", response_model=WalletResponse, status_code=http_status.HTTP_201_CREATED)
async def create_wallet(request: CreateWalletRequest, user_id: int = Depends(get_current_user_id)):
    """
    Create a new wallet (SAVINGS or FOREIGN type).
    PRIMARY wallet is created automatically during user registration.
    """
    # Check if user already has a PRIMARY wallet
    if request.wallet_type == 'PRIMARY':
        existing = db.execute_query(
            "SELECT wallet_id FROM DIGITAL_WALLETS WHERE user_id = :user_id AND wallet_type = 'PRIMARY'",
            {"user_id": user_id}
        )
        if existing:
            raise HTTPException(
                status_code=http_status.HTTP_400_BAD_REQUEST,
                detail="Primary wallet already exists"
            )
    
    currency_id = get_currency_id(request.currency_code)
    
    try:
        db.execute_update(
            """INSERT INTO DIGITAL_WALLETS 
               (wallet_id, user_id, currency_id, balance, wallet_type, is_active, created_at)
               VALUES (SEQ_WALLETS.NEXTVAL, :user_id, :currency_id, :balance, :wallet_type, 'Y', SYSDATE)""",
            {
                "user_id": user_id,
                "currency_id": currency_id,
                "balance": request.initial_balance,
                "wallet_type": request.wallet_type
            }
        )
        
        # Get the created wallet
        result = db.execute_query(
            """SELECT w.wallet_id, w.user_id, w.currency_id, c.code, c.symbol,
                      w.balance, w.wallet_type, w.is_active, w.created_at
               FROM DIGITAL_WALLETS w
               JOIN CURRENCIES c ON w.currency_id = c.currency_id
               WHERE w.user_id = :user_id AND w.wallet_type = :wallet_type
               ORDER BY w.wallet_id DESC FETCH FIRST 1 ROW ONLY""",
            {"user_id": user_id, "wallet_type": request.wallet_type}
        )
        
        if result:
            row = result[0]
            return WalletResponse(
                wallet_id=row[0],
                user_id=row[1],
                currency_code=row[3],
                currency_symbol=row[4],
                balance=float(row[5]),
                wallet_type=row[6],
                is_active=row[7] == 'Y',
                created_at=row[8]
            )
        
        raise HTTPException(status_code=500, detail="Failed to create wallet")
        
    except Exception as e:
        raise HTTPException(
            status_code=http_status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create wallet: {str(e)}"
        )


@router.get("/balance", response_model=BalanceSummaryResponse)
async def get_balance_summary(user_id: int = Depends(get_current_user_id)):
    """
    Get comprehensive balance summary across all wallets.
    """
    result = db.execute_query(
        """SELECT w.wallet_type, c.code, w.balance
           FROM DIGITAL_WALLETS w
           JOIN CURRENCIES c ON w.currency_id = c.currency_id
           WHERE w.user_id = :user_id AND w.is_active = 'Y'""",
        {"user_id": user_id}
    )
    
    total_balance = 0
    total_balance_usd = 0
    primary_balance = 0
    savings_balance = 0
    foreign_balance = 0
    currency_breakdown = {}
    
    for row in result:
        wallet_type, currency_code, balance = row
        balance_float = float(balance)
        total_balance += balance_float
        
        usd_balance = convert_currency(balance_float, currency_code, "USD")
        total_balance_usd += usd_balance
        
        if wallet_type == 'PRIMARY':
            primary_balance = balance_float
        elif wallet_type == 'SAVINGS':
            savings_balance = balance_float
        else:
            foreign_balance += balance_float
        
        if currency_code not in currency_breakdown:
            currency_breakdown[currency_code] = 0
        currency_breakdown[currency_code] += balance_float
    
    return BalanceSummaryResponse(
        total_balance=round(total_balance, 2),
        total_balance_usd=round(total_balance_usd, 2),
        primary_wallet_balance=round(primary_balance, 2),
        savings_wallet_balance=round(savings_balance, 2),
        foreign_wallet_balance=round(foreign_balance, 2),
        currency_breakdown={k: round(v, 2) for k, v in currency_breakdown.items()}
    )


# ========================================================================
# Transaction Endpoints
# ========================================================================

@router.get("/transactions", response_model=TransactionListResponse)
async def get_transactions(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    wallet_id: Optional[int] = None,
    txn_type: Optional[str] = Query(None, pattern="^(DEBIT|CREDIT|REFUND)$"),
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    user_id: int = Depends(get_current_user_id)
):
    """
    Get paginated list of transactions for the user.
    """
    # Build query conditions
    conditions = ["t.user_id = :user_id"]
    params = {"user_id": user_id, "limit": limit, "offset": offset}
    
    if wallet_id:
        conditions.append("t.wallet_id = :wallet_id")
        params["wallet_id"] = wallet_id
    
    if txn_type:
        conditions.append("t.txn_type = :txn_type")
        params["txn_type"] = txn_type
    
    if start_date:
        conditions.append("t.txn_date >= TO_DATE(:start_date, 'YYYY-MM-DD')")
        params["start_date"] = start_date
    
    if end_date:
        conditions.append("t.txn_date <= TO_DATE(:end_date, 'YYYY-MM-DD') + 1")
        params["end_date"] = end_date
    
    where_clause = " AND ".join(conditions)
    
    # Get transactions
    txns_result = db.execute_query(
        f"""SELECT t.txn_id, t.user_id, t.wallet_id, w.currency_id, c.code, c.symbol,
                  ec.name as category_name, s.service_name as subscription_name,
                  t.amount, t.amount_usd, t.txn_type, t.description, t.txn_date, 
                  t.is_recurring, t.is_anomaly
           FROM TRANSACTIONS t
           JOIN DIGITAL_WALLETS w ON t.wallet_id = w.wallet_id
           JOIN CURRENCIES c ON w.currency_id = c.currency_id
           LEFT JOIN EXPENSE_CATEGORIES ec ON t.category_id = ec.category_id
           LEFT JOIN SUBSCRIPTIONS s ON t.subscription_id = s.sub_id
           WHERE {where_clause}
           ORDER BY t.txn_date DESC
           OFFSET :offset ROWS FETCH NEXT :limit ROWS ONLY""",
        params
    )
    
    # Get totals
    total_result = db.execute_query(
        f"SELECT COUNT(*) FROM TRANSACTIONS t WHERE {where_clause}",
        {k: v for k, v in params.items() if k not in ["limit", "offset"]}
    )
    total_count = total_result[0][0] if total_result else 0
    
    debit_result = db.execute_query(
        f"SELECT NVL(SUM(t.amount), 0) FROM TRANSACTIONS t WHERE {where_clause} AND t.txn_type = 'DEBIT'",
        {k: v for k, v in params.items() if k not in ["limit", "offset"]}
    )
    total_debits = float(debit_result[0][0]) if debit_result else 0
    
    credit_result = db.execute_query(
        f"SELECT NVL(SUM(t.amount), 0) FROM TRANSACTIONS t WHERE {where_clause} AND t.txn_type = 'CREDIT'",
        {k: v for k, v in params.items() if k not in ["limit", "offset"]}
    )
    total_credits = float(credit_result[0][0]) if credit_result else 0
    
    # Build response
    transactions = []
    for row in txns_result:
        (txn_id, user_id, wallet_id, currency_id, currency_code, currency_symbol,
         category_name, subscription_name, amount, amount_usd, txn_type, 
         description, txn_date, is_recurring, is_anomaly) = row
        
        transactions.append(TransactionResponse(
            txn_id=txn_id,
            user_id=user_id,
            wallet_id=wallet_id,
            wallet_currency=currency_symbol,
            category_name=category_name,
            subscription_name=subscription_name,
            amount=float(amount),
            amount_usd=float(amount_usd) if amount_usd else None,
            txn_type=txn_type,
            description=description,
            txn_date=txn_date,
            is_recurring=is_recurring == 'Y',
            is_anomaly=is_anomaly == 'Y'
        ))
    
    return TransactionListResponse(
        transactions=transactions,
        total_count=total_count,
        total_debits=round(total_debits, 2),
        total_credits=round(total_credits, 2),
        page=offset // limit + 1 if limit > 0 else 1,
        page_size=limit
    )


@router.post("/transactions", response_model=TransactionResponse, status_code=http_status.HTTP_201_CREATED)
async def create_transaction(request: CreateTransactionRequest, user_id: int = Depends(get_current_user_id)):
    """
    Create a new transaction (debit, credit, or refund).
    """
    # Verify wallet ownership
    wallet_result = db.execute_query(
        "SELECT wallet_id, currency_id FROM DIGITAL_WALLETS WHERE wallet_id = :wallet_id AND user_id = :user_id",
        {"wallet_id": request.wallet_id, "user_id": user_id}
    )
    
    if not wallet_result:
        raise HTTPException(
            status_code=http_status.HTTP_404_NOT_FOUND,
            detail="Wallet not found or does not belong to user"
        )
    
    currency_id = wallet_result[0][1]
    currency_code_result = db.execute_query(
        "SELECT code FROM CURRENCIES WHERE currency_id = :currency_id",
        {"currency_id": currency_id}
    )
    currency_code = currency_code_result[0][0] if currency_code_result else "USD"
    
    # Convert to USD if needed
    amount_usd = convert_currency(request.amount, currency_code, "USD")
    
    # Get category_id if provided
    category_id = get_category_id(request.category_name) if request.category_name else None
    
    # Verify subscription ownership if provided
    if request.subscription_id:
        sub_result = db.execute_query(
            "SELECT sub_id FROM SUBSCRIPTIONS WHERE sub_id = :sub_id AND user_id = :user_id",
            {"sub_id": request.subscription_id, "user_id": user_id}
        )
        if not sub_result:
            raise HTTPException(
                status_code=http_status.HTTP_404_NOT_FOUND,
                detail="Subscription not found or does not belong to user"
            )
    
    # Update wallet balance
    if request.txn_type == 'DEBIT':
        db.execute_update(
            "UPDATE DIGITAL_WALLETS SET balance = balance - :amount WHERE wallet_id = :wallet_id",
            {"amount": request.amount, "wallet_id": request.wallet_id}
        )
    elif request.txn_type == 'CREDIT' or request.txn_type == 'REFUND':
        db.execute_update(
            "UPDATE DIGITAL_WALLETS SET balance = balance + :amount WHERE wallet_id = :wallet_id",
            {"amount": request.amount, "wallet_id": request.wallet_id}
        )
    
    # Insert transaction
    try:
        db.execute_update(
            """INSERT INTO TRANSACTIONS 
               (txn_id, user_id, wallet_id, category_id, subscription_id,
                amount, currency_id, amount_usd, txn_type, description, txn_date)
               VALUES (SEQ_TRANSACTIONS.NEXTVAL, :user_id, :wallet_id, :category_id, :subscription_id,
                       :amount, :currency_id, :amount_usd, :txn_type, :description, SYSDATE)""",
            {
                "user_id": user_id,
                "wallet_id": request.wallet_id,
                "category_id": category_id,
                "subscription_id": request.subscription_id,
                "amount": request.amount,
                "currency_id": currency_id,
                "amount_usd": amount_usd,
                "txn_type": request.txn_type,
                "description": request.description
            }
        )
        
        # Get the created transaction
        result = db.execute_query(
            """SELECT t.txn_id, t.user_id, t.wallet_id, w.currency_id, c.code, c.symbol,
                      ec.name as category_name, s.service_name as subscription_name,
                      t.amount, t.amount_usd, t.txn_type, t.description, t.txn_date, 
                      t.is_recurring, t.is_anomaly
               FROM TRANSACTIONS t
               JOIN DIGITAL_WALLETS w ON t.wallet_id = w.wallet_id
               JOIN CURRENCIES c ON w.currency_id = c.currency_id
               LEFT JOIN EXPENSE_CATEGORIES ec ON t.category_id = ec.category_id
               LEFT JOIN SUBSCRIPTIONS s ON t.subscription_id = s.sub_id
               WHERE t.user_id = :user_id
               ORDER BY t.txn_id DESC FETCH FIRST 1 ROW ONLY""",
            {"user_id": user_id}
        )
        
        if result:
            row = result[0]
            return TransactionResponse(
                txn_id=row[0],
                user_id=row[1],
                wallet_id=row[2],
                wallet_currency=row[5],
                category_name=row[6],
                subscription_name=row[7],
                amount=float(row[8]),
                amount_usd=float(row[9]) if row[9] else None,
                txn_type=row[10],
                description=row[11],
                txn_date=row[12],
                is_recurring=row[13] == 'Y',
                is_anomaly=row[14] == 'Y'
            )
        
        raise HTTPException(status_code=500, detail="Failed to create transaction")
        
    except Exception as e:
        raise HTTPException(
            status_code=http_status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create transaction: {str(e)}"
        )


@router.post("/topup", response_model=TransactionResponse)
async def topup_wallet(request: TopUpRequest, user_id: int = Depends(get_current_user_id)):
    """
    Add funds to a wallet (top-up).
    """
    return await create_transaction(
        CreateTransactionRequest(
            wallet_id=request.wallet_id,
            amount=request.amount,
            txn_type="CREDIT",
            description=request.description or f"Top-up via {request.payment_method or 'cash'}"
        ),
        user_id
    )


@router.post("/transfer", response_model=TransferResponse)
async def transfer_between_wallets(request: TransferRequest, user_id: int = Depends(get_current_user_id)):
    """
    Transfer funds between wallets (with currency conversion if needed).
    """
    # Verify source wallet
    from_wallet = db.execute_query(
        "SELECT wallet_id, currency_id FROM DIGITAL_WALLETS WHERE wallet_id = :wallet_id AND user_id = :user_id",
        {"wallet_id": request.from_wallet_id, "user_id": user_id}
    )
    if not from_wallet:
        raise HTTPException(
            status_code=http_status.HTTP_404_NOT_FOUND,
            detail="Source wallet not found"
        )
    
    # Verify destination wallet
    to_wallet = db.execute_query(
        "SELECT wallet_id, currency_id FROM DIGITAL_WALLETS WHERE wallet_id = :wallet_id AND user_id = :user_id",
        {"wallet_id": request.to_wallet_id, "user_id": user_id}
    )
    if not to_wallet:
        raise HTTPException(
            status_code=http_status.HTTP_404_NOT_FOUND,
            detail="Destination wallet not found"
        )
    
    # Get currency codes
    from_currency_code = db.execute_query(
        "SELECT code FROM CURRENCIES WHERE currency_id = :currency_id",
        {"currency_id": from_wallet[0][1]}
    )[0][0]
    
    to_currency_code = db.execute_query(
        "SELECT code FROM CURRENCIES WHERE currency_id = :currency_id",
        {"currency_id": to_wallet[0][1]}
    )[0][0]
    
    # Convert amount to destination currency if different
    if from_currency_code == to_currency_code:
        converted_amount = request.amount
    else:
        converted_amount = convert_currency(request.amount, from_currency_code, to_currency_code)
    
    # Check sufficient balance in source wallet
    balance_result = db.execute_query(
        "SELECT balance FROM DIGITAL_WALLETS WHERE wallet_id = :wallet_id",
        {"wallet_id": request.from_wallet_id}
    )
    current_balance = float(balance_result[0][0]) if balance_result else 0
    
    if current_balance < request.amount:
        raise HTTPException(
            status_code=http_status.HTTP_400_BAD_REQUEST,
            detail=f"Insufficient balance. Available: {current_balance}"
        )
    
    # Perform transfer (debit from source, credit to destination)
    db.execute_update(
        "UPDATE DIGITAL_WALLETS SET balance = balance - :amount WHERE wallet_id = :wallet_id",
        {"amount": request.amount, "wallet_id": request.from_wallet_id}
    )
    
    db.execute_update(
        "UPDATE DIGITAL_WALLETS SET balance = balance + :amount WHERE wallet_id = :wallet_id",
        {"amount": converted_amount, "wallet_id": request.to_wallet_id}
    )
    
    # Record transactions
    description = request.description or f"Transfer to wallet {request.to_wallet_id}"
    
    from_transaction = await create_transaction(
        CreateTransactionRequest(
            wallet_id=request.from_wallet_id,
            amount=request.amount,
            txn_type="DEBIT",
            description=f"Transfer to wallet {request.to_wallet_id}"
        ),
        user_id
    )
    
    to_transaction = await create_transaction(
        CreateTransactionRequest(
            wallet_id=request.to_wallet_id,
            amount=converted_amount,
            txn_type="CREDIT",
            description=f"Transfer from wallet {request.from_wallet_id}"
        ),
        user_id
    )
    
    return TransferResponse(
        from_transaction_id=from_transaction.txn_id,
        to_transaction_id=to_transaction.txn_id,
        amount=request.amount,
        from_currency=from_currency_code,
        to_currency=to_currency_code,
        converted_amount=round(converted_amount, 2),
        message="Transfer completed successfully"
    )


@router.get("/spending/monthly", response_model=List[MonthlySpendingResponse])
async def get_monthly_spending(
    months: int = Query(6, ge=1, le=12),
    user_id: int = Depends(get_current_user_id)
):
    """
    Get monthly spending report for the last N months.
    """
    result = db.execute_query(
        """SELECT TO_CHAR(TRUNC(t.txn_date, 'MM'), 'YYYY-MM') as month,
                  NVL(SUM(CASE WHEN t.txn_type = 'DEBIT' THEN t.amount ELSE 0 END), 0) as total_spent,
                  NVL(SUM(CASE WHEN t.subscription_id IS NOT NULL AND t.txn_type = 'DEBIT' THEN t.amount ELSE 0 END), 0) as subscription_spent,
                  COUNT(CASE WHEN t.txn_type = 'DEBIT' THEN 1 END) as txn_count
           FROM TRANSACTIONS t
           WHERE t.user_id = :user_id
           AND t.txn_date >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -:months)
           GROUP BY TRUNC(t.txn_date, 'MM')
           ORDER BY month DESC""",
        {"user_id": user_id, "months": months}
    )
    
    monthly_spending = []
    for row in result:
        month, total_spent, subscription_spent, txn_count = row
        monthly_spending.append(MonthlySpendingResponse(
            month=month,
            total_spent=round(float(total_spent), 2),
            subscription_spent=round(float(subscription_spent), 2),
            other_spent=round(float(total_spent) - float(subscription_spent), 2),
            transaction_count=txn_count
        ))
    
    return monthly_spending