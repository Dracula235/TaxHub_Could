
CREATE TABLE app_user (
	id UUID DEFAULT gen_random_uuid() NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	created_by UUID, 
	version INTEGER DEFAULT '1' NOT NULL, 
	login TEXT NOT NULL, 
	password_hash TEXT NOT NULL, 
	CONSTRAINT pk_app_user PRIMARY KEY (id), 
	CONSTRAINT ck_version CHECK (version > 0), 
	CONSTRAINT uq_app_user_login UNIQUE (login)
)


-- statement-break

CREATE TABLE tenant (
	id UUID DEFAULT gen_random_uuid() NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	created_by UUID, 
	version INTEGER DEFAULT '1' NOT NULL, 
	name TEXT NOT NULL, 
	CONSTRAINT pk_tenant PRIMARY KEY (id), 
	CONSTRAINT ck_version CHECK (version > 0)
)


-- statement-break

CREATE TABLE account (
	id UUID DEFAULT gen_random_uuid() NOT NULL, 
	tenant_id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	created_by UUID, 
	version INTEGER DEFAULT '1' NOT NULL, 
	code TEXT NOT NULL, 
	name TEXT NOT NULL, 
	enabled BOOLEAN DEFAULT true NOT NULL, 
	CONSTRAINT pk_account PRIMARY KEY (id), 
	CONSTRAINT uq_account_tenant_id_code UNIQUE (tenant_id, code), 
	CONSTRAINT fk_account_tenant_id_tenant FOREIGN KEY(tenant_id) REFERENCES tenant (id), 
	CONSTRAINT uq_account_tenant_id_id UNIQUE (tenant_id, id), 
	CONSTRAINT ck_version CHECK (version > 0)
)


