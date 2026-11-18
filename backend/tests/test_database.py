"""Runs only against an explicitly configured isolated PostgreSQL test database."""
import os
from uuid import uuid4
import asyncpg
import pytest
import pytest_asyncio

@pytest_asyncio.fixture
async def db():
    url = os.environ.get('TEST_DATABASE_URL')
    if not url:
        pytest.skip('TEST_DATABASE_URL required; no SQLite fallback')
    conn = await asyncpg.connect(url)
    if not (await conn.fetchval('select current_database()')).endswith('_test'):
        await conn.close()
        raise RuntimeError('Tests require a database ending in _test')
    tx = conn.transaction()
    await tx.start()
    try:
        yield conn
    finally:
        await tx.rollback()
        await conn.close()

async def tenant(db):
    return await db.fetchval("insert into tenant(name) values('synthetic test') returning id")

async def context(db, t):
    await db.execute("select set_config('app.tenant_id',$1,true)", str(t))

@pytest.mark.asyncio
async def test_rls_and_cross_tenant_fk(db):
    a,b = await tenant(db),await tenant(db)
    await db.execute("insert into account(tenant_id,code,name) values($1,'1001','test')",a)
    invoice = await db.fetchval("insert into invoice(tenant_id,namespace,kind,number,seller,buyer,invoice_date,amount,tax,total) values($1,'test','test','SIM-CROSS','{}','{}','2026-01-01',100,6,106) returning id",a)
    await db.execute('SET LOCAL ROLE taxhub_app')
    assert await db.fetchval('select count(*) from account') == 0
    await context(db,b)
    assert await db.fetchval('select count(*) from account') == 0
    with pytest.raises(asyncpg.InsufficientPrivilegeError):
        async with db.transaction():
            await db.execute("insert into account(tenant_id,code,name) values($1,'1002','test')",a)
    await context(db,a)
    assert await db.fetchval('select count(*) from account') == 1
    await context(db,b)
    with pytest.raises(asyncpg.ForeignKeyViolationError):
        async with db.transaction():
            await db.execute("insert into posting_source(tenant_id,invoice_id) values($1,$2)",b,invoice)

@pytest.mark.asyncio
async def test_money_and_unique(db):
    t = await tenant(db)
    await context(db,t)
    await db.execute('SET LOCAL ROLE taxhub_app')
    sql = "insert into invoice(tenant_id,namespace,kind,number,seller,buyer,invoice_date,amount,tax,total) values($1,'test','test','SIM-001','{}','{}','2026-01-01',100,6,$2)"
    with pytest.raises(asyncpg.CheckViolationError):
        async with db.transaction():
            await db.execute(sql,t,107)
    await db.execute(sql,t,106)
    with pytest.raises(asyncpg.UniqueViolationError):
        async with db.transaction():
            await db.execute(sql,t,106)

@pytest.mark.asyncio
async def test_voucher_requires_balanced_lines(db):
    t = await tenant(db)
    await context(db,t)
    await db.execute('SET LOCAL ROLE taxhub_app')
    p = await db.fetchval("insert into accounting_period(tenant_id,period) values($1,'2026-01') returning id",t)
    a = await db.fetchval("insert into account(tenant_id,code,name) values($1,'1001','test') returning id",t)
    v = await db.fetchval("insert into voucher(tenant_id,period_id,number,summary,debit_total,credit_total) values($1,$2,1,'test',100,100) returning id",t,p)
    with pytest.raises(asyncpg.RaiseError):
        async with db.transaction():
            await db.execute('SET CONSTRAINTS ALL IMMEDIATE')
    await db.execute("insert into voucher_line(tenant_id,voucher_id,account_id,line_no,debit,credit,auxiliary) values($1,$2,$3,1,100,0,'{}'),($1,$2,$3,2,0,100,'{}')",t,v,a)
    await db.execute('SET CONSTRAINTS ALL IMMEDIATE')
    with pytest.raises(asyncpg.RaiseError):
        async with db.transaction():
            await db.execute('delete from voucher_line where tenant_id=$1 and voucher_id=$2 and line_no=1',t,v)

@pytest.mark.asyncio
async def test_tax_overlap_and_audit_immutable(db):
    t = await tenant(db)
    await context(db,t)
    await db.execute('SET LOCAL ROLE taxhub_app')
    sql = "insert into tax_rate(tenant_id,scope,rate,valid_from,valid_to,policy_source) values($1,'synthetic',0.06,'2026-01-01','2027-01-01','test only')"
    await db.execute(sql,t)
    with pytest.raises(asyncpg.ExclusionViolationError):
        async with db.transaction():
            await db.execute(sql,t)
    await db.execute("insert into audit_log(tenant_id,actor_id,action,resource_id,detail) values($1,$2,'test',$2,'{}')",t,uuid4())
    with pytest.raises(asyncpg.RaiseError):
        async with db.transaction():
            await db.execute('delete from audit_log where tenant_id=$1',t)

@pytest.mark.asyncio
async def test_claim_release_and_posting_deduplication(db):
    t = await tenant(db)
    user = await db.fetchval("insert into app_user(login,password_hash) values($1,'synthetic') returning id",str(uuid4()))
    await context(db,t)
    await db.execute('SET LOCAL ROLE taxhub_app')
    inv = await db.fetchval("insert into invoice(tenant_id,namespace,kind,number,seller,buyer,invoice_date,amount,tax,total) values($1,'test','test','SIM-002','{}','{}','2026-01-01',100,6,106) returning id",t)
    expense = await db.fetchval("insert into reimbursement(tenant_id,applicant_id,department,reason,amount) values($1,$2,'test','test',106) returning id",t,user)
    claim_sql = 'insert into invoice_claim(tenant_id,invoice_id,reimbursement_id) values($1,$2,$3)'
    await db.execute(claim_sql,t,inv,expense)
    with pytest.raises(asyncpg.UniqueViolationError):
        async with db.transaction():
            await db.execute(claim_sql,t,inv,expense)
    await db.execute('update invoice_claim set released_at=now() where tenant_id=$1 and invoice_id=$2',t,inv)
    await db.execute(claim_sql,t,inv,expense)
    source = await db.fetchval('insert into posting_source(tenant_id,invoice_id) values($1,$2) returning id',t,inv)
    other = await db.fetchval('insert into posting_source(tenant_id,reimbursement_id) values($1,$2) returning id',t,expense)
    await db.execute('insert into posting_source_invoice(tenant_id,source_id,invoice_id) values($1,$2,$3)',t,source,inv)
    with pytest.raises(asyncpg.UniqueViolationError):
        async with db.transaction():
            await db.execute('insert into posting_source_invoice(tenant_id,source_id,invoice_id) values($1,$2,$3)',t,other,inv)
