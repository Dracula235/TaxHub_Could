from uuid import UUID
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

async def get_by_id(session: AsyncSession, model, tenant_id: UUID, record_id: UUID):
    """Explicit filtering supplements database RLS; caller owns the transaction."""
    return await session.scalar(select(model).where(model.tenant_id == tenant_id, model.id == record_id))
