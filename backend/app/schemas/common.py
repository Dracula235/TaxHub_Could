from pydantic import BaseModel, Field
from typing import Literal

class Health(BaseModel):
    status: Literal['ok', 'ready']

class FieldError(BaseModel):
    location: list[str | int]
    message: str
    code: str

class Problem(BaseModel):
    type: str = 'about:blank'
    title: str
    status: int
    detail: str
    instance: str
    code: str
    trace_id: str
    errors: list[FieldError] = Field(default_factory=list)

class Pagination(BaseModel):
    page: int = Field(default=1, ge=1)
    page_size: int = Field(default=20, ge=1, le=100)
