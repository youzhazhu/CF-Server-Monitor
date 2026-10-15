# v2.7.1 → v2.8.6 升级审查（2026-10-15）

结论：可以准备升级，但不能直接同步上线。本 PR 为 Draft；正式版优先，数据库历史主键迁移和生产配置核验是上线阻断项。没有访问、修改生产 D1，没有运行部署或更新 main。

## 精确版本

- Fork main：`9b46be4ec5cab39aefe54947cb9a74381cb70fc2`，2026-06-19，package 2.7.1。
- 正式版：`79679db2dbef281865c3d670839c79aaa1c0adc1`，2026-10-10；领先 Fork 354 次提交。本 PR 以此为基础，不跟随浮动 main。
- Beta1 发布点：`a5b6ca52e235d2ab52258eb3f04a5dd69d54d6ad`，2026-10-14。
- 当前上游 main：`fa60c60d7a5e872c874fe92822206b32d072c3af`；领先 Fork 358 次提交，Fork 独有提交 0。main 还包含 Beta1 之后的最新指标查询优化和西班牙语更新。
- GitHub Releases 和 tags 均为空；这里的“发布”指版本提交及 README，不能当作有签名的 Release/tag。

## 版本比较

| 项目 | v2.8.6 | v2.8.7 Beta1 发布点 |
| --- | --- | --- |
| 共同功能 | Go Agent 默认、Agent WSS、SMTP、月流量告警、Docker Agent 安装、前端 WSS 250ms 批量广播 | 保留左侧功能 |
| 离线检测 | 读取完整最新指标 | 只读最新时间戳；查询失败时跳过检测，降低误报风险 |
| 资源告警任务 | 每分钟强制刷新设置，关闭告警时重复清理状态 | 偶数分钟强制刷新，其他分钟使用缓存；避免重复 DELETE |
| 登录 | 非 ASCII 用户名存在已知 500 问题 | 包含 10/11 的登录修复 e5e9a02 |
| 选择 | 优先作为生产候选，但需解决本文阻断项 | 先在隔离环境验证；CPU/免费额度收益尚未实测 |

“正式版”不是无缺陷保证。若现有管理员用户名含中文，正式版上线前应在旧系统改用 ASCII 用户名，或单独审查、回移登录修复。本 PR 保留正式版业务代码，未混入 Beta 修复。

## 数据库：已复现直接升级的历史不可见问题

测试 `test/upgrade-v271-audit.test.js` 使用 Fork 提交中的实际建表 SQL（fixture 已附）、真实内存 SQLite 和 D1 风格适配器运行新版初始化/升级函数：

1. v2.7.1 历史 id 为普通 INTEGER PRIMARY KEY 自动编号；新版主键为 `history_partition_id * 10^13 + YYMMDDhhmmss`。
2. `initDatabase` / `ensureServerOptimization` 添加分区并分配编号，但不改写旧历史 id。
3. `updateDatabase` 为 servers、metrics_history 和 metrics_history_old 补字段，但不转换旧 id。
4. 旧行数量保持不变，新版 `getLatestMetrics` 却返回 null；新上报写入、读取成功。再次升级不重复添加字段。
5. 测试通过代表“已复现阻断项”，不代表迁移已完成。SQLite 测试不等于生产 D1 全量验证。

不得仅点击“升级数据库”就认为升级安全，也不要用“清空历史”当作保留历史的迁移。新版 updateDatabase 还会删除弃用表、字段及部分 settings keys，子步骤可返回 success:false 而顶层 success:true，必须逐项检查 results。README 的“不删除现有数据”不能作为完整回滚保证。

建议路径：

- 导出生产 D1 全量备份（含 settings、servers、两张历史表、索引），记录 Worker 当前部署版本和配置，在独立 D1/Worker 上演练恢复。
- 先盘点真实表结构、site_options、分区编号、孤儿行、无效时间戳、同一服务器同一秒重复样本、服务器数量（新版上限 900），以及每张历史表的时间跨度。
- 若需保留历史：专门设计、审查离线转换。保持服务器分区映射稳定，校验上述重复/时间戳问题，对两张历史表转换 id，核验行数与按服务器抽样结果。不要直接在生产运行无校验 UPDATE。
- 旧版本是按月轮换，新版代码实际按周日 UTC 00:00 轮换，尽管部分注释仍写“每月”。跨周查询按本周日边界选择旧表；迁移必须按新查询窗口验证两张表的数据归属，不能只转换 id。
- 暂停 Agent 写入和定时任务后，在副本完成初始化、字段升级、历史转换及设置保留核验，再验证新旧 Agent HTTP 上报、历史图表、管理员登录、通知和周轮换。
- 若不需要历史，可在确认并备份后选择新库/重新积累历史的路径；本 PR 未执行该选择。
- 回滚应恢复旧 Worker 和与其匹配的 D1 备份；仅回退代码不能恢复已删除字段/表，也不保证新主键数据兼容旧查询。切换期间新增上报数据需另行保留。

