from fastapi import FastAPI

from .database import test_database_connection


# ==========================================
# CREATE FASTAPI APPLICATION
# ==========================================

app = FastAPI(
    title="Cognitive Care API",
    description="AI-powered cognitive assistance platform for elderly dementia patients",
    version="1.0.0"
)


# ==========================================
# STARTUP EVENT
# ==========================================

@app.on_event("startup")
def startup_event():

    test_database_connection()


# ==========================================
# HOME ROUTE
# ==========================================

@app.get("/")
def home():

    return {
        "message": "Cognitive Care API is running"
    }