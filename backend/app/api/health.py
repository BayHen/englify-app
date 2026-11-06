"""Liveness probes that do not require a database connection."""

from fastapi import APIRouter
from pydantic import BaseModel

from app.core.responses import ApiResponse

router = APIRouter(tags=["health"])


class HealthData(BaseModel):
    status: str = "ok"


@router.get("/health", response_model=ApiResponse[HealthData])
@router.get("/api/v1/health", response_model=ApiResponse[HealthData])
def health() -> ApiResponse[HealthData]:
    return ApiResponse(data=HealthData())
