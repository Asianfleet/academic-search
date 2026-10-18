# 合并上游 v1.4 实施计划

> **给执行者：** 本计划由主代理在本会话内按步骤执行（inline execution）。步骤用 `- [ ]` 复选标记跟踪；完成后勾选并补一行实施说明。

**目标：** 把上游 `ustc-ai4science/academic-search` 的 v1.4（6 个提交，2026-09-05）合并进本 fork 的 `feat/usability_improve` 成果，同时保留本 fork 独有的价值：任务产出协议、S2 速率纪律、并行分治权限模型、API 凭据检查。

**背景事实：**

| 项 | 值 |
|---|---|
| 分叉点（merge-base） | `3ae6844` (2026-07-05) |
| 本 fork 超前 | 12 个提交（8 已推送 / 4 未推送） |
| 上游超前 | 6 个提交 = v1.4 |
| 冲突文件 | 7 个（`git merge-tree` 实算） |

上游 v1.4 的两个方向性变化决定了本次合并的重心：

1. `SKILL.md` 从 407 行瘦身为 59 行的“路由器”，细节下沉到 `references/`（新增 `browser-workflow.md`、`full-text-workflow.md`、`academic-records.md`，扩写 `metadata-schema.md`、`cdp-api.md`）。
2. `scripts/check-deps.sh` 换架构：删除“直连日常 Chrome + `chrome://inspect` 授权 + 自行拉起 cdp-proxy”，改为 `Node 版本门 + exec node ensure-proxy.mjs`，新增 `--api-only`、专用 Chrome profile，以及 `ensure-proxy.mjs` / `proxy-owner.mjs` / `browser-runtime.mjs`。上游代码中已无 `chrome://inspect`。

## 决策记录

| 编号 | 决策 | 结论 |
|---|---|---|
| D1 | `api-cookbook` 走向 | **方案 A**：回到上游单文件 `references/api-cookbook.md`，并入本 fork 独有内容；删除 `references/api-cookbook/` 目录拆分 |
| D2 | “无条件遵守”协议放哪 | **折中**：`SKILL.md` 保留 4–6 行硬要求 + 强制指路，细则进 `references/task-protocol.md` |
| D3 | README clone URL | 不跟上游，改用本 fork 地址 `Asianfleet/academic-search` |
| D4 | 版本号 | fork 自有版本：`1.4.0+asianfleet.1` |
| D5 | `check-deps.ps1` | **不再维护**，删除 `scripts/check-deps.ps1` 与 `scripts/check-deps-self-test.ps1`；Windows 一律直接使用 Node（`node scripts/ensure-proxy.mjs`） |
| D6 | 本 fork 附加文档 | 原样保留（`docs/superpowers/plans/2026-05-08-check-deps-powershell.md`、`docs/multidisciplinary-improvement-analysis.md`） |

## 冲突清单与逐文件策略

| 文件 | 冲突 | 策略 |
|---|---|---|
| `README.md` / `README.en.md` | content ×5 / ×4 | 以上游版为基底（v1.4 结构、3456→3457 迁移说明），加回 Windows 说明但**改为 Node 直连**；clone URL 换 `Asianfleet` |
| `project-introduction.md` | content ×1 | 取上游 + 按 D5/D1 调整脚本树与 references 树 |
| `SKILL.md` | content ×6（含巨型块） | 采用上游 59 行骨架，按下方“移植清单”重植本 fork 内容 |
| `references/api-cookbook.md` | modify/delete | 取上游文件，并入本 fork 独有内容；删除 `references/api-cookbook/*.md` |
| `references/cdp-api.md` | content ×2 | 取上游重写版；本 fork 对该文件的 2 行改动作废（去掉 `check-deps.ps1` 提法） |
| `scripts/check-deps.sh` | content ×1 | 取上游 v1.4 版，把“API 凭据检查块”插到 `--api-only` 早退**之前** |

## SKILL.md 移植清单

| 本 fork 独有内容 | 落点 |
|---|---|
| 任务产出协议（`protocol.md` / `report.md` / `trace.md` / `manifest.json` + 中间产物分类登记） | 新建 `references/task-protocol.md`，`SKILL.md` 留硬要求摘要 + 指路 |
| 完成判定 | 并入上游「任务范围与完成标准」 |
| 执行前置检查（依赖清单、API Key 说明） | 并入上游「运行路径与站点经验」，**改写**为 v1.4 语义（无 `chrome://inspect`、支持 `--api-only`） |
| “绝不为方便只用单一平台”硬规则 | 并入上游「学科路由与来源」末尾 |
| 并行分治 + S2 权限模型（专属 S2 子 Agent，其余子 Agent 禁用 S2） | 新增小节加回 `SKILL.md`（执行纪律，不埋进 reference） |
| S2 速率守则（串行 + 每次 sleep 1.5–2s + 批量优先） | 与上游 `api-cookbook.md`「限流与请求预算」、`site-patterns/semanticscholar.org.md`「限流与故障」合并 |
| 子 Agent 任务目录路径必须显式给出、禁止写临时目录 | 并入 `references/task-protocol.md` + 并行分治节 |
| 引用数 / 命中数写入 `trace.md` | 并入 `references/task-protocol.md` |