-- statement-break
CREATE INDEX ix_account_tenant ON account (tenant_id)
-- statement-break
ALTER TABLE "account" ENABLE ROW LEVEL SECURITY
-- statement-break
ALTER TABLE "account" FORCE ROW LEVEL SECURITY
-- statement-break
CREATE POLICY tenant_isolation ON "account"
            USING (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
            WITH CHECK (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
-- statement-break

CREATE TABLE accounting_period (
	id UUID DEFAULT gen_random_uuid() NOT NULL, 
	tenant_id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	created_by UUID, 
	version INTEGER DEFAULT '1' NOT NULL, 
	period VARCHAR(7) NOT NULL, 
	locked BOOLEAN DEFAULT false NOT NULL, 
	CONSTRAINT pk_accounting_period PRIMARY KEY (id), 
	CONSTRAINT ck_period CHECK (period ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'), 
	CONSTRAINT uq_accounting_period_tenant_id_period UNIQUE (tenant_id, period), 
	CONSTRAINT fk_accounting_period_tenant_id_tenant FOREIGN KEY(tenant_id) REFERENCES tenant (id), 
	CONSTRAINT uq_accounting_period_tenant_id_id UNIQUE (tenant_id, id), 
	CONSTRAINT ck_version CHECK (version > 0)
)


-- statement-break
CREATE INDEX ix_accounting_period_tenant ON accounting_period (tenant_id)
-- statement-break
ALTER TABLE "accounting_period" ENABLE ROW LEVEL SECURITY
-- statement-break
ALTER TABLE "accounting_period" FORCE ROW LEVEL SECURITY
-- statement-break
CREATE POLICY tenant_isolation ON "accounting_period"
            USING (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
            WITH CHECK (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
-- statement-break

CREATE TABLE audit_log (
	id UUID DEFAULT gen_random_uuid() NOT NULL, 
	tenant_id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	created_by UUID, 
	version INTEGER DEFAULT '1' NOT NULL, 
	actor_id UUID NOT NULL, 
	action TEXT NOT NULL, 
	resource_id UUID NOT NULL, 
	detail JSONB NOT NULL, 
	CONSTRAINT pk_audit_log PRIMARY KEY (id), 
	CONSTRAINT fk_audit_log_tenant_id_tenant FOREIGN KEY(tenant_id) REFERENCES tenant (id), 
	CONSTRAINT uq_audit_log_tenant_id_id UNIQUE (tenant_id, id), 
	CONSTRAINT ck_version CHECK (version > 0)
)


-- statement-break
CREATE INDEX ix_audit_log_tenant ON audit_log (tenant_id)
-- statement-break
ALTER TABLE "audit_log" ENABLE ROW LEVEL SECURITY
-- statement-break
ALTER TABLE "audit_log" FORCE ROW LEVEL SECURITY
-- statement-break
CREATE POLICY tenant_isolation ON "audit_log"
            USING (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
            WITH CHECK (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
-- statement-break

CREATE TABLE idempotency_record (
	id UUID DEFAULT gen_random_uuid() NOT NULL, 
	tenant_id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	created_by UUID, 
	version INTEGER DEFAULT '1' NOT NULL, 
	actor_id UUID NOT NULL, 
	action TEXT NOT NULL, 
	target TEXT NOT NULL, 
	key TEXT NOT NULL, 
	request_hash TEXT NOT NULL, 
	response JSONB, 
	status TEXT DEFAULT 'processing' NOT NULL, 
	CONSTRAINT pk_idempotency_record PRIMARY KEY (id), 
	CONSTRAINT ck_status_processing CHECK (status IN ('processing','completed','failed')), 
	CONSTRAINT uq_idempotency_record_tenant_id_actor_id_action_target_key UNIQUE (tenant_id, actor_id, action, target, key), 
	CONSTRAINT fk_idempotency_record_tenant_id_tenant FOREIGN KEY(tenant_id) REFERENCES tenant (id), 
	CONSTRAINT uq_idempotency_record_tenant_id_id UNIQUE (tenant_id, id), 
	CONSTRAINT ck_version CHECK (version > 0)
)


-- statement-break
CREATE INDEX ix_idempotency_record_tenant ON idempotency_record (tenant_id)
-- statement-break
ALTER TABLE "idempotency_record" ENABLE ROW LEVEL SECURITY
-- statement-break
ALTER TABLE "idempotency_record" FORCE ROW LEVEL SECURITY
-- statement-break
CREATE POLICY tenant_isolation ON "idempotency_record"
            USING (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
            WITH CHECK (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
-- statement-break

CREATE TABLE invoice (
	id UUID DEFAULT gen_random_uuid() NOT NULL, 
	tenant_id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	created_by UUID, 
	version INTEGER DEFAULT '1' NOT NULL, 
	namespace TEXT NOT NULL, 
	kind TEXT NOT NULL, 
	code TEXT DEFAULT '' NOT NULL, 
	number TEXT NOT NULL, 
	direction TEXT DEFAULT 'input' NOT NULL, 
	mode TEXT DEFAULT 'simulation' NOT NULL, 
	seller JSONB NOT NULL, 
	buyer JSONB NOT NULL, 
	invoice_date DATE NOT NULL, 
	amount NUMERIC(20, 2) NOT NULL, 
	tax NUMERIC(20, 2) NOT NULL, 
	total NUMERIC(20, 2) NOT NULL, 
	status TEXT DEFAULT 'collected' NOT NULL, 
	CONSTRAINT pk_invoice PRIMARY KEY (id), 
	CONSTRAINT ck_direction_input CHECK (direction IN ('input','output')), 
	CONSTRAINT ck_mode_simulation CHECK (mode IN ('simulation','production')), 
	CONSTRAINT ck_amounts CHECK (amount >= 0 AND tax >= 0 AND total = amount + tax AND total < 'Infinity'::numeric), 
	CONSTRAINT ck_status_collected CHECK (status IN ('collected','verifying','verified','verify_failed','pending_posting','posted','archived','voided','red_flushed')), 
	CONSTRAINT uq_invoice_tenant_id_namespace_kind_code_number UNIQUE (tenant_id, namespace, kind, code, number), 
	CONSTRAINT fk_invoice_tenant_id_tenant FOREIGN KEY(tenant_id) REFERENCES tenant (id), 
	CONSTRAINT uq_invoice_tenant_id_id UNIQUE (tenant_id, id), 
	CONSTRAINT ck_version CHECK (version > 0)
)


-- statement-break
CREATE INDEX ix_invoice_tenant ON invoice (tenant_id)
-- statement-break
ALTER TABLE "invoice" ENABLE ROW LEVEL SECURITY
-- statement-break
ALTER TABLE "invoice" FORCE ROW LEVEL SECURITY
-- statement-break
CREATE POLICY tenant_isolation ON "invoice"
            USING (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
            WITH CHECK (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
-- statement-break

CREATE TABLE membership (
	id UUID DEFAULT gen_random_uuid() NOT NULL, 
	tenant_id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	created_by UUID, 
	version INTEGER DEFAULT '1' NOT NULL, 
	user_id UUID NOT NULL, 
	permissions JSONB NOT NULL, 
	CONSTRAINT pk_membership PRIMARY KEY (id), 
	CONSTRAINT fk_membership_user_id_app_user FOREIGN KEY(user_id) REFERENCES app_user (id), 
	CONSTRAINT uq_membership_tenant_id_user_id UNIQUE (tenant_id, user_id), 
	CONSTRAINT fk_membership_tenant_id_tenant FOREIGN KEY(tenant_id) REFERENCES tenant (id), 
	CONSTRAINT uq_membership_tenant_id_id UNIQUE (tenant_id, id), 
	CONSTRAINT ck_version CHECK (version > 0)
)


-- statement-break
CREATE INDEX ix_membership_tenant ON membership (tenant_id)
-- statement-break
ALTER TABLE "membership" ENABLE ROW LEVEL SECURITY
-- statement-break
ALTER TABLE "membership" FORCE ROW LEVEL SECURITY
-- statement-break
CREATE POLICY tenant_isolation ON "membership"
            USING (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
            WITH CHECK (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
-- statement-break

CREATE TABLE outbox_event (
	id UUID DEFAULT gen_random_uuid() NOT NULL, 
	tenant_id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	created_by UUID, 
	version INTEGER DEFAULT '1' NOT NULL, 
	event_type TEXT NOT NULL, 
	resource_id UUID NOT NULL, 
	payload JSONB NOT NULL, 
	published_at TIMESTAMP WITH TIME ZONE, 
	CONSTRAINT pk_outbox_event PRIMARY KEY (id), 
	CONSTRAINT fk_outbox_event_tenant_id_tenant FOREIGN KEY(tenant_id) REFERENCES tenant (id), 
	CONSTRAINT uq_outbox_event_tenant_id_id UNIQUE (tenant_id, id), 
	CONSTRAINT ck_version CHECK (version > 0)
)


-- statement-break
CREATE INDEX ix_outbox_event_tenant ON outbox_event (tenant_id)
-- statement-break
ALTER TABLE "outbox_event" ENABLE ROW LEVEL SECURITY
-- statement-break
ALTER TABLE "outbox_event" FORCE ROW LEVEL SECURITY
-- statement-break
CREATE POLICY tenant_isolation ON "outbox_event"
            USING (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
            WITH CHECK (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
-- statement-break

CREATE TABLE posting_rule (
	id UUID DEFAULT gen_random_uuid() NOT NULL, 
	tenant_id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	created_by UUID, 
	version INTEGER DEFAULT '1' NOT NULL, 
	name TEXT NOT NULL, 
	rule_version INTEGER NOT NULL, 
	definition JSONB NOT NULL, 
	enabled BOOLEAN DEFAULT true NOT NULL, 
	CONSTRAINT pk_posting_rule PRIMARY KEY (id), 
	CONSTRAINT uq_posting_rule_tenant_id_name_rule_version UNIQUE (tenant_id, name, rule_version), 
	CONSTRAINT fk_posting_rule_tenant_id_tenant FOREIGN KEY(tenant_id) REFERENCES tenant (id), 
	CONSTRAINT uq_posting_rule_tenant_id_id UNIQUE (tenant_id, id), 
	CONSTRAINT ck_version CHECK (version > 0)
)


-- statement-break
CREATE INDEX ix_posting_rule_tenant ON posting_rule (tenant_id)
-- statement-break
ALTER TABLE "posting_rule" ENABLE ROW LEVEL SECURITY
-- statement-break
ALTER TABLE "posting_rule" FORCE ROW LEVEL SECURITY
-- statement-break
CREATE POLICY tenant_isolation ON "posting_rule"
            USING (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
            WITH CHECK (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
-- statement-break

CREATE TABLE reimbursement (
	id UUID DEFAULT gen_random_uuid() NOT NULL, 
	tenant_id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	created_by UUID, 
	version INTEGER DEFAULT '1' NOT NULL, 
	applicant_id UUID NOT NULL, 
	department TEXT NOT NULL, 
	reason TEXT NOT NULL, 
	amount NUMERIC(20, 2) NOT NULL, 
	status TEXT DEFAULT 'draft' NOT NULL, 
	posting_status TEXT DEFAULT 'unposted' NOT NULL, 
	CONSTRAINT pk_reimbursement PRIMARY KEY (id), 
	CONSTRAINT fk_reimbursement_applicant_id_app_user FOREIGN KEY(applicant_id) REFERENCES app_user (id), 
	CONSTRAINT ck_reimbursement_amount CHECK (amount > 0 AND amount < 'Infinity'::numeric), 
	CONSTRAINT ck_status_draft CHECK (status IN ('draft','submitted','approved','rejected','cancelled')), 
	CONSTRAINT ck_posting_status_unposted CHECK (posting_status IN ('unposted','posted')), 
	CONSTRAINT fk_reimbursement_tenant_id_tenant FOREIGN KEY(tenant_id) REFERENCES tenant (id), 
	CONSTRAINT uq_reimbursement_tenant_id_id UNIQUE (tenant_id, id), 
	CONSTRAINT ck_version CHECK (version > 0)
)


-- statement-break
CREATE INDEX ix_reimbursement_tenant ON reimbursement (tenant_id)
-- statement-break
ALTER TABLE "reimbursement" ENABLE ROW LEVEL SECURITY
-- statement-break
ALTER TABLE "reimbursement" FORCE ROW LEVEL SECURITY
-- statement-break
CREATE POLICY tenant_isolation ON "reimbursement"
            USING (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
            WITH CHECK (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
-- statement-break

CREATE TABLE tax_rate (
	id UUID DEFAULT gen_random_uuid() NOT NULL, 
	tenant_id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	created_by UUID, 
	version INTEGER DEFAULT '1' NOT NULL, 
	scope TEXT NOT NULL, 
	rate NUMERIC(9, 6) NOT NULL, 
	valid_from DATE NOT NULL, 
	valid_to DATE NOT NULL, 
	policy_source TEXT NOT NULL, 
	CONSTRAINT pk_tax_rate PRIMARY KEY (id), 
	CONSTRAINT ck_tax_rate CHECK (rate >= 0 AND rate <= 1 AND valid_to > valid_from), 
	CONSTRAINT fk_tax_rate_tenant_id_tenant FOREIGN KEY(tenant_id) REFERENCES tenant (id), 
	CONSTRAINT uq_tax_rate_tenant_id_id UNIQUE (tenant_id, id), 
	CONSTRAINT ck_version CHECK (version > 0)
)


-- statement-break
CREATE INDEX ix_tax_rate_tenant ON tax_rate (tenant_id)
-- statement-break
ALTER TABLE "tax_rate" ENABLE ROW LEVEL SECURITY
-- statement-break
ALTER TABLE "tax_rate" FORCE ROW LEVEL SECURITY
-- statement-break
CREATE POLICY tenant_isolation ON "tax_rate"
            USING (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
            WITH CHECK (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
-- statement-break

CREATE TABLE approval_record (
	id UUID DEFAULT gen_random_uuid() NOT NULL, 
	tenant_id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	created_by UUID, 
	version INTEGER DEFAULT '1' NOT NULL, 
	reimbursement_id UUID NOT NULL, 
	actor_id UUID NOT NULL, 
	decision TEXT NOT NULL, 
	reason TEXT NOT NULL, 
	submission_version INTEGER NOT NULL, 
	CONSTRAINT pk_approval_record PRIMARY KEY (id), 
	CONSTRAINT fk_approval_record_tenant_id_reimbursement FOREIGN KEY(tenant_id, reimbursement_id) REFERENCES reimbursement (tenant_id, id), 
	CONSTRAINT fk_approval_record_actor_id_app_user FOREIGN KEY(actor_id) REFERENCES app_user (id), 
	CONSTRAINT ck_decision CHECK (decision IN ('approve','reject')), 
	CONSTRAINT fk_approval_record_tenant_id_tenant FOREIGN KEY(tenant_id) REFERENCES tenant (id), 
	CONSTRAINT uq_approval_record_tenant_id_id UNIQUE (tenant_id, id), 
	CONSTRAINT ck_version CHECK (version > 0)
)


-- statement-break
CREATE INDEX ix_approval_record_tenant ON approval_record (tenant_id)
-- statement-break
ALTER TABLE "approval_record" ENABLE ROW LEVEL SECURITY
-- statement-break
ALTER TABLE "approval_record" FORCE ROW LEVEL SECURITY
-- statement-break
CREATE POLICY tenant_isolation ON "approval_record"
            USING (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
            WITH CHECK (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
-- statement-break

CREATE TABLE invoice_claim (
	id UUID DEFAULT gen_random_uuid() NOT NULL, 
	tenant_id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	created_by UUID, 
	version INTEGER DEFAULT '1' NOT NULL, 
	invoice_id UUID NOT NULL, 
	reimbursement_id UUID NOT NULL, 
	released_at TIMESTAMP WITH TIME ZONE, 
	CONSTRAINT pk_invoice_claim PRIMARY KEY (id), 
	CONSTRAINT fk_invoice_claim_tenant_id_invoice FOREIGN KEY(tenant_id, invoice_id) REFERENCES invoice (tenant_id, id), 
	CONSTRAINT fk_invoice_claim_tenant_id_reimbursement FOREIGN KEY(tenant_id, reimbursement_id) REFERENCES reimbursement (tenant_id, id), 
	CONSTRAINT fk_invoice_claim_tenant_id_tenant FOREIGN KEY(tenant_id) REFERENCES tenant (id), 
	CONSTRAINT uq_invoice_claim_tenant_id_id UNIQUE (tenant_id, id), 
	CONSTRAINT ck_version CHECK (version > 0)
)


-- statement-break
CREATE INDEX ix_invoice_claim_tenant ON invoice_claim (tenant_id)
-- statement-break
CREATE UNIQUE INDEX uq_active_invoice_claim ON invoice_claim (tenant_id, invoice_id) WHERE released_at IS NULL
-- statement-break
ALTER TABLE "invoice_claim" ENABLE ROW LEVEL SECURITY
-- statement-break
ALTER TABLE "invoice_claim" FORCE ROW LEVEL SECURITY
-- statement-break
CREATE POLICY tenant_isolation ON "invoice_claim"
            USING (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
            WITH CHECK (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
-- statement-break

CREATE TABLE invoice_issue_request (
	id UUID DEFAULT gen_random_uuid() NOT NULL, 
	tenant_id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	created_by UUID, 
	version INTEGER DEFAULT '1' NOT NULL, 
	buyer JSONB NOT NULL, 
	seller JSONB NOT NULL, 
	kind TEXT NOT NULL, 
	business_date DATE NOT NULL, 
	amount NUMERIC(20, 2) NOT NULL, 
	tax NUMERIC(20, 2) NOT NULL, 
	total NUMERIC(20, 2) NOT NULL, 
	status TEXT DEFAULT 'draft' NOT NULL, 
	mode TEXT DEFAULT 'simulation' NOT NULL, 
	external_key TEXT, 
	submitted_snapshot JSONB, 
	receipt_key TEXT, 
	invoice_id UUID, 
	CONSTRAINT pk_invoice_issue_request PRIMARY KEY (id), 
	CONSTRAINT ck_amounts CHECK (amount >= 0 AND tax >= 0 AND total = amount + tax AND total < 'Infinity'::numeric), 
	CONSTRAINT ck_status_draft CHECK (status IN ('draft','queued','issuing','unknown','failed','issued','cancelled')), 
	CONSTRAINT ck_mode_simulation CHECK (mode IN ('simulation','production')), 
	CONSTRAINT fk_invoice_issue_request_tenant_id_invoice FOREIGN KEY(tenant_id, invoice_id) REFERENCES invoice (tenant_id, id), 
	CONSTRAINT uq_invoice_issue_request_tenant_id_external_key UNIQUE (tenant_id, external_key), 
	CONSTRAINT uq_invoice_issue_request_tenant_id_invoice_id UNIQUE (tenant_id, invoice_id), 
	CONSTRAINT ck_issued_invoice CHECK (status <> 'issued' OR invoice_id IS NOT NULL), 
	CONSTRAINT fk_invoice_issue_request_tenant_id_tenant FOREIGN KEY(tenant_id) REFERENCES tenant (id), 
	CONSTRAINT uq_invoice_issue_request_tenant_id_id UNIQUE (tenant_id, id), 
	CONSTRAINT ck_version CHECK (version > 0)
)


-- statement-break
CREATE INDEX ix_invoice_issue_request_tenant ON invoice_issue_request (tenant_id)
-- statement-break
ALTER TABLE "invoice_issue_request" ENABLE ROW LEVEL SECURITY
-- statement-break
ALTER TABLE "invoice_issue_request" FORCE ROW LEVEL SECURITY
-- statement-break
CREATE POLICY tenant_isolation ON "invoice_issue_request"
            USING (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
            WITH CHECK (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
-- statement-break

CREATE TABLE invoice_line (
	id UUID DEFAULT gen_random_uuid() NOT NULL, 
	tenant_id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	created_by UUID, 
	version INTEGER DEFAULT '1' NOT NULL, 
	invoice_id UUID NOT NULL, 
	line_no INTEGER NOT NULL, 
	description TEXT NOT NULL, 
	quantity NUMERIC(20, 6) NOT NULL, 
	unit_price NUMERIC(20, 6) NOT NULL, 
	tax_rate_id UUID, 
	rate_snapshot NUMERIC(9, 6) NOT NULL, 
	amount NUMERIC(20, 2) NOT NULL, 
	tax NUMERIC(20, 2) NOT NULL, 
	total NUMERIC(20, 2) NOT NULL, 
	CONSTRAINT pk_invoice_line PRIMARY KEY (id), 
	CONSTRAINT fk_invoice_line_tenant_id_invoice FOREIGN KEY(tenant_id, invoice_id) REFERENCES invoice (tenant_id, id), 
	CONSTRAINT fk_invoice_line_tenant_id_tax_rate FOREIGN KEY(tenant_id, tax_rate_id) REFERENCES tax_rate (tenant_id, id), 
	CONSTRAINT ck_amounts CHECK (amount >= 0 AND tax >= 0 AND total = amount + tax AND total < 'Infinity'::numeric), 
	CONSTRAINT ck_line_values CHECK (quantity > 0 AND quantity < 'Infinity'::numeric AND unit_price >= 0 AND unit_price < 'Infinity'::numeric AND rate_snapshot BETWEEN 0 AND 1), 
	CONSTRAINT uq_invoice_line_tenant_id_invoice_id_line_no UNIQUE (tenant_id, invoice_id, line_no), 
	CONSTRAINT fk_invoice_line_tenant_id_tenant FOREIGN KEY(tenant_id) REFERENCES tenant (id), 
	CONSTRAINT uq_invoice_line_tenant_id_id UNIQUE (tenant_id, id), 
	CONSTRAINT ck_version CHECK (version > 0)
)


-- statement-break
CREATE INDEX ix_invoice_line_tenant ON invoice_line (tenant_id)
-- statement-break
ALTER TABLE "invoice_line" ENABLE ROW LEVEL SECURITY
-- statement-break
ALTER TABLE "invoice_line" FORCE ROW LEVEL SECURITY
-- statement-break
CREATE POLICY tenant_isolation ON "invoice_line"
            USING (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
            WITH CHECK (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
-- statement-break

CREATE TABLE invoice_verification (
	id UUID DEFAULT gen_random_uuid() NOT NULL, 
	tenant_id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	created_by UUID, 
	version INTEGER DEFAULT '1' NOT NULL, 
	invoice_id UUID NOT NULL, 
	operation_key TEXT NOT NULL, 
	result JSONB NOT NULL, 
	mode TEXT DEFAULT 'simulation' NOT NULL, 
	CONSTRAINT pk_invoice_verification PRIMARY KEY (id), 
	CONSTRAINT fk_invoice_verification_tenant_id_invoice FOREIGN KEY(tenant_id, invoice_id) REFERENCES invoice (tenant_id, id), 
	CONSTRAINT ck_mode_simulation CHECK (mode IN ('simulation','production')), 
	CONSTRAINT uq_invoice_verification_tenant_id_operation_key UNIQUE (tenant_id, operation_key), 
	CONSTRAINT fk_invoice_verification_tenant_id_tenant FOREIGN KEY(tenant_id) REFERENCES tenant (id), 
	CONSTRAINT uq_invoice_verification_tenant_id_id UNIQUE (tenant_id, id), 
	CONSTRAINT ck_version CHECK (version > 0)
)


-- statement-break
CREATE INDEX ix_invoice_verification_tenant ON invoice_verification (tenant_id)
-- statement-break
ALTER TABLE "invoice_verification" ENABLE ROW LEVEL SECURITY
-- statement-break
ALTER TABLE "invoice_verification" FORCE ROW LEVEL SECURITY
-- statement-break
CREATE POLICY tenant_isolation ON "invoice_verification"
            USING (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
            WITH CHECK (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
-- statement-break

CREATE TABLE payment_record (
	id UUID DEFAULT gen_random_uuid() NOT NULL, 
	tenant_id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	created_by UUID, 
	version INTEGER DEFAULT '1' NOT NULL, 
	reimbursement_id UUID NOT NULL, 
	reference TEXT NOT NULL, 
	amount NUMERIC(20, 2) NOT NULL, 
	paid_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	evidence_key TEXT NOT NULL, 
	CONSTRAINT pk_payment_record PRIMARY KEY (id), 
	CONSTRAINT fk_payment_record_tenant_id_reimbursement FOREIGN KEY(tenant_id, reimbursement_id) REFERENCES reimbursement (tenant_id, id), 
	CONSTRAINT ck_payment_amount CHECK (amount > 0 AND amount < 'Infinity'::numeric), 
	CONSTRAINT uq_payment_record_tenant_id_reference UNIQUE (tenant_id, reference), 
	CONSTRAINT fk_payment_record_tenant_id_tenant FOREIGN KEY(tenant_id) REFERENCES tenant (id), 
	CONSTRAINT uq_payment_record_tenant_id_id UNIQUE (tenant_id, id), 
	CONSTRAINT ck_version CHECK (version > 0)
)


-- statement-break
CREATE INDEX ix_payment_record_tenant ON payment_record (tenant_id)
-- statement-break
ALTER TABLE "payment_record" ENABLE ROW LEVEL SECURITY
-- statement-break
ALTER TABLE "payment_record" FORCE ROW LEVEL SECURITY
-- statement-break
CREATE POLICY tenant_isolation ON "payment_record"
            USING (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
            WITH CHECK (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
-- statement-break

CREATE TABLE posting_source (
	id UUID DEFAULT gen_random_uuid() NOT NULL, 
	tenant_id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	created_by UUID, 
	version INTEGER DEFAULT '1' NOT NULL, 
	invoice_id UUID, 
	reimbursement_id UUID, 
	CONSTRAINT pk_posting_source PRIMARY KEY (id), 
	CONSTRAINT fk_posting_source_tenant_id_invoice FOREIGN KEY(tenant_id, invoice_id) REFERENCES invoice (tenant_id, id), 
	CONSTRAINT fk_posting_source_tenant_id_reimbursement FOREIGN KEY(tenant_id, reimbursement_id) REFERENCES reimbursement (tenant_id, id), 
	CONSTRAINT ck_source_one_origin CHECK (num_nonnulls(invoice_id,reimbursement_id) = 1), 
	CONSTRAINT uq_posting_source_tenant_id_invoice_id UNIQUE (tenant_id, invoice_id), 
	CONSTRAINT uq_posting_source_tenant_id_reimbursement_id UNIQUE (tenant_id, reimbursement_id), 
	CONSTRAINT fk_posting_source_tenant_id_tenant FOREIGN KEY(tenant_id) REFERENCES tenant (id), 
	CONSTRAINT uq_posting_source_tenant_id_id UNIQUE (tenant_id, id), 
	CONSTRAINT ck_version CHECK (version > 0)
)


-- statement-break
CREATE INDEX ix_posting_source_tenant ON posting_source (tenant_id)
-- statement-break
ALTER TABLE "posting_source" ENABLE ROW LEVEL SECURITY
-- statement-break
ALTER TABLE "posting_source" FORCE ROW LEVEL SECURITY
-- statement-break
CREATE POLICY tenant_isolation ON "posting_source"
            USING (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
            WITH CHECK (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
-- statement-break

CREATE TABLE reimbursement_invoice (
	id UUID DEFAULT gen_random_uuid() NOT NULL, 
	tenant_id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	created_by UUID, 
	version INTEGER DEFAULT '1' NOT NULL, 
	reimbursement_id UUID NOT NULL, 
	invoice_id UUID NOT NULL, 
	CONSTRAINT pk_reimbursement_invoice PRIMARY KEY (id), 
	CONSTRAINT fk_reimbursement_invoice_tenant_id_reimbursement FOREIGN KEY(tenant_id, reimbursement_id) REFERENCES reimbursement (tenant_id, id), 
	CONSTRAINT fk_reimbursement_invoice_tenant_id_invoice FOREIGN KEY(tenant_id, invoice_id) REFERENCES invoice (tenant_id, id), 
	CONSTRAINT uq_reimbursement_invoice_tenant_id_reimbursement_id_invoice_id UNIQUE (tenant_id, reimbursement_id, invoice_id), 
	CONSTRAINT fk_reimbursement_invoice_tenant_id_tenant FOREIGN KEY(tenant_id) REFERENCES tenant (id), 
	CONSTRAINT uq_reimbursement_invoice_tenant_id_id UNIQUE (tenant_id, id), 
	CONSTRAINT ck_version CHECK (version > 0)
)


-- statement-break
CREATE INDEX ix_reimbursement_invoice_tenant ON reimbursement_invoice (tenant_id)
-- statement-break
ALTER TABLE "reimbursement_invoice" ENABLE ROW LEVEL SECURITY
-- statement-break
ALTER TABLE "reimbursement_invoice" FORCE ROW LEVEL SECURITY
-- statement-break
CREATE POLICY tenant_isolation ON "reimbursement_invoice"
            USING (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
            WITH CHECK (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
-- statement-break

CREATE TABLE reimbursement_line (
	id UUID DEFAULT gen_random_uuid() NOT NULL, 
	tenant_id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	created_by UUID, 
	version INTEGER DEFAULT '1' NOT NULL, 
	reimbursement_id UUID NOT NULL, 
	line_no INTEGER NOT NULL, 
	category TEXT NOT NULL, 
	description TEXT NOT NULL, 
	amount NUMERIC(20, 2) NOT NULL, 
	CONSTRAINT pk_reimbursement_line PRIMARY KEY (id), 
	CONSTRAINT fk_reimbursement_line_tenant_id_reimbursement FOREIGN KEY(tenant_id, reimbursement_id) REFERENCES reimbursement (tenant_id, id), 
	CONSTRAINT ck_expense_amount CHECK (amount > 0 AND amount < 'Infinity'::numeric), 
	CONSTRAINT uq_reimbursement_line_tenant_id_reimbursement_id_line_no UNIQUE (tenant_id, reimbursement_id, line_no), 
	CONSTRAINT fk_reimbursement_line_tenant_id_tenant FOREIGN KEY(tenant_id) REFERENCES tenant (id), 
	CONSTRAINT uq_reimbursement_line_tenant_id_id UNIQUE (tenant_id, id), 
	CONSTRAINT ck_version CHECK (version > 0)
)


-- statement-break
CREATE INDEX ix_reimbursement_line_tenant ON reimbursement_line (tenant_id)
-- statement-break
ALTER TABLE "reimbursement_line" ENABLE ROW LEVEL SECURITY
-- statement-break
ALTER TABLE "reimbursement_line" FORCE ROW LEVEL SECURITY
-- statement-break
CREATE POLICY tenant_isolation ON "reimbursement_line"
            USING (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
            WITH CHECK (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
-- statement-break

CREATE TABLE voucher (
	id UUID DEFAULT gen_random_uuid() NOT NULL, 
	tenant_id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	created_by UUID, 
	version INTEGER DEFAULT '1' NOT NULL, 
	period_id UUID NOT NULL, 
	number BIGINT NOT NULL, 
	summary TEXT NOT NULL, 
	debit_total NUMERIC(20, 2) NOT NULL, 
	credit_total NUMERIC(20, 2) NOT NULL, 
	CONSTRAINT pk_voucher PRIMARY KEY (id), 
	CONSTRAINT fk_voucher_tenant_id_accounting_period FOREIGN KEY(tenant_id, period_id) REFERENCES accounting_period (tenant_id, id), 
	CONSTRAINT ck_voucher_balance CHECK (debit_total > 0 AND debit_total < 'Infinity'::numeric AND debit_total = credit_total), 
	CONSTRAINT uq_voucher_tenant_id_period_id_number UNIQUE (tenant_id, period_id, number), 
	CONSTRAINT fk_voucher_tenant_id_tenant FOREIGN KEY(tenant_id) REFERENCES tenant (id), 
	CONSTRAINT uq_voucher_tenant_id_id UNIQUE (tenant_id, id), 
	CONSTRAINT ck_version CHECK (version > 0)
)


-- statement-break
CREATE INDEX ix_voucher_tenant ON voucher (tenant_id)
-- statement-break
ALTER TABLE "voucher" ENABLE ROW LEVEL SECURITY
-- statement-break
ALTER TABLE "voucher" FORCE ROW LEVEL SECURITY
-- statement-break
CREATE POLICY tenant_isolation ON "voucher"
            USING (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
            WITH CHECK (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
-- statement-break

CREATE TABLE invoice_issue_line (
	id UUID DEFAULT gen_random_uuid() NOT NULL, 
	tenant_id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	created_by UUID, 
	version INTEGER DEFAULT '1' NOT NULL, 
	request_id UUID NOT NULL, 
	line_no INTEGER NOT NULL, 
	description TEXT NOT NULL, 
	quantity NUMERIC(20, 6) NOT NULL, 
	unit_price NUMERIC(20, 6) NOT NULL, 
	tax_rate_id UUID, 
	rate_snapshot NUMERIC(9, 6) NOT NULL, 
	amount NUMERIC(20, 2) NOT NULL, 
	tax NUMERIC(20, 2) NOT NULL, 
	total NUMERIC(20, 2) NOT NULL, 
	CONSTRAINT pk_invoice_issue_line PRIMARY KEY (id), 
	CONSTRAINT fk_invoice_issue_line_tenant_id_invoice_issue_request FOREIGN KEY(tenant_id, request_id) REFERENCES invoice_issue_request (tenant_id, id), 
	CONSTRAINT fk_invoice_issue_line_tenant_id_tax_rate FOREIGN KEY(tenant_id, tax_rate_id) REFERENCES tax_rate (tenant_id, id), 
	CONSTRAINT ck_amounts CHECK (amount >= 0 AND tax >= 0 AND total = amount + tax AND total < 'Infinity'::numeric), 
	CONSTRAINT ck_line_values CHECK (quantity > 0 AND quantity < 'Infinity'::numeric AND unit_price >= 0 AND unit_price < 'Infinity'::numeric AND rate_snapshot BETWEEN 0 AND 1), 
	CONSTRAINT uq_invoice_issue_line_tenant_id_request_id_line_no UNIQUE (tenant_id, request_id, line_no), 
	CONSTRAINT fk_invoice_issue_line_tenant_id_tenant FOREIGN KEY(tenant_id) REFERENCES tenant (id), 
	CONSTRAINT uq_invoice_issue_line_tenant_id_id UNIQUE (tenant_id, id), 
	CONSTRAINT ck_version CHECK (version > 0)
)


-- statement-break
CREATE INDEX ix_invoice_issue_line_tenant ON invoice_issue_line (tenant_id)
-- statement-break
ALTER TABLE "invoice_issue_line" ENABLE ROW LEVEL SECURITY
-- statement-break
ALTER TABLE "invoice_issue_line" FORCE ROW LEVEL SECURITY
-- statement-break
CREATE POLICY tenant_isolation ON "invoice_issue_line"
            USING (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
            WITH CHECK (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
-- statement-break

CREATE TABLE posting_source_invoice (
	id UUID DEFAULT gen_random_uuid() NOT NULL, 
	tenant_id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	created_by UUID, 
	version INTEGER DEFAULT '1' NOT NULL, 
	source_id UUID NOT NULL, 
	invoice_id UUID NOT NULL, 
	CONSTRAINT pk_posting_source_invoice PRIMARY KEY (id), 
	CONSTRAINT fk_posting_source_invoice_tenant_id_posting_source FOREIGN KEY(tenant_id, source_id) REFERENCES posting_source (tenant_id, id), 
	CONSTRAINT fk_posting_source_invoice_tenant_id_invoice FOREIGN KEY(tenant_id, invoice_id) REFERENCES invoice (tenant_id, id), 
	CONSTRAINT uq_posting_source_invoice_tenant_id_invoice_id UNIQUE (tenant_id, invoice_id), 
	CONSTRAINT fk_posting_source_invoice_tenant_id_tenant FOREIGN KEY(tenant_id) REFERENCES tenant (id), 
	CONSTRAINT uq_posting_source_invoice_tenant_id_id UNIQUE (tenant_id, id), 
	CONSTRAINT ck_version CHECK (version > 0)
)


-- statement-break
CREATE INDEX ix_posting_source_invoice_tenant ON posting_source_invoice (tenant_id)
-- statement-break
ALTER TABLE "posting_source_invoice" ENABLE ROW LEVEL SECURITY
-- statement-break
ALTER TABLE "posting_source_invoice" FORCE ROW LEVEL SECURITY
-- statement-break
CREATE POLICY tenant_isolation ON "posting_source_invoice"
            USING (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
            WITH CHECK (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
-- statement-break

CREATE TABLE posting_suggestion (
	id UUID DEFAULT gen_random_uuid() NOT NULL, 
	tenant_id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	created_by UUID, 
	version INTEGER DEFAULT '1' NOT NULL, 
	source_id UUID NOT NULL, 
	source_version INTEGER NOT NULL, 
	rule_version INTEGER NOT NULL, 
	entries JSONB NOT NULL, 
	signals JSONB NOT NULL, 
	confidence NUMERIC(20, 18) NOT NULL, 
	need_review BOOLEAN NOT NULL, 
	status TEXT DEFAULT 'active' NOT NULL, 
	CONSTRAINT pk_posting_suggestion PRIMARY KEY (id), 
	CONSTRAINT fk_posting_suggestion_tenant_id_posting_source FOREIGN KEY(tenant_id, source_id) REFERENCES posting_source (tenant_id, id), 
	CONSTRAINT ck_status_active CHECK (status IN ('active','superseded','accepted','rejected')), 
	CONSTRAINT ck_confidence CHECK (confidence BETWEEN 0 AND 1), 
	CONSTRAINT fk_posting_suggestion_tenant_id_tenant FOREIGN KEY(tenant_id) REFERENCES tenant (id), 
	CONSTRAINT uq_posting_suggestion_tenant_id_id UNIQUE (tenant_id, id), 
	CONSTRAINT ck_version CHECK (version > 0)
)


-- statement-break
CREATE INDEX ix_posting_suggestion_tenant ON posting_suggestion (tenant_id)
-- statement-break
ALTER TABLE "posting_suggestion" ENABLE ROW LEVEL SECURITY
-- statement-break
ALTER TABLE "posting_suggestion" FORCE ROW LEVEL SECURITY
-- statement-break
CREATE POLICY tenant_isolation ON "posting_suggestion"
            USING (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
            WITH CHECK (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
-- statement-break

CREATE TABLE voucher_line (
	id UUID DEFAULT gen_random_uuid() NOT NULL, 
	tenant_id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	created_by UUID, 
	version INTEGER DEFAULT '1' NOT NULL, 
	voucher_id UUID NOT NULL, 
	account_id UUID NOT NULL, 
	line_no INTEGER NOT NULL, 
	debit NUMERIC(20, 2) NOT NULL, 
	credit NUMERIC(20, 2) NOT NULL, 
	auxiliary JSONB NOT NULL, 
	CONSTRAINT pk_voucher_line PRIMARY KEY (id), 
	CONSTRAINT fk_voucher_line_tenant_id_voucher FOREIGN KEY(tenant_id, voucher_id) REFERENCES voucher (tenant_id, id), 
	CONSTRAINT fk_voucher_line_tenant_id_account FOREIGN KEY(tenant_id, account_id) REFERENCES account (tenant_id, id), 
	CONSTRAINT ck_entry_side CHECK (((debit > 0 AND credit = 0) OR (credit > 0 AND debit = 0)) AND debit < 'Infinity'::numeric AND credit < 'Infinity'::numeric), 
	CONSTRAINT uq_voucher_line_tenant_id_voucher_id_line_no UNIQUE (tenant_id, voucher_id, line_no), 
	CONSTRAINT fk_voucher_line_tenant_id_tenant FOREIGN KEY(tenant_id) REFERENCES tenant (id), 
	CONSTRAINT uq_voucher_line_tenant_id_id UNIQUE (tenant_id, id), 
	CONSTRAINT ck_version CHECK (version > 0)
)


-- statement-break
CREATE INDEX ix_voucher_line_tenant ON voucher_line (tenant_id)
-- statement-break
ALTER TABLE "voucher_line" ENABLE ROW LEVEL SECURITY
-- statement-break
ALTER TABLE "voucher_line" FORCE ROW LEVEL SECURITY
-- statement-break
CREATE POLICY tenant_isolation ON "voucher_line"
            USING (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
            WITH CHECK (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
-- statement-break

CREATE TABLE voucher_source (
	id UUID DEFAULT gen_random_uuid() NOT NULL, 
	tenant_id UUID NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
	created_by UUID, 
	version INTEGER DEFAULT '1' NOT NULL, 
	voucher_id UUID NOT NULL, 
	source_id UUID NOT NULL, 
	CONSTRAINT pk_voucher_source PRIMARY KEY (id), 
	CONSTRAINT fk_voucher_source_tenant_id_voucher FOREIGN KEY(tenant_id, voucher_id) REFERENCES voucher (tenant_id, id), 
	CONSTRAINT fk_voucher_source_tenant_id_posting_source FOREIGN KEY(tenant_id, source_id) REFERENCES posting_source (tenant_id, id), 
	CONSTRAINT uq_voucher_source_tenant_id_source_id UNIQUE (tenant_id, source_id), 
	CONSTRAINT fk_voucher_source_tenant_id_tenant FOREIGN KEY(tenant_id) REFERENCES tenant (id), 
	CONSTRAINT uq_voucher_source_tenant_id_id UNIQUE (tenant_id, id), 
	CONSTRAINT ck_version CHECK (version > 0)
)


-- statement-break
CREATE INDEX ix_voucher_source_tenant ON voucher_source (tenant_id)
-- statement-break
ALTER TABLE "voucher_source" ENABLE ROW LEVEL SECURITY
-- statement-break
ALTER TABLE "voucher_source" FORCE ROW LEVEL SECURITY
-- statement-break
CREATE POLICY tenant_isolation ON "voucher_source"
            USING (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
            WITH CHECK (tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid)
-- statement-break
CREATE EXTENSION IF NOT EXISTS btree_gist
-- statement-break
ALTER TABLE tax_rate ADD CONSTRAINT tax_rate_no_overlap EXCLUDE USING gist (tenant_id WITH =, scope WITH =, daterange(valid_from, valid_to, '[)') WITH &&)
-- statement-break
CREATE FUNCTION deny_audit_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN RAISE EXCEPTION 'audit records are append only'; END $$
-- statement-break
CREATE TRIGGER audit_append_only BEFORE UPDATE OR DELETE ON audit_log FOR EACH ROW EXECUTE FUNCTION deny_audit_mutation()
-- statement-break
CREATE FUNCTION check_voucher_balance() RETURNS trigger LANGUAGE plpgsql AS $$
    DECLARE target uuid; owner_tenant uuid; expected numeric; d numeric; c numeric; n integer;
    BEGIN
      IF TG_TABLE_NAME = 'voucher' THEN target := NEW.id; owner_tenant := NEW.tenant_id;
      ELSE target := COALESCE(NEW.voucher_id, OLD.voucher_id); owner_tenant := COALESCE(NEW.tenant_id, OLD.tenant_id); END IF;
      SELECT debit_total INTO expected FROM voucher WHERE id=target AND tenant_id=owner_tenant FOR UPDATE;
      IF NOT FOUND THEN RETURN NULL; END IF;
      SELECT coalesce(sum(debit),0), coalesce(sum(credit),0), count(*) INTO d,c,n FROM voucher_line WHERE voucher_id=target AND tenant_id=owner_tenant;
      IF n < 2 OR d <> c OR d <> expected THEN RAISE EXCEPTION 'voucher lines do not balance with header'; END IF;
      RETURN NULL;
    END $$
-- statement-break
CREATE CONSTRAINT TRIGGER voucher_balance AFTER INSERT OR UPDATE ON voucher DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION check_voucher_balance()
-- statement-break
CREATE CONSTRAINT TRIGGER voucher_line_balance AFTER INSERT OR UPDATE OR DELETE ON voucher_line DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION check_voucher_balance()
-- statement-break
CREATE FUNCTION deny_line_reparent() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN IF NEW.voucher_id <> OLD.voucher_id OR NEW.tenant_id <> OLD.tenant_id THEN RAISE EXCEPTION 'cannot reparent voucher line'; END IF; RETURN NEW; END $$
-- statement-break
CREATE TRIGGER voucher_line_no_reparent BEFORE UPDATE ON voucher_line FOR EACH ROW EXECUTE FUNCTION deny_line_reparent()