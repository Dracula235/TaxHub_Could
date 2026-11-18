"""PostgreSQL schema. Tenant references always include tenant_id."""
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import registry

metadata = sa.MetaData(naming_convention={
    "ix": "ix_%(table_name)s_%(column_0_name)s",
    "uq": "uq_%(table_name)s_%(column_0_N_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
})
mapper_registry = registry(metadata=metadata)
money = sa.Numeric(20, 2)

def col(name, type_=sa.Text, **kw):
    return sa.Column(name, type_, nullable=kw.pop("nullable", False), **kw)

def ref(name, target, nullable=False):
    return (col(name, UUID, nullable=nullable), sa.ForeignKeyConstraint(
        ["tenant_id", name], [f"{target}.tenant_id", f"{target}.id"]))

def state(values, default, name="status"):
    return (col(name, sa.Text, server_default=default), sa.CheckConstraint(
        f"{name} IN ({','.join(repr(v) for v in values.split())})", name=f"ck_{name}_{default}"))

def amounts():
    return (col("amount", money), col("tax", money), col("total", money),
            sa.CheckConstraint("amount >= 0 AND tax >= 0 AND total = amount + tax AND total < 'Infinity'::numeric", name="ck_amounts"))

def table(name, *items, tenant=True):
    columns = [col("id", UUID, primary_key=True, server_default=sa.text("gen_random_uuid()"))]
    if tenant:
        columns += [col("tenant_id", UUID)]
        columns += [sa.ForeignKeyConstraint(["tenant_id"], ["tenant.id"]), sa.UniqueConstraint("tenant_id", "id")]
    columns += [col("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
                col("created_by", UUID, nullable=True),
                col("version", sa.Integer, server_default="1"), sa.CheckConstraint("version > 0", name="ck_version")]
    for item in items:
        columns.extend(item if isinstance(item, tuple) else [item])
    result = sa.Table(name, metadata, *columns)
    if tenant:
        sa.Index(f"ix_{name}_tenant", result.c.tenant_id)
    return result

tenant = table("tenant", col("name"), tenant=False)
app_user = table("app_user", col("login", unique=True), col("password_hash"), tenant=False)
membership = table("membership", col("user_id", UUID), col("permissions", JSONB),
    sa.ForeignKeyConstraint(["user_id"], ["app_user.id"]), sa.UniqueConstraint("tenant_id", "user_id"))
account = table("account", col("code"), col("name"), col("enabled", sa.Boolean, server_default=sa.true()), sa.UniqueConstraint("tenant_id", "code"))
period = table("accounting_period", col("period", sa.String(7)), col("locked", sa.Boolean, server_default=sa.false()),
    sa.CheckConstraint("period ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'", name="ck_period"), sa.UniqueConstraint("tenant_id", "period"))
tax_rate = table("tax_rate", col("scope"), col("rate", sa.Numeric(9,6)), col("valid_from", sa.Date), col("valid_to", sa.Date), col("policy_source"),
    sa.CheckConstraint("rate >= 0 AND rate <= 1 AND valid_to > valid_from", name="ck_tax_rate"))
invoice = table("invoice", col("namespace"), col("kind"), col("code", server_default=""), col("number"),
    state("input output", "input", "direction"), state("simulation production", "simulation", "mode"),
    col("seller", JSONB), col("buyer", JSONB), col("invoice_date", sa.Date), amounts(),
    state("collected verifying verified verify_failed pending_posting posted archived voided red_flushed", "collected"),
    sa.UniqueConstraint("tenant_id", "namespace", "kind", "code", "number"))
issue = table("invoice_issue_request", col("buyer", JSONB), col("seller", JSONB), col("kind"), col("business_date", sa.Date), amounts(),
    state("draft queued issuing unknown failed issued cancelled", "draft"), state("simulation production", "simulation", "mode"),
    col("external_key", nullable=True), col("submitted_snapshot", JSONB, nullable=True), col("receipt_key", nullable=True),
    ref("invoice_id", "invoice", True), sa.UniqueConstraint("tenant_id", "external_key"), sa.UniqueConstraint("tenant_id", "invoice_id"),
    sa.CheckConstraint("status <> 'issued' OR invoice_id IS NOT NULL", name="ck_issued_invoice"))
for name, parent, key in [("invoice_line", "invoice", "invoice_id"), ("invoice_issue_line", "invoice_issue_request", "request_id")]:
    table(name, ref(key,parent), col("line_no", sa.Integer), col("description"), col("quantity", sa.Numeric(20,6)), col("unit_price", sa.Numeric(20,6)),
        ref("tax_rate_id", "tax_rate", True), col("rate_snapshot", sa.Numeric(9,6)), amounts(),
        sa.CheckConstraint("quantity > 0 AND quantity < 'Infinity'::numeric AND unit_price >= 0 AND unit_price < 'Infinity'::numeric AND rate_snapshot BETWEEN 0 AND 1", name="ck_line_values"),
        sa.UniqueConstraint("tenant_id",key,"line_no"))
table("invoice_verification", ref("invoice_id", "invoice"), col("operation_key"), col("result", JSONB), state("simulation production", "simulation", "mode"), sa.UniqueConstraint("tenant_id","operation_key"))
reimbursement = table("reimbursement", col("applicant_id", UUID), col("department"), col("reason"), col("amount", money),
    sa.ForeignKeyConstraint(["applicant_id"],["app_user.id"]),
    sa.CheckConstraint("amount > 0 AND amount < 'Infinity'::numeric", name="ck_reimbursement_amount"),
    state("draft submitted approved rejected cancelled", "draft"), state("unposted posted", "unposted", "posting_status"))
table("reimbursement_line", ref("reimbursement_id", "reimbursement"), col("line_no", sa.Integer), col("category"), col("description"), col("amount", money),
    sa.CheckConstraint("amount > 0 AND amount < 'Infinity'::numeric", name="ck_expense_amount"), sa.UniqueConstraint("tenant_id","reimbursement_id","line_no"))
table("reimbursement_invoice", ref("reimbursement_id", "reimbursement"), ref("invoice_id", "invoice"), sa.UniqueConstraint("tenant_id","reimbursement_id","invoice_id"))
claim = table("invoice_claim", ref("invoice_id", "invoice"), ref("reimbursement_id", "reimbursement"), col("released_at", sa.DateTime(timezone=True), nullable=True))
sa.Index("uq_active_invoice_claim", claim.c.tenant_id, claim.c.invoice_id, unique=True, postgresql_where=claim.c.released_at.is_(None))
table("approval_record", ref("reimbursement_id", "reimbursement"), col("actor_id", UUID), col("decision"), col("reason"), col("submission_version", sa.Integer),
    sa.ForeignKeyConstraint(["actor_id"],["app_user.id"]), sa.CheckConstraint("decision IN ('approve','reject')", name="ck_decision"))
table("payment_record", ref("reimbursement_id", "reimbursement"), col("reference"), col("amount", money), col("paid_at", sa.DateTime(timezone=True)), col("evidence_key"),
    sa.CheckConstraint("amount > 0 AND amount < 'Infinity'::numeric", name="ck_payment_amount"), sa.UniqueConstraint("tenant_id","reference"))
source = table("posting_source", ref("invoice_id","invoice",True), ref("reimbursement_id","reimbursement",True),
    sa.CheckConstraint("num_nonnulls(invoice_id,reimbursement_id) = 1", name="ck_source_one_origin"),
    sa.UniqueConstraint("tenant_id","invoice_id"), sa.UniqueConstraint("tenant_id","reimbursement_id"))
table("posting_source_invoice", ref("source_id","posting_source"), ref("invoice_id","invoice"), sa.UniqueConstraint("tenant_id","invoice_id"))
table("posting_rule", col("name"), col("rule_version", sa.Integer), col("definition", JSONB), col("enabled",sa.Boolean,server_default=sa.true()), sa.UniqueConstraint("tenant_id","name","rule_version"))
table("posting_suggestion", ref("source_id","posting_source"), col("source_version",sa.Integer), col("rule_version",sa.Integer), col("entries",JSONB), col("signals",JSONB),
    col("confidence",sa.Numeric(20,18)), col("need_review",sa.Boolean), state("active superseded accepted rejected", "active"),
    sa.CheckConstraint("confidence BETWEEN 0 AND 1",name="ck_confidence"))
voucher = table("voucher", ref("period_id","accounting_period"), col("number",sa.BigInteger), col("summary"),
    col("debit_total",money), col("credit_total",money),
    sa.CheckConstraint("debit_total > 0 AND debit_total < 'Infinity'::numeric AND debit_total = credit_total",name="ck_voucher_balance"),
    sa.UniqueConstraint("tenant_id","period_id","number"))
table("voucher_line", ref("voucher_id","voucher"), ref("account_id","account"), col("line_no",sa.Integer), col("debit",money), col("credit",money), col("auxiliary",JSONB),
    sa.CheckConstraint("((debit > 0 AND credit = 0) OR (credit > 0 AND debit = 0)) AND debit < 'Infinity'::numeric AND credit < 'Infinity'::numeric", name="ck_entry_side"),
    sa.UniqueConstraint("tenant_id","voucher_id","line_no"))
table("voucher_source", ref("voucher_id","voucher"), ref("source_id","posting_source"), sa.UniqueConstraint("tenant_id","source_id"))
table("idempotency_record", col("actor_id",UUID), col("action"), col("target"), col("key"), col("request_hash"), col("response",JSONB,nullable=True), state("processing completed failed","processing"),
    sa.UniqueConstraint("tenant_id","actor_id","action","target","key"))
table("outbox_event", col("event_type"), col("resource_id",UUID), col("payload",JSONB), col("published_at",sa.DateTime(timezone=True),nullable=True))
table("audit_log", col("actor_id",UUID), col("action"), col("resource_id",UUID), col("detail",JSONB))

# Imperative ORM mapping keeps SQLAlchemy tables and mapped classes in one schema.
models = {}
for _table in metadata.tables.values():
    _class = type(''.join(word.title() for word in _table.name.split('_')), (), {})
    mapper_registry.map_imperatively(_class, _table)
    models[_table.name] = _class
    globals()[_class.__name__] = _class
