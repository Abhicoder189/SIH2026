from bson import ObjectId

from fastapi import Depends, HTTPException

from app.auth import get_current_user
from app.database import caregiver_links_collection, patients_collection


def get_my_patient(
    current_user=Depends(get_current_user)
):
    """
    Get the patient profile belonging to
    the currently authenticated elderly user.
    """

    user_id = current_user["user_id"]

    patient = patients_collection.find_one(
        {
            "user_id": user_id
        }
    )

    if not patient:
        raise HTTPException(
            status_code=404,
            detail="Patient profile not found"
        )

    return patient


def get_my_patient_id(
    current_user=Depends(get_current_user)
):
    """
    Return the MongoDB patient ID for
    the currently authenticated elderly user.
    """

    patient = get_my_patient(
        current_user
    )

    return str(patient["_id"])


def verify_patient_access(
    patient_id: str,
    current_user=Depends(get_current_user)
):
    """
    Verify that the authenticated user is
    allowed to access the requested patient.
    """

    if not ObjectId.is_valid(patient_id):
        raise HTTPException(
            status_code=400,
            detail="Invalid patient ID"
        )

    patient = patients_collection.find_one(
        {
            "_id": ObjectId(patient_id)
        }
    )

    if not patient:
        raise HTTPException(
            status_code=404,
            detail="Patient not found"
        )

    user_id = current_user["user_id"]
    role = current_user["role"]

    # Elderly user can access their own profile
    if role == "elderly":

        if patient.get("user_id") != user_id:
            raise HTTPException(
                status_code=403,
                detail="You cannot access this patient"
            )

        return patient

    if role == "caregiver":
        link = caregiver_links_collection.find_one({
            "caregiver_id": user_id,
            "patient_id": patient_id,
            "status": "active",
        })
        if link:
            return patient
        raise HTTPException(status_code=403, detail="You are not linked to this patient")

    if role == "health_worker":
        raise HTTPException(status_code=403, detail="Health-worker patient access is not configured")

    raise HTTPException(
        status_code=403,
        detail="Insufficient permissions"
    )
