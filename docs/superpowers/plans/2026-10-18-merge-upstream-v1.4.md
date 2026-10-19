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
| D3 | README clone URL | 不跟上游，改用本 fork 地址 `Asianfleet/academic-search`；**已补全（用户确认，统一到 A 方案）**：README.md / README.en.md 的 clone 与 install 链接、stars / last-commit / repo badge、Star History 链接与图表，以及 `project-introduction.md` 的项目地址全部改为 `Asianfleet/academic-search`；`wechat-promo.md`（上游推广文案）**已按用户要求删除**，不再对外推广 |
| D4 | 版本号 | fork 自有版本：`1.4.0+asianfleet.1` |
| D5 | `check-deps.ps1` | ~~不再维护~~ **已修订（执行后用户要求恢复）**：保留 `scripts/check-deps.ps1`，按 v1.4 契约重写（参数门、curl 检查、凭据检查、Node 版本门、委托 `ensure-proxy.mjs`）；`scripts/check-deps-self-test.ps1` 暂未恢复（旧断言针对 v1.3 流程，需重写，待定） |
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
| `scripts/check-deps.ps1` | 无冲突（上游无此文件） | 按 v1.4 契约重写为 `check-deps.sh` 的等价实现（原版 v1.3 流程已废弃） |

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

- [x] **Step 1:** 写入本计划文档。
- [x] **Step 2:** 提交计划文档（commit `51b9d63`，中文文档、英文 commit message）。
- [x] **Step 3:** 推送未推送提交到 `origin/feat/usability_improve` 作为备份（`b5fe1ae..51b9d63`）。
- [x] **Step 4:** 创建合并分支 `merge/upstream-v1.4`。

### Task 2: 机械合并与冲突解决

- [x] **Step 1:** `git merge upstream/main`，冲突文件与预判一致（7 个）。
- [x] **Step 2:** 解决 `README.md` / `README.en.md` / `project-introduction.md`：以上游版为基底（`--theirs`），加回 Windows 直连 Node 说明，clone/install URL 换 `Asianfleet`，目录树补 `ensure-proxy.mjs` / `proxy-owner.mjs` / `browser-runtime.mjs` / `task-protocol.md`。
- [x] **Step 3:** 解决 `references/cdp-api.md`（取上游）。
- [x] **Step 4:** 解决 `scripts/check-deps.sh`（上游版 + 凭据检查块）。实测：`--api-only` 输出凭据后跳过浏览器准备并返回 0；假 Key 只输出变量名不输出值；非法参数返回 usage/1；端口被占用时按上游契约返回 `PROXY_PORT_IN_USE`（未启动 Chrome）。
- [x] **Step 5:** `references/api-cookbook.md` 冲突解决为上游单文件；删除 `references/api-cookbook/` 四个拆分文件。
- [x] **Step 6:** `SKILL.md` 以上游骨架重写，内容移植见 Task 3。
- [x] **Step 7（后续修订，D3 补全）:** 用户确认采用 A 方案（fork 自洽），仓库地址全量统一到 `Asianfleet/academic-search`：
  - `README.md`：stars badge、Star History 链接、Codex / Claude 两处 clone、"帮我安装这个 skill" 链接、底部 Star History 图表（3 个 `api.star-history.com` URL）。
  - `README.en.md`：stars / last-commit / repo 三个 badge 的 `href` 与 `img src`（clone 与 install 链接在合并时已是 `Asianfleet`）。
  - `project-introduction.md`：项目地址。
  - `wechat-promo.md`：**已删除**（用户决定不再保留上游公众号推广文案），同时从 `project-introduction.md` 的目录树中移除对应条目。

### Task 3: 本 fork 内容移植

- [x] **Step 1:** 新建 `references/task-protocol.md`（产出协议全文：任务目录、四件主产物、`trace.md` 列定义与禁记内容、中间产物分类、子 Agent 交接、完成判定）。
- [x] **Step 2:** 本 fork 独有内容并入 `references/api-cookbook.md`（S2 速率守则、ID 类型表、`/paper/search/bulk`、`/snippet/search`、作者 batch、字段映射与引用/被引结构），CNKI 的 `crossids` 代码表与字段映射并入 `references/site-patterns/cnki.net.md`；与 `site-patterns/*` 重复的 Google Scholar/CNKI 浏览器流程不再重复。
- [x] **Step 3:** `SKILL.md` 植入：任务产出协议（硬要求 + 指路）、完成判定、前置检查（`--api-only` 与 Windows PowerShell 等价脚本）、跨平台硬规则、并行分治 + S2 权限、S2 速率纪律指针。
- [x] **Step 4:** 统一 S2 表述：按官方 API 产品页采用“未认证共享全局池 1000 req/s、带 Key 1 RPS”，替换上游旧值“无 Key 约 100 req/5min”；429 预防纪律与有界恢复预算分层（恢复不得立即重试）。
- [x] **Step 5（后续修订）:** 前置检查位置调整：原放在 `## 运行路径与站点经验` 末尾（与运行时配置混在一起），改为文档首个章节 `## 前置检查（任何任务的第一步）`，并把 `ACADEMIC_SEARCH_ROOT` 路径约定一并前置；《任务产出协议》与本节互相引用，明确“先建任务目录与 `protocol.md`，再执行前置检查”的先后。`## 运行路径与站点经验` 只保留其余脚本调用与 CDP 配置说明。

### Task 4: D5 决策修订（先删除，后按用户要求恢复 PowerShell 实现）