**已知事实冲突（合并时必须统一）：**

- S2 无 Key 速率：上游写“约 100 req/5min”，本 fork 写“共享全局池”。按官方文档核对后统一措辞。
- 429 处理：本 fork“不要立刻重试”，上游“最多 2 次重试 / 30s 预算”。保留本 fork 的预防纪律（串行 + sleep + 批量优先）作为主策略，上游的预算作为有界恢复策略，二者在文档中显式分层。

## 执行步骤

### Task 1: 保存方案并备份分支

**Files:** 创建 `docs/superpowers/plans/2026-10-18-merge-upstream-v1.4.md`

- [ ] **Step 1:** 写入本计划文档。
- [ ] **Step 2:** 提交计划文档（中文文档，英文 commit message）。
- [ ] **Step 3:** 推送 4 个未推送提交到 `origin/feat/usability_improve` 作为备份。
- [ ] **Step 4:** 从 `feat/usability_improve` 创建合并分支 `merge/upstream-v1.4`。

### Task 2: 机械合并与冲突解决

- [ ] **Step 1:** `git merge upstream/main`，确认冲突文件与预判一致（7 个）。
- [ ] **Step 2:** 解决 `README.md` / `README.en.md` / `project-introduction.md`（以上游为基底，加回 Windows-Node 说明，URL 换 `Asianfleet`）。
- [ ] **Step 3:** 解决 `references/cdp-api.md`（取上游）。
- [ ] **Step 4:** 解决 `scripts/check-deps.sh`（取上游 + 凭据检查块前置到 `--api-only` 之前）。
- [ ] **Step 5:** 解决 `references/api-cookbook.md` 的 modify/delete：保留上游单文件，删除 `references/api-cookbook/` 目录。
- [ ] **Step 6:** `SKILL.md` 三路取舍，先落上游骨架，内容移植放到 Task 3。

### Task 3: 本 fork 内容移植

- [ ] **Step 1:** 新建 `references/task-protocol.md`（产出协议全文）。
- [ ] **Step 2:** 把本 fork 拆分文件中的 90 行独有内容并入上游 `references/api-cookbook.md`；删除与 `site-patterns/*` 重复的浏览器流程。
- [ ] **Step 3:** `SKILL.md` 植入：产出协议硬要求 + 指路、完成判定、前置检查、跨平台硬规则、并行分治 + S2 权限、S2 速度守则分层表述。
- [ ] **Step 4:** 统一 S2 速率与 429 表述（含事实冲突）。

### Task 4: D5 清理（删除 PowerShell 实现）

- [ ] **Step 1:** 删除 `scripts/check-deps.ps1`、`scripts/check-deps-self-test.ps1`。
- [ ] **Step 2:** 清除 `README*.md`、`SKILL.md`、`project-introduction.md`、`references/*` 中所有 `check-deps.ps1` 提法，改为 Node 直连说明。
- [ ] **Step 3:** 保留 `docs/superpowers/plans/2026-05-08-check-deps-powershell.md`（历史记录，按 D6）。

### Task 5: 一致性与版本号

- [ ] **Step 1:** 版本号改 `1.4.0+asianfleet.1`（`SKILL.md`、`agents/openai.yaml`）。
- [ ] **Step 2:** 全树扫描残留：`3456`、`chrome://inspect`、`api-cookbook/`、`check-deps.ps1`。
- [ ] **Step 3:** 核对 `SKILL.md` frontmatter 仍为单行 `description`。

### Task 6: 验证

- [ ] **Step 1:** `make test-offline`。
- [ ] **Step 2:** `make test`（如需要浏览器则记录实际执行范围）。
- [ ] **Step 3:** Windows 侧验证 `node scripts/ensure-proxy.mjs config` 与 `bash scripts/check-deps.sh --api-only` 等价路径。
- [ ] **Step 4:** 确认最终 diff 只含本次合并相关改动。

## 验证边界

浏览器相关的 `make test-release` 依赖本机 Chrome 与专用 profile；公开学术站点、登录态、反爬行为不在本地 fixture 范围内，必须按实际观测报告，不据 v1.4 文档推断。
