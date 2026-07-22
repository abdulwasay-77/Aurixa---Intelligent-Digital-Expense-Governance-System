"""
AURIXA Backend - Oracle Service Layer
Helper functions for calling stored procedures and functions
"""

from typing import Any, List, Dict, Optional, Tuple
from database import db


class OracleService:
    """
    Service class for Oracle stored procedure and function calls.
    Provides clean interfaces to AURIXA_ANALYTICS package.
    """

    # ========================================================================
    # Financial Health Procedures
    # ========================================================================

    @staticmethod
    def calculate_financial_health(user_id: int) -> bool:
        """
        Calculate financial health score for a user.
        Calls: AURIXA_ANALYTICS.CALCULATE_FINANCIAL_HEALTH

        Args:
            user_id: User identifier

        Returns:
            True if successful, False otherwise
        """
        try:
            db.call_procedure(
                "AURIXA_ANALYTICS.CALCULATE_FINANCIAL_HEALTH",
                [user_id]
            )
            return True
        except Exception as e:
            print(f"Error calculating financial health for user {user_id}: {e}")
            return False

    @staticmethod
    def predict_monthly_expenses(user_id: int) -> bool:
        """
        Predict monthly expenses for a user.
        Calls: AURIXA_ANALYTICS.PREDICT_MONTHLY_EXPENSES

        Args:
            user_id: User identifier

        Returns:
            True if successful, False otherwise
        """
        try:
            db.call_procedure(
                "AURIXA_ANALYTICS.PREDICT_MONTHLY_EXPENSES",
                [user_id]
            )
            return True
        except Exception as e:
            print(f"Error predicting expenses for user {user_id}: {e}")
            return False

    @staticmethod
    def generate_smart_recommendations(user_id: int) -> bool:
        """
        Generate smart recommendations for a user.
        Calls: AURIXA_ANALYTICS.GENERATE_SMART_RECOMMENDATIONS

        Args:
            user_id: User identifier

        Returns:
            True if successful, False otherwise
        """
        try:
            db.call_procedure(
                "AURIXA_ANALYTICS.GENERATE_SMART_RECOMMENDATIONS",
                [user_id]
            )
            return True
        except Exception as e:
            print(f"Error generating recommendations for user {user_id}: {e}")
            return False

    @staticmethod
    def generate_billing_schedule(sub_id: int, months: int = 12) -> bool:
        """
        Generate billing schedule for a subscription.
        Calls: AURIXA_ANALYTICS.GENERATE_BILLING_SCHEDULE

        *** FIX 2 ***
        This used to wrap db.call_procedure in a try/except that printed the
        error and returned False. That meant a real Oracle failure (e.g. the
        ORA-04091 mutating-table error from the old TRG_AFTER_PAYMENT) was
        invisible to every caller — create_subscription() in
        routers/subscriptions.py never checked the return value anyway, so
        the subscription got created with HTTP 200 and silently zero billing
        history.

        Now this re-raises. The caller (create_subscription) is responsible
        for deciding what to do about a failure — see the updated
        routers/subscriptions.py, which now rolls back the subscription row
        if this raises.

        Returns:
            True if successful. Raises the underlying exception on failure
            instead of swallowing it.
        """
        db.call_procedure(
            "AURIXA_ANALYTICS.GENERATE_BILLING_SCHEDULE",
            [sub_id, months]
        )
        return True

    @staticmethod
    def generate_annual_forecast(user_id: int) -> bool:
        """
        Generate annual forecast for a user.
        Calls: AURIXA_ANALYTICS.GENERATE_ANNUAL_FORECAST

        Args:
            user_id: User identifier

        Returns:
            True if successful, False otherwise
        """
        try:
            db.call_procedure(
                "AURIXA_ANALYTICS.GENERATE_ANNUAL_FORECAST",
                [user_id]
            )
            return True
        except Exception as e:
            print(f"Error generating annual forecast for user {user_id}: {e}")
            return False

    @staticmethod
    def process_idle_subscriptions(user_id: int) -> bool:
        """
        Process idle subscriptions for a user.
        Calls: AURIXA_ANALYTICS.PROCESS_IDLE_SUBSCRIPTIONS

        Args:
            user_id: User identifier

        Returns:
            True if successful, False otherwise
        """
        try:
            db.call_procedure(
                "AURIXA_ANALYTICS.PROCESS_IDLE_SUBSCRIPTIONS",
                [user_id]
            )
            return True
        except Exception as e:
            print(f"Error processing idle subscriptions for user {user_id}: {e}")
            return False

    # ========================================================================
    # Function Calls
    # ========================================================================

    @staticmethod
    def get_monthly_spend(user_id: int, month_date: str) -> float:
        """
        Get monthly spend for a user.
        Calls: AURIXA_ANALYTICS.GET_MONTHLY_SPEND

        Args:
            user_id: User identifier
            month_date: Month to calculate (e.g., '2024-01-01')

        Returns:
            Total monthly spend
        """
        try:
            result = db.call_function(
                "AURIXA_ANALYTICS.GET_MONTHLY_SPEND",
                float,
                [user_id, month_date]
            )
            return float(result) if result else 0.0
        except Exception as e:
            print(f"Error getting monthly spend for user {user_id}: {e}")
            return 0.0

    @staticmethod
    def is_budget_breached(user_id: int) -> bool:
        """
        Check if budget is breached.
        Calls: AURIXA_ANALYTICS.IS_BUDGET_BREACHED

        Args:
            user_id: User identifier

        Returns:
            True if budget breached, False otherwise
        """
        try:
            result = db.call_function(
                "AURIXA_ANALYTICS.IS_BUDGET_BREACHED",
                int,
                [user_id]
            )
            return result == 1
        except Exception as e:
            print(f"Error checking budget breach for user {user_id}: {e}")
            return False

    @staticmethod
    def convert_currency(amount: float, from_code: str, to_code: str) -> float:
        """
        Convert currency using CONVERT_CURRENCY function.

        Args:
            amount: Amount to convert
            from_code: Source currency code
            to_code: Target currency code

        Returns:
            Converted amount
        """
        try:
            result = db.execute_query(
                "SELECT CONVERT_CURRENCY(:amount, :from_code, :to_code) FROM DUAL",
                {"amount": amount, "from_code": from_code, "to_code": to_code}
            )
            return float(result[0][0]) if result else amount
        except Exception as e:
            print(f"Error converting currency: {e}")
            return amount


# Singleton instance
oracle_service = OracleService()