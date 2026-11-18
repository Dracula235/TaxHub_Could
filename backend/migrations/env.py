import asyncio
import os
from alembic import context
from sqlalchemy.ext.asyncio import create_async_engine
from app.models import metadata

url = os.environ["DATABASE_URL"]

def migrate(connection):
    context.configure(connection=connection, target_metadata=metadata, compare_type=True)
    with context.begin_transaction():
        context.run_migrations()

async def online():
    engine = create_async_engine(url)
    async with engine.connect() as connection:
        await connection.run_sync(migrate)
    await engine.dispose()

if context.is_offline_mode():
    context.configure(url=url, target_metadata=metadata, literal_binds=True)
    with context.begin_transaction():
        context.run_migrations()
else:
    asyncio.run(online())
