import asyncio
import json
from pathlib import Path
import asyncpg
from app.models import metadata

async def main():
    config = json.loads(Path('.local/database.json').read_text(encoding='utf-8-sig'))
    for database in ('taxhub', 'taxhub_test'):
        conn = await asyncpg.connect(f"postgresql://taxhub_owner:{config['password']}@{config['host']}:{config['port']}/{database}")
        await conn.execute('REVOKE CREATE ON SCHEMA public FROM PUBLIC')
        await conn.execute('GRANT USAGE ON SCHEMA public TO taxhub_app')
        for table in metadata.tables.values():
            if 'tenant_id' in table.c:
                await conn.execute(f'GRANT SELECT, INSERT, UPDATE, DELETE ON "{table.name}" TO taxhub_app')
        await conn.close()
    print('Runtime role grants configured for both local databases')

asyncio.run(main())
