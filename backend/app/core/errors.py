from http import HTTPStatus
from fastapi import Request
from fastapi.responses import JSONResponse
from app.schemas.common import Problem

class AppError(Exception):
    def __init__(self, status: int, code: str, detail: str):
        self.status, self.code, self.detail = status, code, detail

def problem_response(request: Request, status: int, code: str, detail: str, errors=None):
    body = Problem(title=HTTPStatus(status).phrase, status=status, detail=detail,
                   instance=request.url.path, code=code, trace_id=request.state.trace_id,
                   errors=errors or [])
    return JSONResponse(body.model_dump(), status_code=status, media_type='application/problem+json',
                        headers={'X-Trace-ID': request.state.trace_id})
