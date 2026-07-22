"""
AURIXA Backend - Summary Service Layer
Rule-based natural language insights generation
No external API calls - all templates are local
"""

from typing import Dict, Any, Optional, List
from datetime import datetime, date


class SummaryService:
    """
    Service for generating human-readable financial insights.
    Uses rule-based templates - no LLM or external API calls.
    """
    
    @staticmethod
    def generate_financial_insight(score_data: Dict[str, Any], forecast_data: Dict[str, Any]) -> str:
        """
        Generate a financial health insight string.
        
        Args:
            score_data: Financial score data (health_score, score_label, etc.)
            forecast_data: Budget forecast data (variance_pct, days_to_breach, etc.)
        
        Returns:
            Human-readable insight string
        """
        score = score_data.get('financial_health_score', 0)
        label = score_data.get('score_label', 'UNKNOWN')
        days = forecast_data.get('days_to_breach')
        var_pct = forecast_data.get('variance_pct', 0)
        
        # Critical: Budget breach imminent
        if days is not None and days < 5 and days > 0:
            return (
                f"⚠️ CRITICAL: Budget breach in {days} days! "
                f"Your current spending velocity will exceed your monthly budget. "
                f"Financial Health Score: {score}/100 ({label}). "
                f"Consider pausing non-essential subscriptions immediately."
            )
        
        # Budget at risk
        if days is not None and days <= 10:
            return (
                f"⚠️ Budget at risk: {days} days until potential breach. "
                f"Your current spend rate of ${forecast_data.get('velocity_per_day', 0):.2f}/day "
                f"exceeds your daily allowance. Financial Health Score: {score}/100."
            )
        
        # Overspending trend
        if var_pct > 15:
            return (
                f"📈 Spending Alert: On track to exceed budget by {var_pct:.1f}% this month. "
                f"Review your {forecast_data.get('top_category', 'subscription')} spending. "
                f"Health Score: {score}/100 ({label})."
            )
        
        # Excellent financial health
        if score >= 80:
            savings = forecast_data.get('projected_savings', 0)
            return (
                f"🌟 Excellent financial discipline! Health Score {score}/100 ({label}). "
                f"You are {abs(var_pct):.1f}% under budget this month. "
                f"Keep up the great work!"
            )
        
        # Good financial health
        if score >= 60:
            return (
                f"✅ Good financial health: {score}/100 ({label}). "
                f"Your spending is {var_pct:+.1f}% vs budget. "
                f"Continue monitoring your subscriptions."
            )
        
        # Fair financial health
        if score >= 40:
            return (
                f"📊 Fair financial health: {score}/100 ({label}). "
                f"Consider reviewing idle subscriptions to improve your score. "
                f"You are {abs(var_pct):.1f}% {'over' if var_pct > 0 else 'under'} budget."
            )
        
        # Poor financial health
        if score >= 20:
            return (
                f"⚠️ Financial health needs attention: {score}/100 ({label}). "
                f"Review your AI recommendations for actionable savings. "
                f"Potential savings available through subscription optimization."
            )
        
        # Critical financial health
        return (
            f"🚨 Financial health is critical: {score}/100 ({label}). "
            f"Immediate action recommended. Check your budget and subscriptions. "
            f"Consider cancelling low-usage subscriptions to reduce monthly spend."
        )
    
    @staticmethod
    def generate_subscription_insight(subscription: Dict[str, Any]) -> str:
        """
        Generate insight for a single subscription.
        
        Args:
            subscription: Subscription data (name, amount, usage_score, etc.)
        
        Returns:
            Human-readable insight string
        """
        name = subscription.get('service_name', 'Unknown')
        amount = subscription.get('billing_amount', 0)
        usage = subscription.get('usage_score', 5)
        
        if usage <= 2:
            return f"💡 {name} (${amount:.2f}/month) has very low usage (score {usage}/10). Consider cancelling to save ${amount:.2f} monthly."
        elif usage <= 4:
            return f"📌 {name} (${amount:.2f}/month) has moderate-low usage (score {usage}/10). Review if still needed."
        elif usage <= 6:
            return f"ℹ️ {name} (${amount:.2f}/month) has moderate usage (score {usage}/10). Keep monitoring."
        elif usage <= 8:
            return f"✅ {name} (${amount:.2f}/month) has good usage (score {usage}/10). Good value for money."
        else:
            return f"🌟 {name} (${amount:.2f}/month) is highly used (score {usage}/10). Excellent value!"
    
    @staticmethod
    def generate_budget_insight(budget_limit: float, spent: float, remaining_days: int) -> str:
        """
        Generate budget insight string.
        
        Args:
            budget_limit: Monthly budget limit
            spent: Amount spent so far
            remaining_days: Days remaining in month
        
        Returns:
            Human-readable budget insight
        """
        remaining_budget = budget_limit - spent
        daily_allowance = remaining_budget / max(remaining_days, 1)
        
        if spent > budget_limit:
            return f"🚨 Budget breached by ${spent - budget_limit:.2f}. Review subscriptions immediately."
        elif remaining_days <= 5 and remaining_budget < 100:
            return f"⚠️ Low budget remaining: ${remaining_budget:.2f} for {remaining_days} days. Daily allowance: ${daily_allowance:.2f}"
        elif remaining_budget < 200:
            return f"📌 Budget remaining: ${remaining_budget:.2f} for {remaining_days} days. Spend wisely: ${daily_allowance:.2f}/day"
        else:
            return f"✅ On track! ${remaining_budget:.2f} remaining for {remaining_days} days. Daily allowance: ${daily_allowance:.2f}"
    
    @staticmethod
    def generate_savings_insight(potential_savings: float, recommendations_count: int) -> str:
        """
        Generate savings insight string.
        
        Args:
            potential_savings: Total potential monthly savings
            recommendations_count: Number of pending recommendations
        
        Returns:
            Human-readable savings insight
        """
        if potential_savings > 100:
            yearly = potential_savings * 12
            return f"💰 You could save ${potential_savings:.2f}/month (${yearly:.2f}/year) by applying {recommendations_count} recommendations!"
        elif potential_savings > 50:
            return f"💡 ${potential_savings:.2f} in potential monthly savings available. Review {recommendations_count} recommendations."
        elif potential_savings > 0:
            return f"📌 ${potential_savings:.2f} potential monthly savings identified. Small changes add up!"
        else:
            return f"✅ No savings opportunities identified. Your subscriptions are well optimized!"
    
    @staticmethod
    def generate_anomaly_insight(anomaly_count: int, largest_anomaly: Optional[float] = None) -> str:
        """
        Generate anomaly detection insight.
        
        Args:
            anomaly_count: Number of anomalies detected
            largest_anomaly: Largest anomaly amount (if any)
        
        Returns:
            Human-readable anomaly insight
        """
        if anomaly_count == 0:
            return "✅ No unusual transactions detected. Your spending patterns appear normal."
        elif anomaly_count == 1 and largest_anomaly:
            return f"⚠️ 1 unusual transaction detected (${largest_anomaly:.2f}). Please review for accuracy."
        else:
            return f"⚠️ {anomaly_count} unusual transactions detected. Review your recent transaction history."


# Singleton instance
summary_service = SummaryService()