import json
from pathlib import Path
from typing import Literal
from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict
from sqlalchemy.engine import URL, make_url

ROOT = Path(__file__).resolve().parents[2]

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix='TAXHUB_', env_file=ROOT / '.env', extra='ignore')
    environment: Literal['development', 'test', 'production'] = 'development'
    database_url: SecretStr | None = None

    def connection_url(self) -> URL:
        if self.database_url:
            url = make_url(self.database_url.get_secret_value())
        elif self.environment == 'development':
            config = json.loads((ROOT / '.local/database.json').read_text(encoding='utf-8-sig'))
            url = URL.create('postgresql+asyncpg', username='taxhub_app', password=config['app_password'],
                             host=config['host'], port=config['port'], database=config['database'])
        else:
            raise ValueError('TAXHUB_DATABASE_URL is required outside development')
        if url.drivername != 'postgresql+asyncpg':
            raise ValueError('PostgreSQL asyncpg connection required')
        return url
