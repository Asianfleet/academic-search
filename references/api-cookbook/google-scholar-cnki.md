# Google Scholar & CNKI（中国知网）API Cookbook

需要浏览器自动化/登录态的学术平台调用速查。所有示例均可直接复制执行。

---

## Google Scholar

**官方 API**：无  
**唯一可靠方式**：CDP 浏览器自动化（直连用户 Chrome）  
**不要尝试**：WebFetch、curl、WebSearch 搜索 scholar.google.com

### CDP 操作流程

macOS / Linux / Bash：

```bash
bash scripts/check-deps.sh
```

Windows PowerShell：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-deps.ps1
```

```bash
# 2. 打开 Google Scholar 搜索页
TARGET=$(curl -s "http://127.0.0.1:${CDP_PROXY_PORT:-3456}/new?url=https://scholar.google.com" | node -p "JSON.parse(require('fs').readFileSync(0, 'utf8')).targetId")

# 3. 用搜索框搜索（GUI 方式，最稳定）
curl -s -X POST "http://127.0.0.1:${CDP_PROXY_PORT:-3456}/eval?target=$TARGET" \
  -d 'document.querySelector("input[name=q]").value = "attention is all you need"'
curl -s -X POST "http://127.0.0.1:${CDP_PROXY_PORT:-3456}/click?target=$TARGET" -d 'button[type=submit], input[type=submit]'

# 4. 等待结果加载后提取
curl -s -X POST "http://127.0.0.1:${CDP_PROXY_PORT:-3456}/eval?target=$TARGET" -d '
JSON.stringify(Array.from(document.querySelectorAll(".gs_ri")).slice(0,10).map(el => ({
  title: el.querySelector(".gs_rt a")?.textContent?.trim(),
  link: el.querySelector(".gs_rt a")?.href,
  authors_venue: el.querySelector(".gs_a")?.textContent?.trim(),
  cited_by: el.querySelector(".gs_fl a")?.textContent?.match(/Cited by (\d+)/)?.[1]
})))
'

# 5. 完成后关闭 tab
curl -s "http://127.0.0.1:${CDP_PROXY_PORT:-3456}/close?target=$TARGET"
```

**主要用途**：获取引用数（Scholar 引用数最全面）、发现其他平台未收录的论文、查看相关论文推荐。

**注意**：操作间隔不要过短，避免触发 CAPTCHA。详见 `site-patterns/scholar.google.com.md`。

---

## CNKI（中国知网）

**官方 API**：无公开 API
**唯一可靠方式**：CDP 浏览器自动化（直连用户 Chrome，需携带机构登录态）
**不要尝试**：curl 直接爬取（反爬严重，结果为 JS 渲染页）、任何第三方非官方 API
**主要使用场景**：中文期刊论文、硕博学位论文、中文会议论文、被引/下载统计

### 登录态说明

| 访问级别 | 能获得什么 | 如何实现 |
|---------|-----------|---------|
| 未登录 | 标题、作者、来源、年份、摘要（部分截断） | CDP 直接打开 cnki.net |
| 机构 IP / 机构账号登录 | 全文 CAJ / PDF 下载链接 | 用户在 Chrome 中完成机构认证后再用 CDP |
| 个人 CNKI 账号 | 引用/下载统计、收藏记录 | 同上 |

> 通常仅需摘要和元数据时，未登录即可。如需全文下载链接，需用户先在 Chrome 完成机构认证。

### CDP 操作流程

macOS / Linux / Bash：

```bash
bash scripts/check-deps.sh
```

Windows PowerShell：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-deps.ps1
```

