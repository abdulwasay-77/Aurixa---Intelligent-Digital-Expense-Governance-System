"""
AURIXA Backend - AI Service Layer
scikit-learn based anomaly detection and pattern recognition
"""

import numpy as np
from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime, timedelta
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler
from config import config
from database import db


class AIService:
    """
    AI Service for anomaly detection and spending pattern analysis.
    Uses scikit-learn Isolation Forest for unsupervised anomaly detection.
    All models run locally - no external API calls.
    """

    def __init__(self):
        self.contamination = config.ANOMALY_CONTAMINATION
        self.random_state = config.ML_RANDOM_STATE
        self.model = None
        self.scaler = None

        # *** FIX 8 ***
        # contamination=0.05 tells Isolation Forest "assume exactly 5% of my
        # data is anomalous" — with ~40 transactions that forces it to flag
        # close to 2 of them every single run, whether or not anything is
        # actually unusual. That's why a routine $3.75 GitHub Pro charge
        # (well within its normal $3.43-$4.52 range) got flagged: the model
        # had a quota to fill.
        #
        # Two changes here:
        #  1. Raise the minimum sample size before we even attempt detection
        #     (was implicitly 10, which is far too small a sample for a
        #     5%-quota model to behave sensibly).
        #  2. In detect_anomalies(), cross-check every Isolation Forest flag
        #     against the statistical threshold already computed in
        #     get_spending_pattern() — only keep a flag if the transaction
        #     amount is ALSO statistically unusual, not just "whichever ~5%
        #     the forest had to pick from this batch."
        #
        # Also update ANOMALY_CONTAMINATION in backend/.env from 0.05 to
        # 0.02 — that's a config value, not something this file controls.
        self.min_transactions = 20

    def _get_transaction_features(self, user_id: int, limit: int = 200) -> np.ndarray:
        """
        Extract features from user transactions for anomaly detection.

        Features:
        - Transaction amount (normalized)
        - Day of month (1-31)
        - Hour of day (0-23)
        - Days since last transaction
        - Category ID

        Returns:
            numpy array of features
        """
        result = db.execute_query(
            """SELECT t.txn_id, t.amount,
                      EXTRACT(DAY FROM t.txn_date) as day_of_month,
                      EXTRACT(HOUR FROM t.txn_date) as hour_of_day,
                      t.category_id,
                      COALESCE(t.subscription_id, 0) as has_subscription
               FROM TRANSACTIONS t
               WHERE t.user_id = :user_id
               AND t.txn_date >= SYSDATE - 90
               ORDER BY t.txn_date DESC
               FETCH FIRST :limit ROWS ONLY""",
            {"user_id": user_id, "limit": limit}
        )

        # *** FIX 8 *** was "< 10" — raised to the same floor used everywhere
        # else in this service so a sparse history doesn't get force-fit.
        if not result or len(result) < self.min_transactions:
            return np.array([])

        features = []
        for row in result:
            txn_id, amount, day_of_month, hour_of_day, category_id, has_sub = row

            features.append([
                float(amount),
                float(day_of_month),
                float(hour_of_day),
                float(category_id) if category_id else 0,
                float(has_sub)
            ])

        return np.array(features)

    def _train_isolation_forest(self, features: np.ndarray) -> None:
        """
        Train Isolation Forest model on transaction features.
        """
        if len(features) < self.min_transactions:
            return

        # Normalize features
        self.scaler = StandardScaler()
        features_scaled = self.scaler.fit_transform(features)

        # Train Isolation Forest
        self.model = IsolationForest(
            contamination=self.contamination,
            random_state=self.random_state,
            n_estimators=100
        )
        self.model.fit(features_scaled)

    def detect_anomalies(self, user_id: int) -> List[int]:
        """
        Detect anomalous transactions for a user.

        *** FIX 8 ***
        Isolation Forest results are now cross-validated against the
        statistical threshold from get_spending_pattern() (mean + 2 std
        deviations of this user's own transaction amounts). A transaction
        only gets flagged if BOTH:
          1. The Isolation Forest considers it an outlier across all
             features (amount, timing, category, etc.), AND
          2. Its amount alone is statistically unusual for this user.

        This is what eliminates false positives like the $3.75 GitHub Pro
        charge — the forest may flag it on timing/category quirks, but its
        amount is nowhere near 2 standard deviations above this user's
        average, so the cross-check filters it back out.

        Args:
            user_id: User identifier

        Returns:
            List of transaction IDs flagged as anomalies
        """
        features = self._get_transaction_features(user_id)

        if len(features) < self.min_transactions:
            return []

        # Get transaction IDs in same order
        result = db.execute_query(
            """SELECT txn_id
               FROM TRANSACTIONS t
               WHERE t.user_id = :user_id
               AND t.txn_date >= SYSDATE - 90
               ORDER BY t.txn_date DESC
               FETCH FIRST 200 ROWS ONLY""",
            {"user_id": user_id}
        )

        txn_ids = [row[0] for row in result]

        # Train and predict
        self._train_isolation_forest(features)

        if self.model is None:
            return []

        features_scaled = self.scaler.transform(features)
        predictions = self.model.predict(features_scaled)

        # Isolation Forest returns -1 for anomalies, 1 for normal
        forest_anomalies = [txn_ids[i] for i, pred in enumerate(predictions) if pred == -1]

        if not forest_anomalies:
            return []

        # *** FIX 8 *** Cross-validate against the statistical threshold —
        # NOTE: the TRANSACTIONS table's amount column is "amount", not
        # "amount_usd" (amount_usd exists but is a separate converted-value
        # column not used elsewhere in this service).
        pattern = self.get_spending_pattern(user_id)
        threshold = pattern.get("anomaly_threshold", float('inf'))

        placeholders = ",".join([f":id{i}" for i in range(len(forest_anomalies))])
        params = {f"id{i}": tid for i, tid in enumerate(forest_anomalies)}
        rows = db.execute_query(
            f"SELECT txn_id, amount FROM TRANSACTIONS WHERE txn_id IN ({placeholders})",
            params
        )

        confirmed = [row[0] for row in rows if float(row[1]) >= threshold]
        return confirmed

    def flag_anomalies_in_database(self, user_id: int) -> int:
        """
        Detect and flag anomalies in database.

        Args:
            user_id: User identifier

        Returns:
            Number of anomalies flagged
        """
        anomalies = self.detect_anomalies(user_id)

        if anomalies:
            # Update is_anomaly flag in TRANSACTIONS table
            placeholders = ",".join([":id" + str(i) for i in range(len(anomalies))])
            params = {f"id{i}": txn_id for i, txn_id in enumerate(anomalies)}

            db.execute_update(
                f"UPDATE TRANSACTIONS SET is_anomaly = 'Y' WHERE txn_id IN ({placeholders})",
                params
            )

            # Create alerts for anomalies
            for txn_id in anomalies:
                # Check if alert already exists
                existing = db.execute_query(
                    "SELECT alert_id FROM RISK_ALERTS WHERE related_txn_id = :txn_id AND alert_type = 'ANOMALY'",
                    {"txn_id": txn_id}
                )

                if not existing:
                    db.execute_update(
                        """INSERT INTO RISK_ALERTS
                           (alert_id, user_id, alert_type, severity, title, message, related_txn_id, triggered_at)
                           VALUES (SEQ_RISK_ALERTS.NEXTVAL, :user_id, 'ANOMALY', 'MEDIUM',
                                   'Unusual Transaction Detected',
                                   'AI detected an unusual transaction pattern. Please review.',
                                   :txn_id, SYSDATE)""",
                        {"user_id": user_id, "txn_id": txn_id}
                    )

        return len(anomalies)

    def get_spending_pattern(self, user_id: int) -> Dict[str, Any]:
        """
        Analyze spending patterns for a user.

        Returns:
            Dictionary with spending pattern insights
        """
        # Get daily spending patterns
        result = db.execute_query(
            """SELECT TO_CHAR(t.txn_date, 'DY') as day_of_week,
                      COUNT(*) as transaction_count,
                      SUM(t.amount) as total_amount
               FROM TRANSACTIONS t
               WHERE t.user_id = :user_id
               AND t.txn_type = 'DEBIT'
               AND t.txn_date >= SYSDATE - 90
               GROUP BY TO_CHAR(t.txn_date, 'DY')
               ORDER BY total_amount DESC""",
            {"user_id": user_id}
        )

        day_patterns = {}
        for row in result:
            day, count, amount = row
            day_patterns[day] = {
                "transaction_count": count,
                "total_amount": float(amount)
            }

        # Get hourly patterns
        hour_result = db.execute_query(
            """SELECT EXTRACT(HOUR FROM t.txn_date) as hour,
                      COUNT(*) as transaction_count,
                      SUM(t.amount) as total_amount
               FROM TRANSACTIONS t
               WHERE t.user_id = :user_id
               AND t.txn_type = 'DEBIT'
               AND t.txn_date >= SYSDATE - 90
               GROUP BY EXTRACT(HOUR FROM t.txn_date)
               ORDER BY hour""",
            {"user_id": user_id}
        )

        hour_patterns = {}
        for row in hour_result:
            hour, count, amount = row
            hour_patterns[hour] = {
                "transaction_count": count,
                "total_amount": float(amount)
            }

        # Get average transaction amount
        avg_result = db.execute_query(
            """SELECT AVG(amount) as avg_amount,
                      STDDEV(amount) as stddev_amount,
                      MIN(amount) as min_amount,
                      MAX(amount) as max_amount
               FROM TRANSACTIONS t
               WHERE t.user_id = :user_id
               AND t.txn_type = 'DEBIT'
               AND t.txn_date >= SYSDATE - 90""",
            {"user_id": user_id}
        )

        avg_amount = float(avg_result[0][0]) if avg_result and avg_result[0][0] else 0
        stddev = float(avg_result[0][1]) if avg_result and avg_result[0][1] else 0
        min_amount = float(avg_result[0][2]) if avg_result and avg_result[0][2] else 0
        max_amount = float(avg_result[0][3]) if avg_result and avg_result[0][3] else 0

        return {
            "day_patterns": day_patterns,
            "hour_patterns": hour_patterns,
            "average_transaction": round(avg_amount, 2),
            "stddev_transaction": round(stddev, 2),
            "min_transaction": round(min_amount, 2),
            "max_transaction": round(max_amount, 2),
            "anomaly_threshold": round(avg_amount + 2 * stddev, 2)
        }


# Singleton instance
ai_service = AIService()