## Agent 兼容性

- v2.8.3 默认 Go Agent；Docker 入口是 Agent 安装方式，不代表 Worker/D1 后端迁到 Docker。
- 保留 Shell/PowerShell 安装文件和 HTTP `/update`，服务端仍接受传统 `{metrics: ...}` 请求；配置序列化保留旧 schema。Agent 配置测试通过，但没有连接真实旧 Agent 做端到端验证。
- WSS 要求 Go Agent v1.0.10+。先保持 HTTP，上报稳定后逐台升级 Agent，再启用 WSS/时段控制，监控 DO 时长与请求数。
- Worker URL、API_SECRET、server id 保持一致；不要同时运行新旧探针服务。新安装命令须检查自动更新开关，避免无意跟随 Agent latest。
- Shell/PowerShell 与旧 Agent 不保证具备磁盘 IO、新 Ping 节点、WSS 等完整新功能。

## Cloudflare / 工作流

- API 已确认有 push 权限。Actions runs 返回 total_count=0：只能证明无可见运行记录，不能排除 Cloudflare Git 集成或手工部署。没有读取密钥值或 Cloudflare 控制台配置。
- 原 Actions/main push 会部署；上游仍有该触发，并新增每日同步上游 main。为避免自动越过审核，本 PR 删除 sync.yml，将 Workers 与 Pages 部署改为仅 workflow_dispatch 且仅 main 可执行。没有 PR 部署触发器。
- 此保护仅控制 GitHub Actions。Cloudflare Workers Builds 的生产分支/预览分支设置须在控制台单独核验；本 PR 不修改外部集成。合并前必须确认 main 合并是否仍会由 Cloudflare 自动发布。
- Actions 生成的 Worker 名仍是 `server-monitor-pro`，仓库 wrangler.toml 是 `cf-server-monitor`；直接使用仓库配置部署可能指向不同 Worker。必须确认线上真实名称、账户、域名路由、D1 ID。
- 保留 `DB`、`ASSETS`、`METRICS_BROADCASTER` 绑定、DO 类 `MetricsBroadcaster`、migration tag `v1` 和 new_sqlite_classes；不要改名或重复重建现有 DO。
- 两个正式版配置的 cron 均为 `*/1 * * * *` 和 `0 * * * *`，与 scheduled 分支匹配。替换旧的月初/月8号通配 cron，清理控制台遗留触发器。
- 核对 CF_API_TOKEN、CF_ACCOUNT_ID、D1_DATABASE_ID、API_SECRET；保留 API_USER_NAME 回退设置；CORS_ALLOWED_ORIGINS 要包含实际外部前台来源。
- Actions 会重写 wrangler.toml，仓库文件里的 keep_vars=true 不会随之带入；盘点并显式保留线上额外 vars/secrets（尤其 DEBUG、CORS 等）。
- 上游工作流通过 GitHub 表达式将密钥插入 sed/shell 与 TOML，特殊字符可能导致转义问题；正式启用部署前应改为环境变量传入并用 TOML 安全序列化、API_SECRET secret 管理。不要通过日志输出配置验证密钥。
- lockfile 中 Wrangler 4.120.0；当前 Node 24.19.0 构建成功，Actions 使用 Node 22，package 的 >=18 声明不可当作所有锁定依赖的最低要求。

## 执行结果

- `npm ci --ignore-scripts`：成功，89 packages；未执行依赖生命周期脚本。
- `npm run build:frontend`：成功，81 modules。
- `npx wrangler deploy --dry-run --outdir .dry-run`：成功，Worker 424.97 KiB / gzip 91.14 KiB，DB/DO/assets 绑定可解析；无远程部署。
- `npm run test:all`：第一阶段 62 tests，61 pass / 1 fail；随后两阶段因 && 短路未运行，因此另行执行。
- 唯一失败 `frontend-live-socket.test.js`：vite-plugin-mkcert 调用 os.networkInterfaces 得到 uv_interface_addresses 错误（当前沙箱限制），不是断言失败；需在普通 CI 环境重跑，不能写作“全绿”。
- `npm run test:agent-config`：成功。
- `npm run test:history-query`：6/6，包括 Miniflare 的 D1-compatible SQLite 查询。
- `node --test test/upgrade-v271-audit.test.js`：1/1，旧历史不可见的特征测试。

上线前必须补充：生产数据库副本迁移/恢复演练、真实 Agent HTTP/WSS、通知/SMTP、域名/CORS、Cloudflare CPU/D1/DO 用量、Node 22 CI。当前结果不足以批准生产发布。

Beta1 补充验证：在精确提交 a5b6ca5 的独立 worktree 中，复用正式版锁定依赖（两版本 lockfile 相同），前端构建成功；新增 latest-timestamps 测试 6/6 通过。未运行完整 Beta 回归和生产负载基准，不能据此证明 Beta 更稳定。
