"""Initial accounting database; SQL snapshot is immutable."""
from pathlib import Path
from alembic import op

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None

def upgrade():
    sql = (Path(__file__).parent / "0001_schema.sql").read_text(encoding="utf-8")
    for statement in sql.split("-- statement-break"):
        if statement.strip():
            op.execute(statement.strip())

def downgrade():
    raise RuntimeError("Initial financial schema cannot be automatically dropped; restore a reviewed backup instead.")
