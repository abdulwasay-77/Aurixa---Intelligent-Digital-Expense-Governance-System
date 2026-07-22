# AURIXA – Intelligent Digital Expense Governance System

AURIXA is an AI-powered digital expense governance and financial behavior analytics platform developed as a semester project for the **Advanced Database Management Systems (ADBMS)** course. The system helps users manage digital subscriptions, monitor spending, track billing cycles across multiple currencies, and receive AI-driven financial recommendations through a modern web application backed by Oracle Database 21c. :contentReference[oaicite:0]{index=0}

---

## Team Members

- **Abdul Wasay** (UW-24-CS-BS-112)
- **Muhammad Fahad** (UW-24-CS-BS-092)
- **Mahnoor Saleem** (UW-24-CS-BS-074) :contentReference[oaicite:1]{index=1}

---

## Key Features

- Secure JWT Authentication
- Subscription Management
- Digital Wallet Management
- AI-Based Anomaly Detection (Isolation Forest)
- AI Financial Recommendations
- Risk Alerts Dashboard
- Financial Analytics & Reports
- Spending Trend Analysis
- Multi-Currency Support
- Budget Forecasting
- Financial Health Score
- Automated Billing Reminders
- Audit Trail Logging
- Oracle Scheduler Jobs
- Materialized Views for Analytics :contentReference[oaicite:2]{index=2}

---

## Technology Stack

### Backend
- Python 3.11
- FastAPI
- Oracle Database 21c XE
- python-oracledb
- Pydantic v2
- PyJWT
- bcrypt
- scikit-learn
- Uvicorn

### Frontend
- Flutter
- Dart

### Database
- Oracle SQL Developer
- PL/SQL
- Triggers
- Sequences
- Materialized Views
- Scheduler Jobs
- Stored Packages
- Standalone Functions :contentReference[oaicite:3]{index=3}

---

## System Architecture

```
Flutter Frontend
        │
        ▼
 FastAPI REST API
        │
        ▼
 Oracle Database 21c XE
        │
        ▼
 AI Analytics Engine
```

The application follows a three-tier architecture consisting of:

- Flutter Client
- Python FastAPI Backend
- Oracle Database 21c XE :contentReference[oaicite:4]{index=4}

---

## Database Highlights

- 29 Normalized Tables
- 26 Oracle Sequences
- 55 Performance Indexes
- 5 Database Triggers
- 3 Materialized Views
- PL/SQL Packages
- Standalone Functions
- Oracle Scheduler Jobs
- Complete Audit Trail System :contentReference[oaicite:5]{index=5}

---

## AI Module

AURIXA integrates an **Isolation Forest** machine learning model using **scikit-learn** to detect unusual financial transactions automatically.

The AI engine analyzes:

- Transaction Amount
- Spending Patterns
- Subscription Categories
- Historical User Behavior

Suspicious transactions generate risk alerts and personalized recommendations for users. :contentReference[oaicite:6]{index=6}

---

## Project Structure

```
Aurixa/
│
├── backend/
│   ├── models/
│   ├── routers/
│   ├── services/
│   ├── utils/
│   └── main.py
│
├── frontend/
│   ├── lib/
│   ├── assets/
│   └── pubspec.yaml
│
├── database/
│   └── scripts/
│
└── README.md
```

---

## API Modules

- Authentication
- Users
- Subscriptions
- Analytics
- Alerts
- Recommendations
- Wallet
- Audit Logs :contentReference[oaicite:7]{index=7}

---

## Security Features

- JWT Authentication
- Refresh Tokens
- bcrypt Password Hashing
- Account Lockout Protection
- Secure Oracle Database Access
- Audit Logging :contentReference[oaicite:8]{index=8}

---

## Screens

- Login
- Registration
- Dashboard
- Subscription Management
- Analytics
- AI Recommendations
- Risk Alerts
- Wallet
- Score History
- User Profile :contentReference[oaicite:9]{index=9}

---

## Setup

### Clone Repository

```bash
git clone https://github.com/abdulwasay-77/Aurixa---Intelligent-Digital-Expense-Governance-System.git
```

### Backend

```bash
cd backend

python -m venv venv

venv\Scripts\activate

pip install -r requirements.txt

uvicorn main:app --reload
```

### Frontend

```bash
cd frontend

flutter pub get

flutter run
```

---

## Note

Sensitive configuration files (such as `.env`) and the Oracle user creation script (`01_create_user.sql`) are intentionally excluded from this repository for security reasons.

---

## Course

**Advanced Database Management Systems (ADBMS)**

Semester Project

University of Wah

---

## License

This repository is intended for educational and academic purposes.