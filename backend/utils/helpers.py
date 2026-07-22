"""
AURIXA Backend - Helper Utilities
Common helper functions used across the application
"""

from typing import Dict, Any, Optional, List
from datetime import datetime, date, timedelta
import json
import uuid


class Helpers:
    """Collection of helper functions"""
    
    @staticmethod
    def generate_uuid() -> str:
        """Generate a unique UUID string."""
        return str(uuid.uuid4())
    
    @staticmethod
    def get_current_timestamp() -> datetime:
        """Get current timestamp."""
        return datetime.now()
    
    @staticmethod
    def format_currency(amount: float, symbol: str = "$") -> str:
        """
        Format amount as currency string.
        
        Args:
            amount: Amount to format
            symbol: Currency symbol
        
        Returns:
            Formatted currency string
        """
        return f"{symbol}{amount:,.2f}"
    
    @staticmethod
    def calculate_percentage(part: float, whole: float) -> float:
        """
        Calculate percentage.
        
        Args:
            part: Part value
            whole: Whole value
        
        Returns:
            Percentage (0-100)
        """
        if whole == 0:
            return 0.0
        return round((part / whole) * 100, 2)
    
    @staticmethod
    def calculate_days_between(start_date: date, end_date: date) -> int:
        """
        Calculate days between two dates.
        
        Args:
            start_date: Start date
            end_date: End date
        
        Returns:
            Number of days between
        """
        return (end_date - start_date).days
    
    @staticmethod
    def get_month_days(year: int, month: int) -> int:
        """
        Get number of days in a month.
        
        Args:
            year: Year
            month: Month (1-12)
        
        Returns:
            Number of days in month
        """
        if month == 2:
            # Check for leap year
            if (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0):
                return 29
            return 28
        if month in [4, 6, 9, 11]:
            return 30
        return 31
    
    @staticmethod
    def get_first_day_of_month(date_input: date) -> date:
        """Get first day of the month for a given date."""
        return date_input.replace(day=1)
    
    @staticmethod
    def get_last_day_of_month(date_input: date) -> date:
        """Get last day of the month for a given date."""
        year = date_input.year
        month = date_input.month
        days = Helpers.get_month_days(year, month)
        return date_input.replace(day=days)
    
    @staticmethod
    def safe_json_parse(json_string: str, default: Any = None) -> Any:
        """
        Safely parse JSON string.
        
        Args:
            json_string: JSON string to parse
            default: Default value if parsing fails
        
        Returns:
            Parsed JSON or default
        """
        try:
            return json.loads(json_string)
        except (json.JSONDecodeError, TypeError):
            return default
    
    @staticmethod
    def safe_json_dumps(data: Any, default: Any = None) -> str:
        """
        Safely convert to JSON string.
        
        Args:
            data: Data to convert
            default: Default value if conversion fails
        
        Returns:
            JSON string or default
        """
        try:
            return json.dumps(data, default=str)
        except (TypeError, ValueError):
            return default if default else "{}"
    
    @staticmethod
    def mask_email(email: str) -> str:
        """
        Mask email address for privacy.
        
        Args:
            email: Email address to mask
        
        Returns:
            Masked email (e.g., u***r@example.com)
        """
        if not email or "@" not in email:
            return email
        
        local, domain = email.split("@", 1)
        if len(local) <= 2:
            masked_local = local[0] + "***"
        else:
            masked_local = local[0] + "***" + local[-1]
        
        return f"{masked_local}@{domain}"
    
    @staticmethod
    def truncate_string(text: str, max_length: int = 100) -> str:
        """
        Truncate string to maximum length.
        
        Args:
            text: String to truncate
            max_length: Maximum length
        
        Returns:
            Truncated string with ellipsis if needed
        """
        if not text or len(text) <= max_length:
            return text
        return text[:max_length - 3] + "..."
    
    @staticmethod
    def group_by_key(items: List[Dict], key: str) -> Dict[Any, List[Dict]]:
        """
        Group list of dictionaries by a key.
        
        Args:
            items: List of dictionaries
            key: Key to group by
        
        Returns:
            Dictionary with grouped items
        """
        grouped = {}
        for item in items:
            group_key = item.get(key)
            if group_key not in grouped:
                grouped[group_key] = []
            grouped[group_key].append(item)
        return grouped
    
    @staticmethod
    def calculate_spend_velocity(total_spent: float, days_passed: int) -> float:
        """
        Calculate spend velocity (average daily spend).
        
        Args:
            total_spent: Total amount spent
            days_passed: Number of days passed
        
        Returns:
            Spend velocity per day
        """
        if days_passed <= 0:
            return 0.0
        return round(total_spent / days_passed, 2)
    
    @staticmethod
    def calculate_days_to_breach(budget: float, spent: float, velocity: float) -> Optional[int]:
        """
        Calculate days until budget breach.
        
        Args:
            budget: Monthly budget limit
            spent: Amount spent so far
            velocity: Daily spend velocity
        
        Returns:
            Days to breach or None if not on track to breach
        """
        if velocity <= 0 or spent >= budget:
            return None
        remaining_budget = budget - spent
        days = int(remaining_budget / velocity)
        return days if days > 0 else None
    
    @staticmethod
    def get_category_color(category_name: str) -> str:
        """
        Get default color for a spending category.
        
        Args:
            category_name: Category name
        
        Returns:
            Hex color code        """
        colors = {
            "Streaming": "#E50914",
            "Music": "#1DB954",
            "SaaS Tools": "#0078D4",
            "Gaming": "#7B2FBE",
            "Cloud Storage": "#F4900C",
            "Security VPN": "#22C55E",
            "Utilities": "#EAB308",
            "News Reading": "#6B7280",
            "AI Tools": "#8B5CF6",
            "Fitness Health": "#EF4444"
        }
        return colors.get(category_name, "#4A9EFF")
    
    @staticmethod
    def get_category_icon(category_name: str) -> str:
        """
        Get default icon for a spending category.
        
        Args:
            category_name: Category name
        
        Returns:
            Icon name
        """
        icons = {
            "Streaming": "play_circle",
            "Music": "music_note",
            "SaaS Tools": "build",
            "Gaming": "sports_esports",
            "Cloud Storage": "cloud",
            "Security VPN": "shield",
            "Utilities": "bolt",
            "News Reading": "menu_book",
            "AI Tools": "auto_awesome",
            "Fitness Health": "fitness_center"
        }
        return icons.get(category_name, "receipt")


# Singleton instance
helpers = Helpers()