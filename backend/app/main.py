from contextlib import asynccontextmanager
from uuid import uuid4
from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException
from sqlalchemy.ext.asyncio import create_async_engine
from app.api.v1.health import router
from app.core.config import Settings
from app.core.errors import AppError, problem_response

def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or Settings()

    @asynccontextmanager
    async def lifespan(app):
        engine = create_async_engine(settings.connection_url(), pool_pre_ping=True,
                                     connect_args={'timeout': 3, 'command_timeout': 3})
        app.state.engine = engine
        try:
            yield
        finally:
            await engine.dispose()

    app = FastAPI(title='税枢云后端', version='0.1.0', lifespan=lifespan,
                  docs_url=None if settings.environment == 'production' else '/docs',
                  redoc_url=None)

    @app.middleware('http')
    async def trace(request: Request, call_next):
        request.state.trace_id = uuid4().hex
        response = await call_next(request)
        response.headers['X-Trace-ID'] = request.state.trace_id
        return response

    @app.exception_handler(AppError)
    async def application_error(request, exc):
        return problem_response(request, exc.status, exc.code, exc.detail)

    @app.exception_handler(HTTPException)
    async def http_error(request, exc):
        response = problem_response(request, exc.status_code, f'http_{exc.status_code}', str(exc.detail))
        if exc.headers:
            response.headers.update(exc.headers)
        return response

    @app.exception_handler(RequestValidationError)
    async def validation_error(request, exc):
        errors = [{'location': list(e['loc']), 'message': '字段格式或取值不合法', 'code': e['type']} for e in exc.errors()]
        return problem_response(request, 422, 'validation_error', '请求参数校验失败', errors)

    @app.exception_handler(Exception)
    async def unexpected_error(request, exc):
        return problem_response(request, 500, 'internal_error', '服务器内部错误')

    app.include_router(router, prefix='/api/v1')
    return app

app = create_app()
