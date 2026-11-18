# 开票报销入账数据库

Python 3.12、FastAPI、SQLAlchemy 2.0 async、Alembic、PostgreSQL 16。已实现 T01 服务基础和健康检查，审批、付款、开票业务接口待后续任务实现。

## 启动后端

在 backend 目录运行 `uv sync`，然后运行 `uv run uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload`。

- 接口文档：http://127.0.0.1:8000/docs
- 存活检查：`GET /api/v1/health/live`
- 就绪检查：`GET /api/v1/health/ready`，验证 PostgreSQL 16、运行角色及 RLS 基础结构；数据库不可用返回 503，存活检查仍返回 200。
- 开发环境默认从 `.local/database.json` 读取 taxhub_app 连接；设置 `TAXHUB_DATABASE_URL` 可覆盖。测试和生产环境必须显式提供连接，不能回退本地凭据。
- 应用不会自动迁移、建表或写入样例数据。API 尚无登录和业务接口，现有前端继续使用演示契约。
- `uv run python -m scripts.export_openapi` 导出 `backend/openapi.json`；当前只有健康接口，暂不替换前端演示 OpenAPI。
- 错误采用 `application/problem+json` 并带 `X-Trace-ID`，不返回原始输入、连接凭据或异常堆栈。

测试：`uv run pytest tests/test_api.py -q`。全套数据库测试还需按下文配置 TEST_DATABASE_URL。

## 本地环境

当前使用现有 Docker 容器 `text2sqlbi-postgres`，数据库 `taxhub`，连接 `127.0.0.1:54320`。数据库所有者 `taxhub_owner` 仅供迁移；运行账号 `taxhub_app` 用于业务访问。两个账号均无超级用户和 RLS 绕过权限。该实例已有其他业务库，不能对整实例执行重置或清理。

连接地址和随机生成的凭据保存在忽略的 `.local/database.json`；不提交或复制到文档。Docker 停止后可以运行 `docker start text2sqlbi-postgres`。不要删除数据卷。旧容器 `taxhub-postgres16` 及其 `taxhub-pg16-data` 卷保留为迁移前副本，后续开发以 54320 为准。

```powershell
cd backend
uv sync
$config = Get-Content .local/database.json -Raw | ConvertFrom-Json
$env:DATABASE_URL = "postgresql+asyncpg://taxhub_owner:$($config.password)@$($config.host):$($config.port)/taxhub"
uv run alembic upgrade head
```

应用必须使用 `taxhub_app` 及 `app_password` 连接，验证主体授权后使用 `tenant_transaction` 设置事务局部上下文。无上下文时 RLS 查询返回空，写入拒绝。repository 同时显式过滤 tenant_id。

## 模型与迁移

`app/models.py` 定义 27 张表并采用 SQLAlchemy imperative ORM 映射。`migrations/versions/0001_schema.sql` 是冻结初始结构快照，包含 RLS、税率有效期排斥约束、审计不可修改触发器及延迟凭证平衡约束。后续变更新建迁移，不重新生成已发布快照。

金额使用 NUMERIC；票据与开票表头金额自洽，凭证表头和分录在事务结束时平衡。外键包含 tenant_id，发票身份、有效报销占用、统一票据入账来源和凭证来源具有唯一约束。

业务状态枚举只限制可存值。审批权限、状态合法迁移、单据行合计、付款累计、期间锁竞争、置信度计算、原票与报销占用之间的跨流程互斥，仍需后续服务在事务中实现，不能宣称数据库层已交付完整业务流程。税率表无生产税率种子。申报台账和税务档案留待 T12。

运行账号不授予 tenant、app_user 控制表访问；认证模块后续通过专用受限能力访问控制数据，不能直接向普通业务账号开放密码哈希表。审计表需保留追加能力；生产部署另设非超级用户迁移角色及备份策略。

## 验证

仅对独立的 `taxhub_test` 数据库运行测试。测试夹具使用管理员建立合成数据，再通过 `SET LOCAL ROLE taxhub_app` 验证 RLS；不能用普通应用连接或无绕过权限的迁移账号代替夹具管理员。每项测试回滚合成数据。通过环境变量传入测试专用管理员连接，不在代码内保存共享实例的管理员密码。

```powershell
# 先设置 TEST_DATABASE_URL，目标必须为 127.0.0.1:54320/taxhub_test。
uv run pytest -q
```

初始迁移拒绝自动降级删除财务表；需要回退时使用经过确认的备份恢复。数据库地址、角色和测试库约定仅针对本地开发。
