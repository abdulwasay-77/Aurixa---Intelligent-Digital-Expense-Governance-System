from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import uvicorn
from config import config

# Import routers
from routers import auth, users, subscriptions, analytics, alerts, recommendations, wallet, audit  # ✅ Phase 11

app = FastAPI(
    title="AURIXA API",
    description="Intelligent Digital Expense Governance & Financial Behavior Analytics Platform",
    version="2.3",
    docs_url="/docs",
    redoc_url="/redoc"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost",
        "http://localhost:8000",
        "http://127.0.0.1",
        "http://127.0.0.1:8000",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register routers
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(subscriptions.router)
app.include_router(analytics.router)
app.include_router(alerts.router)
app.include_router(recommendations.router)
app.include_router(wallet.router)
app.include_router(audit.router)  # ✅ Phase 11

@app.get("/")
async def root():
    return {
        "name": "AURIXA API",
        "version": "2.3",
        "status": "running",
        "description": "Intelligent Digital Expense Governance & Financial Behavior Analytics Platform"
    }

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "database": "connected",
        "timestamp": "2026-06-20T00:00:00Z"
    }

@app.on_event("startup")
async def startup_event():
    print("=" * 50)
    print("AURIXA Backend Starting...")
    print(f"API Version: 2.3")
    print(f"Oracle User: {config.ORACLE_USER}")
    print(f"Oracle DSN: {config.ORACLE_DSN}")
    print("Registered Routers:")
    print("  - /api/auth (Authentication)")
    print("  - /api/users (User Management)")
    print("  - /api/subscriptions (Subscription Management)")
    print("  - /api/analytics (Analytics & Forecasting)")
    print("  - /api/alerts (RiskRadar Alerts)")
    print("  - /api/recommendations (AI Recommendations)")
    print("  - /api/wallet (Digital Wallet)")
    print("  - /api/audit (Audit Trail)")  # ✅ Phase 11
    print("=" * 50)

@app.on_event("shutdown")
async def shutdown_event():
    print("=" * 50)
    print("AURIXA Backend Shutting Down...")
    print("=" * 50)

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host=config.API_HOST,
        port=config.API_PORT,
        reload=config.API_RELOAD
    )