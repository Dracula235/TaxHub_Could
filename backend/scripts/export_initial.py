"""Development-only initial snapshot generator. Never rerun after release."""
from pathlib import Path
from sqlalchemy.schema import CreateTable, CreateIndex
from sqlalchemy.dialects.postgresql import dialect
from app.models import metadata

statements = []
for table in metadata.sorted_tables:
    statements.append(str(CreateTable(table).compile(dialect=dialect())))
    statements.extend(str(CreateIndex(index).compile(dialect=dialect())) for index in sorted(table.indexes, key=lambda i: i.name))
    if 'tenant_id' in table.c:
        statements.extend([
            f'ALTER TABLE "{table.name}" ENABLE ROW LEVEL SECURITY',
            f'ALTER TABLE "{table.name}" FORCE ROW LEVEL SECURITY',
            f'''CREATE POLICY tenant_isolation ON "{table.name}"
            USING (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
            WITH CHECK (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)'''])
statements += ["CREATE EXTENSION IF NOT EXISTS btree_gist",
    "ALTER TABLE tax_rate ADD CONSTRAINT tax_rate_no_overlap EXCLUDE USING gist (tenant_id WITH =, scope WITH =, daterange(valid_from, valid_to, '[)') WITH &&)",
    """CREATE FUNCTION deny_audit_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN RAISE EXCEPTION 'audit records are append only'; END $$""",
    "CREATE TRIGGER audit_append_only BEFORE UPDATE OR DELETE ON audit_log FOR EACH ROW EXECUTE FUNCTION deny_audit_mutation()",
    """CREATE FUNCTION check_voucher_balance() RETURNS trigger LANGUAGE plpgsql AS $$
    DECLARE target uuid; owner_tenant uuid; expected numeric; d numeric; c numeric; n integer;
    BEGIN
      IF TG_TABLE_NAME = 'voucher' THEN target := NEW.id; owner_tenant := NEW.tenant_id;
      ELSE target := COALESCE(NEW.voucher_id, OLD.voucher_id); owner_tenant := COALESCE(NEW.tenant_id, OLD.tenant_id); END IF;
      SELECT debit_total INTO expected FROM voucher WHERE id=target AND tenant_id=owner_tenant FOR UPDATE;
      IF NOT FOUND THEN RETURN NULL; END IF;
      SELECT coalesce(sum(debit),0), coalesce(sum(credit),0), count(*) INTO d,c,n FROM voucher_line WHERE voucher_id=target AND tenant_id=owner_tenant;
      IF n < 2 OR d <> c OR d <> expected THEN RAISE EXCEPTION 'voucher lines do not balance with header'; END IF;
      RETURN NULL;
    END $$""",
    "CREATE CONSTRAINT TRIGGER voucher_balance AFTER INSERT OR UPDATE ON voucher DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION check_voucher_balance()",
    "CREATE CONSTRAINT TRIGGER voucher_line_balance AFTER INSERT OR UPDATE OR DELETE ON voucher_line DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION check_voucher_balance()",
    """CREATE FUNCTION deny_line_reparent() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN IF NEW.voucher_id <> OLD.voucher_id OR NEW.tenant_id <> OLD.tenant_id THEN RAISE EXCEPTION 'cannot reparent voucher line'; END IF; RETURN NEW; END $$""",
    "CREATE TRIGGER voucher_line_no_reparent BEFORE UPDATE ON voucher_line FOR EACH ROW EXECUTE FUNCTION deny_line_reparent()"]
Path('migrations/versions/0001_schema.sql').write_text('\n-- statement-break\n'.join(statements), encoding='utf-8')
print(f'Exported {len(metadata.tables)} tables')
