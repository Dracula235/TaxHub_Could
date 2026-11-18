"""Configure this task's local container only. Credentials stay in ignored .local."""
import asyncio
import json
import secrets
from pathlib import Path
import asyncpg

async def main():
    config = json.loads(Path('.local/database.json').read_text(encoding='utf-8-sig'))
    owner = f"postgresql://taxhub_owner:{config['password']}@{config['host']}:{config['port']}"
    connection = await asyncpg.connect(owner+'/taxhub')
    password = secrets.token_hex(24)
    if not await connection.fetchval("SELECT 1 FROM pg_roles WHERE rolname='taxhub_app'"):
        await connection.execute(f"CREATE ROLE taxhub_app LOGIN PASSWORD '{password}' NOSUPERUSER NOBYPASSRLS")
        config['app_password'] = password
    if not await connection.fetchval("SELECT 1 FROM pg_database WHERE datname='taxhub_test'"):
        await connection.execute('CREATE DATABASE taxhub_test')
    await connection.close()
    Path('.local/database.json').write_text(json.dumps(config),encoding='utf-8')
    print('Local application role and isolated test database ready')

asyncio.run(main())
