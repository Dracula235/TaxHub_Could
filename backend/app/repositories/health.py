from sqlalchemy import text

async def inspect_database(connection):
    return (await connection.execute(text("""
      SELECT current_setting('server_version_num')::int AS version,
        r.rolsuper OR r.rolbypassrls AS unsafe_role,
        EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                WHERE n.nspname='public' AND c.relkind='r' AND c.relowner=r.oid) AS owns_tables,
        (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
         WHERE n.nspname='public' AND c.relkind='r' AND c.relrowsecurity AND c.relforcerowsecurity) AS protected_tables
      FROM pg_roles r WHERE r.rolname=current_user
    """))).mappings().one()
