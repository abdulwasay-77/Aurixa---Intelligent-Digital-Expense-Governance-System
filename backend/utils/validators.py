"""
AURIXA Backend - Validation Utilities
Additional validation functions for data integrity
"""

import re
from typing import Optional, Tuple
from datetime import datetime, date


class Validators:
    """Collection of validation functions"""
    
    @staticmethod
    def validate_email(email: str) -> bool:
        """
        Validate email format.
        
        Args:
            email: Email address to validate
        
        Returns:
            True if valid, False otherwise
        """
        pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        return bool(re.match(pattern, email))
    
    @staticmethod
    def validate_password_strength(password: str) -> Tuple[bool, str]:
        """
        Validate password strength.
        
        Returns:
            Tuple of (is_valid, message)
        """
        if len(password) < 8:
            return False, "Password must be at least 8 characters"
        
        if not any(c.isupper() for c in password):
            return False, "Password must contain at least one uppercase letter"
        
        if not any(c.islower() for c in password):
            return False, "Password must contain at least one lowercase letter"
        
        if not any(c.isdigit() for c in password):
            return False, "Password must contain at least one number"
        
        if not any(c in "!@#$%^&*()_+-=[]{}|;:,.<>?/`~" for c in password):
            return False, "Password must contain at least one special character"
        
        return True, "Password is strong"
    
    @staticmethod
    def validate_phone(phone: str) -> bool:
        """
        Validate phone number format.
        
        Args:
            phone: Phone number to validate
        
        Returns:
            True if valid, False otherwise
        """
        # Remove common separators
        cleaned = re.sub(r'[\s\-\(\)\+]', '', phone)
        return cleaned.isdigit() and len(cleaned) >= 10
    
    @staticmethod
    def validate_amount(amount: float) -> bool:
        """
        Validate amount value.
        
        Args:
            amount: Amount to validate
        
        Returns:
            True if valid, False otherwise
        """
        return amount > 0 and amount < 999999.99
    
    @staticmethod
    def validate_date_range(start_date: date, end_date: date) -> bool:
        """
        Validate date range (start <= end).
        
        Args:
            start_date: Start date
            end_date: End date
        
        Returns:
            True if valid, False otherwise
        """
        return start_date <= end_date
    
    @staticmethod
    def validate_future_date(check_date: date) -> bool:
        """
        Validate if date is in the future.
        
        Args:
            check_date: Date to check
        
        Returns:
            True if future, False otherwise
        """
        return check_date > date.today()
    
    @staticmethod
    def sanitize_string(input_str: str, max_length: int = 500) -> str:
        """
        Sanitize string input.
        
        Args:
            input_str: String to sanitize
            max_length: Maximum allowed length
        
        Returns:
            Sanitized string
        """
        if not input_str:
            return ""
        
        # Trim whitespace
        sanitized = input_str.strip()
        
        # Limit length
        if len(sanitized) > max_length:
            sanitized = sanitized[:max_length]
        
        return sanitized
    
    @staticmethod
    def validate_currency_code(code: str) -> bool:
        """
        Validate currency code (ISO 4217).
        
        Args:
            code: Currency code to validate
        
        Returns:
            True if valid, False otherwise
        """
        valid_codes = ["PKR", "USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY", "INR"]
        return code.upper() in valid_codes
    
    @staticmethod
    def validate_billing_cycle(cycle: str) -> bool:
        """
        Validate billing cycle value.
        
        Args:
            cycle: Billing cycle to validate
        
        Returns:
            True if valid, False otherwise
        """
        valid_cycles = ["MONTHLY", "YEARLY", "WEEKLY", "QUARTERLY"]
        return cycle.upper() in valid_cycles
    
    @staticmethod
    def validate_risk_tolerance(risk: str) -> bool:
        """
        Validate risk tolerance value.
        
        Args:
            risk: Risk tolerance to validate
        
        Returns:
            True if valid, False otherwise
        """
        valid_risks = ["LOW", "MEDIUM", "HIGH"]
        return risk.upper() in valid_risks
    
    @staticmethod
    def validate_usage_score(score: int) -> bool:
        """
        Validate usage score (1-10).
        
        Args:
            score: Usage score to validate
        
        Returns:
            True if valid, False otherwise
        """
        return 1 <= score <= 10


# Singleton instance
validators = Validators()