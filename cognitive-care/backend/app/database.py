import os

from dotenv import load_dotenv
from pymongo import MongoClient
from pymongo.server_api import ServerApi


# ==========================================
# LOAD ENVIRONMENT VARIABLES
# ==========================================

load_dotenv()


# ==========================================
# GET MONGODB CONFIGURATION
# ==========================================

MONGODB_URI = os.getenv("MONGODB_URI")
DATABASE_NAME = os.getenv("DATABASE_NAME")


# ==========================================
# CHECK CONFIGURATION
# ==========================================

if not MONGODB_URI:
    raise ValueError("MONGODB_URI is not set in .env")

if not DATABASE_NAME:
    raise ValueError("DATABASE_NAME is not set in .env")


# ==========================================
# CREATE MONGODB CLIENT
# ==========================================

client = MongoClient(
    MONGODB_URI,
    server_api=ServerApi("1")
)


# ==========================================
# SELECT DATABASE
# ==========================================

database = client[DATABASE_NAME]


# ==========================================
# PATIENT COLLECTION
# ==========================================

patients_collection = database["patients"]


# ==========================================
# TEST CONNECTION
# ==========================================

def test_database_connection():

    try:

        client.admin.command("ping")

        print("MongoDB connection successful!")

    except Exception as error:

        print("MongoDB connection failed!")

        print(error)