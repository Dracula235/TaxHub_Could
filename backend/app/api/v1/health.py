from fastapi import APIRouter, Request
from app.schemas.common import Health, Problem
from app.services.health import check_readiness

router = APIRouter(tags=['health'])

@router.get('/health/live', response_model=Health)
async def live():
    return Health(status='ok')

@router.get('/health/ready', response_model=Health, responses={503: {'model': Problem}})
async def ready(request: Request):
    await check_readiness(request.app.state.engine)
    return Health(status='ready')
