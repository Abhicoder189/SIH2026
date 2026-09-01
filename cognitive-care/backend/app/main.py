from fastapi import FastAPI, HTTPException
from pydantic import BaseModel


# ==========================================
# CREATE FASTAPI APPLICATION
# ==========================================

app = FastAPI(
    title="Cognitive Care API",
    description="AI-powered cognitive assistance platform for elderly dementia patients",
    version="1.0.0"
)


# ==========================================
# PATIENT MODEL
# ==========================================

class Patient(BaseModel):
    id: int
    name: str
    age: int
    language: str


# ==========================================
# TEMPORARY PATIENT DATA
# ==========================================

patients = [
    Patient(
        id=1,
        name="Anita Devi",
        age=72,
        language="Assamese"
    ),
    Patient(
        id=2,
        name="Ramesh Das",
        age=68,
        language="Bengali"
    )
]


# ==========================================
# HOME
# ==========================================

@app.get("/")
def home():

    return {
        "message": "Cognitive Care API is running"
    }


# ==========================================
# GET ALL PATIENTS
# ==========================================

@app.get("/patients")
def get_patients():

    return patients


# ==========================================
# GET SINGLE PATIENT
# ==========================================

@app.get("/patients/{patient_id}")
def get_patient(patient_id: int):

    for patient in patients:

        if patient.id == patient_id:
            return patient

    raise HTTPException(
        status_code=404,
        detail="Patient not found"
    )


# ==========================================
# CREATE PATIENT
# ==========================================

@app.post("/patients")
def create_patient(patient: Patient):

    # Check if patient ID already exists

    for existing_patient in patients:

        if existing_patient.id == patient.id:

            raise HTTPException(
                status_code=400,
                detail="Patient ID already exists"
            )

    patients.append(patient)

    return {
        "message": "Patient created successfully",
        "patient": patient
    }