```bash
# 2. 打开知网检索页（KNS8 新版界面）
TARGET=$(curl -s "http://127.0.0.1:${CDP_PROXY_PORT:-3456}/new?url=https://kns.cnki.net/kns8/defaultresult/index" \
  | node -p "JSON.parse(require('fs').readFileSync(0, 'utf8')).targetId")

# 3. 等待页面加载（JS 渲染较慢）
sleep 3

# 4. 填入搜索词
curl -s -X POST "http://127.0.0.1:${CDP_PROXY_PORT:-3456}/eval?target=$TARGET" \
  -d 'document.querySelector("#txt_SearchText").value = "大语言模型 时序预测"'

# 5. 点击检索按钮
curl -s -X POST "http://127.0.0.1:${CDP_PROXY_PORT:-3456}/click?target=$TARGET" \
  -d '#btnSearch'

# 6. 等待结果列表渲染
sleep 3

# 7. 提取结果（最多 20 条）
curl -s -X POST "http://127.0.0.1:${CDP_PROXY_PORT:-3456}/eval?target=$TARGET" -d '
JSON.stringify(
  Array.from(document.querySelectorAll(".result-table-list tbody tr")).slice(0, 20).map(tr => ({
    title:     tr.querySelector("td.name a")?.textContent?.trim(),
    url:       tr.querySelector("td.name a")?.href,
    authors:   tr.querySelector("td.author")?.textContent?.trim(),
    source:    tr.querySelector("td.source a")?.textContent?.trim(),
    date:      tr.querySelector("td.date")?.textContent?.trim(),
    database:  tr.querySelector("td.db")?.textContent?.trim(),
    cite:      tr.querySelector("td.quote a")?.textContent?.trim(),
    download:  tr.querySelector("td.download a")?.textContent?.trim()
  }))
)
'

# 8. 关闭 tab
curl -s "http://127.0.0.1:${CDP_PROXY_PORT:-3456}/close?target=$TARGET"
```

### 通过直接 URL 跳转（带预设关键词）

```bash
# 构造搜索 URL：crossids 限定期刊+学位论文+会议论文
QUERY=$(python3 -c "import urllib.parse; print(urllib.parse.quote('深度学习 时序'))")
TARGET=$(curl -s "http://127.0.0.1:${CDP_PROXY_PORT:-3456}/new?url=https://kns.cnki.net/kns8/defaultresult/index?crossids=YSTT4HG0%2CLSTPFHG2%2CIPFD9Y60&korder=SU&kw=${QUERY}" \
  | node -p "JSON.parse(require('fs').readFileSync(0, 'utf8')).targetId")
sleep 4
# 然后执行步骤 7 提取结果
```

### 获取单篇详情（摘要、关键词、基金）

```bash
# 在详情页提取结构化元数据
curl -s -X POST "http://127.0.0.1:${CDP_PROXY_PORT:-3456}/eval?target=$TARGET" -d '
(() => {
  const get = sel => document.querySelector(sel)?.textContent?.trim() ?? null;
  const getAll = sel => Array.from(document.querySelectorAll(sel)).map(el => el.textContent.trim());
  return JSON.stringify({
    title:     get("h1.title") ?? get(".doc-top h1"),
    authors:   getAll(".author a"),
    source:    get(".source a"),
    date:      get(".date") ?? get(".info-item .date"),
    abstract:  get("#ChDivSummary") ?? get(".abstract-text"),
    keywords:  getAll(".keyword a"),
    fund:      get(".fund a"),
    doi:       get(".doi a"),
    cnki_url:  location.href
  });
})()
'
```

### crossids 数据库代码

| 代码 | 数据库 | 说明 |
|------|--------|------|
| `YSTT4HG0` | 中国学术期刊网络出版总库（CNKI） | 主力期刊库，最常用 |
| `LSTPFHG2` | 中国博硕士学位论文全文数据库 | 硕博论文 |
| `IPFD9Y60` | 中国重要会议论文全文数据库 | 会议论文 |
| `WSLHLHGH` | 中国重要报纸全文数据库 | 学术性低，一般不选 |
| `NYHFWBF4` | 中国年鉴网络出版总库 | 年鉴统计，专项使用 |

**建议默认组合**（学术搜索）：`YSTT4HG0,LSTPFHG2,IPFD9Y60`

### 响应字段映射

| DOM 元素 / 字段 | 标准 Schema 字段 |
|----------------|----------------|
| `td.name a` / `h1.title` | `title` |
| `td.author` / `.author a` | `authors[]` |
| `td.source a` / `.source a` | `venue` |
| `td.date` / `.date` | `year`（取前 4 位） |
| `td.quote a` | `citation_count` |
| `td.download a` | `download_count`（CNKI 特有） |
| `#ChDivSummary` | `abstract` |
| `.keyword a` | `keywords[]` |
| `.doi a` | `doi` |
| `location.href` | `cnki_url`（CNKI 特有） |

**注意**：`source_platforms` 中记为 `"cnki"`。详见 `site-patterns/cnki.net.md`。
