from contextlib import asynccontextmanager
from uuid import UUID
from sqlalchemy import text
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

def session_factory(url: str):
    return async_sessionmaker(create_async_engine(url, pool_pre_ping=True), expire_on_commit=False)

@asynccontextmanager
async def tenant_transaction(factory, tenant_id: UUID):
    """Caller must authorize tenant membership before opening this transaction."""
    async with factory() as session, session.begin():
        await session.execute(text("SELECT set_config('app.tenant_id', :tenant, true)"), {"tenant": str(tenant_id)})
        yield session