- [x] **Step 1:** 按原 D5 删除 `scripts/check-deps.ps1`、`scripts/check-deps-self-test.ps1`。
- [x] **Step 2（修订）:** 用户要求恢复 `check-deps.ps1`，按 v1.4 契约重写：参数校验（仅接受 `--api-only`）与 `check-deps.sh` 同语义、curl 检查、凭据检查（仅变量名）、`--api-only` 跳过浏览器准备、Node 22+ 版本门、委托 `node ensure-proxy.mjs` 并透传退出码；文件保留 UTF-8 BOM（PowerShell 5.1 中文输出所必需）。旧版的日常 Chrome 端口发现、自拉 cdp-proxy、`/targets` 轮询已删除（v1.4 不再需要）。
- [x] **Step 3（修订）:** 文档恢复 Windows 入口：`README.md` / `README.en.md`（Quick Start、专用 Chrome 段、目录树）、`SKILL.md`（前置检查）、`project-introduction.md`（目录树）。
- [x] **Step 4:** 保留 `docs/superpowers/plans/2026-05-08-check-deps-powershell.md`（按 D6）。
- [x] **Step 5（用户决定暂不写）:** `scripts/check-deps-self-test.ps1` 不恢复、也不重写。当前 PowerShell 版本只有手工实测作为验证手段（见 Task 6 Step 5），后续如需回归保护需新开任务补测试。

### Task 5: 一致性与版本号

- [x] **Step 1:** `SKILL.md` 版本号改 `1.4.0+asianfleet.1`。`agents/openai.yaml` 不含 version 字段（上游文件仅有 interface 三项），无需修改。
- [x] **Step 2:** 全树扫描：无 `chrome://inspect` 残留；`3456` 仅剩上游的端口迁移说明与无关示例数字；无 `api-cookbook/`、无 `check-deps.ps1` 残留。
- [x] **Step 3:** `SKILL.md` frontmatter 仍为单行 `description`（行内 `': '` 仅 1 处），文件末尾无多余空格。

### Task 6: 验证

- [x] **Step 1:** `make` 在本机不可用（command not found），改直接运行等价命令：`node --test scripts/*.test.mjs` + `bash scripts/oa-pdf-download-self-test.sh`（后者 PASS）。
- [x] **Step 2:** 本机 Windows 下 node 测试 123 passed / 129 failed；同一套测试在 `upstream/main` 的干净导出中同样是 123 / 129，且失败用例集合完全一致——失败是上游测试的 POSIX 假设（路径分隔符、进程核验）导致，与本次合并无关。未运行 `make test-release`（需本机 Chrome 与专用 profile）。
- [x] **Step 3:** Windows 侧验证：`node scripts/ensure-proxy.mjs` 路径由 `check-deps.sh` 完整走通（凭据 → node 版本门 → 代理归属核验），未启动 Chrome。
- [x] **Step 4:** `git diff --stat upstream/main` 仅列出本 fork 的文件（无测试或运行时脚本改动）。
- [x] **Step 5（修订后补充）:** `check-deps.ps1` 实测（PowerShell 5.1 与 7）：`--api-only` 带假 `S2_API_KEY` 时只输出变量名、退出 0；非法参数与参数个数 >1 返回 usage/1；端口被占用时透传 `PROXY_PORT_IN_USE` 且退出 1；空闲端口下 PS7 走通完整浏览器链路（`proxy: ready ... managed`），验证后已停止该次记录的代理 PID 与专用 profile 的 Chrome 进程并清理状态文件。

**环境说明：** PowerShell 中文输出按系统 ANSI 代码页（本机 GBK）编码，与旧版行为一致；在 Git Bash 管道中查看会显示为乱码，属显示环境差异，不是脚本缺陷。

### Task 7: README 首尾精简与 fork 增量章节

- [x] **Step 1:** 删除 `README.md` / `README.en.md` 开头的 logo 块（`assets/logo.png`）与全部 badge（version / license / test / stars / last-commit / repo）。改为纯 Markdown `#` 标题，保留副标题与语言切换行。
- [x] **Step 2:** 删除 `README.md` 末尾的 `## Star History` 整节（含 star-history 链接与图表），以及开头的 Star History 文字链接。`README.en.md` 本无 Star History 节。
- [x] **Step 3:** 在 `## News` 之前新增 fork 独有内容：中文标题 `## 本 fork 的增量`、英文 `## Fork-Specific Additions`，内容为任务产出协议、S2 速率纪律、API 凭据检查、Windows 原生入口、CNKI 补充、跨平台覆盖六项，并链到 `references/` 对应文件。`README.en.md` 的 Table of Contents 同步新增条目。
- [x] **Step 4:** 验证：两文件已无 `logo.png` / `shields.io` / `star-history` 引用；新增章节位于 `## News` 之前；三个相对链接目标均存在。
- [x] **Step 5（后续修订）:** 根据用户反馈调整：
  - 删除 `assets/logo.png`（已无引用）；`assets/academic-search-framework.png` 保留。
  - 不显式暴露 fork 关系：章节标题改为「本项目独有内容」/「Project-Specific Additions」，开头句改为中性的「在通用学术检索能力之上，本项目额外提供以下内容：」，英文 TOC 同步改为 `#project-specific-additions`。
  - `## License` 作者署名改为「原作者」/「Original author」，避免让人误以为本项目改写了原作者。
  - 删除 `wechat-promo.md`，并从 `project-introduction.md` 目录树移除对应条目。

## 验证边界

浏览器相关的 `make test-release` 依赖本机 Chrome 与专用 profile；公开学术站点、登录态、反爬行为不在本地 fixture 范围内，必须按实际观测报告，不据 v1.4 文档推断。
