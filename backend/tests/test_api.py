from unittest.mock import AsyncMock, patch
import pytest
from fastapi.testclient import TestClient
from pydantic import SecretStr
from app.main import create_app
from app.core.config import Settings
from app.schemas.common import Pagination

def app_for_test():
    return create_app(Settings(environment='test', database_url=SecretStr('postgresql+asyncpg://test:test@127.0.0.1:1/test')))

def test_live_and_missing_route():
    with TestClient(app_for_test()) as client:
        assert client.get('/api/v1/health/live').json() == {'status': 'ok'}
        response = client.get('/missing')
        assert response.status_code == 404
        assert response.headers['content-type'] == 'application/problem+json'
        assert response.json()['trace_id'] == response.headers['x-trace-id']

def test_unreachable_database_is_unready():
    with TestClient(app_for_test()) as client:
        response = client.get('/api/v1/health/ready')
        assert response.status_code == 503
        assert response.json()['code'] == 'database_unavailable'
        assert 'test:test' not in response.text

def test_validation_and_unexpected_exception_do_not_echo_secrets():
    app = app_for_test()
    @app.get('/validate')
    def validate(value: int):
        return value
    @app.get('/explode')
    def explode():
        raise RuntimeError('private-password')
    with TestClient(app, raise_server_exceptions=False) as client:
        result = client.get('/validate?value=private-password')
        assert result.status_code == 422
        assert result.json()['errors'][0]['location'] == ['query', 'value']
        assert 'private-password' not in result.text
        result = client.get('/explode')
        assert result.status_code == 500
        assert 'private-password' not in result.text

def test_configuration_and_pagination():
    with pytest.raises(ValueError):
        Settings(environment='production', database_url=None).connection_url()
    with pytest.raises(ValueError):
        Settings(database_url=SecretStr('sqlite:///test.db')).connection_url()
    for values in ({'page': 0}, {'page_size': 101}):
        with pytest.raises(ValueError):
            Pagination(**values)

@pytest.mark.parametrize('unsafe,owner,version,tables,code', [
    (True,False,160000,25,'unsafe_database_role'),
    (False,True,160000,25,'unsafe_database_role'),
    (False,False,150000,25,'database_not_ready'),
    (False,False,160000,0,'database_not_ready'),
    (False,False,160000,25,None),
])
async def test_readiness_policy(unsafe,owner,version,tables,code):
    from app.services.health import check_readiness
    from app.core.errors import AppError
    from unittest.mock import MagicMock
    engine=MagicMock()
    engine.connect.return_value.__aenter__=AsyncMock(return_value=object())
    engine.connect.return_value.__aexit__=AsyncMock(return_value=False)
    with patch('app.services.health.inspect_database', new=AsyncMock(return_value={
        'unsafe_role': unsafe, 'owns_tables': owner, 'version': version, 'protected_tables': tables})):
        if code:
            with pytest.raises(AppError) as error:
                await check_readiness(engine)
            assert error.value.code == code
        else:
            await check_readiness(engine)
