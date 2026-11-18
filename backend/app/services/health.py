import asyncio
from app.core.errors import AppError
from app.repositories.health import inspect_database

async def check_readiness(engine):
    try:
        async with asyncio.timeout(3):
            async with engine.connect() as connection:
                result = await inspect_database(connection)
        if result['unsafe_role'] or result['owns_tables']:
            raise AppError(503, 'unsafe_database_role', '数据库运行账号权限不符合要求')
        if not 160000 <= result['version'] < 170000 or result['protected_tables'] < 25:
            raise AppError(503, 'database_not_ready', '数据库版本或租户隔离结构尚未就绪')
    except AppError:
        raise
    except Exception:
        raise AppError(503, 'database_unavailable', '数据库暂不可用') from None
