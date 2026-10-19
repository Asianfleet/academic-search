# Academic Platform API Cookbook

各学术平台 API 调用模板。执行前替换标识和真实联系信息，检查当前服务文档、认证和配额；模板及历史字段不构成实时可用性保证。浏览器操作只在相关站点 reference 中维护。

## 限流与请求预算

先解析状态与错误响应，再提取结果。429 不证明永久配额耗尽；遵守有效 `Retry-After`，没有提示时有界退避。同一请求默认最多 2 次重试（必须退避后重试，不得立即重试）、总等待预算 30 秒；服务要求等待超过剩余预算时停止该来源，不提前重试。这是本 Skill 的预算，不是平台配额承诺。并行任务共享平台预算；详见 [S2 恢复规则](site-patterns/semanticscholar.org.md)。

本节是 429 之后的**恢复**策略；避免触发 429 的**预防**策略（串行、请求前 sleep、批量优先）见下方 Semantic Scholar 一节的「S2 速率限制调用守则」。两者分层使用：先按守则降速，触发限流后再按预算有界恢复。

---

## arXiv

**根 URL**：`https://export.arxiv.org/api/query`  
**鉴权**：无需  
**格式**：Atom XML  
**速率**：建议 3 秒/请求（非官方限制）

### 搜索

```bash
# 按标题关键词搜索（最近 10 条）
curl -s "https://export.arxiv.org/api/query?search_query=ti:attention+mechanism&max_results=10&sortBy=submittedDate&sortOrder=descending"

# 按作者搜索
curl -s "https://export.arxiv.org/api/query?search_query=au:Vaswani_A&max_results=20"

# 复合查询：标题 AND 分类
curl -s "https://export.arxiv.org/api/query?search_query=ti:transformer+AND+cat:cs.LG&max_results=10"

# 分页（第 11-20 条）
curl -s "https://export.arxiv.org/api/query?search_query=ti:diffusion+model&start=10&max_results=10"
```

**search_query 字段前缀**：

| 前缀 | 说明 |
|------|------|
| `ti:` | 标题 |
| `au:` | 作者（格式：`LastName_FirstInitial`） |
| `abs:` | 摘要 |
| `cat:` | 分类（如 `cs.AI`、`cs.LG`、`stat.ML`） |
| `all:` | 全字段搜索 |

**响应字段映射**（Atom XML `<entry>` 节点）：

| XML 路径 | 标准字段 |
|---------|---------|
| `<title>` | title |
| `<author><name>` | authors[] |
| `<summary>` | abstract |
| `<published>` | year（取前 4 位） |
| `<arxiv:doi>` | doi |
| `<id>`（末段） | arxiv_id |
| `<link rel="related" type="application/pdf" href>` | pdf_url |

**PDF 直链规律**：`https://arxiv.org/pdf/{arxiv_id}` （如 `https://arxiv.org/pdf/2301.00001`）

**BibTeX 导出**：`https://arxiv.org/bibtex/{arxiv_id}`

---

## Semantic Scholar

**根 URL**：`https://api.semanticscholar.org/graph/v1`  
**鉴权**：Header `x-api-key: YOUR_KEY`（免费注册，高频必需；低频可不加 Key）  
**格式**：JSON  
**速率**：未认证请求共享同一个全局池，官方 API 产品页当前写为 1000 req/s，高峰期会进一步限流；带 Key 后为 1 RPS（所有 endpoints 累计计算）。共享池是所有匿名调用者共用的容量，不是自己持有的配额，可用份额不可预测，因此不要依赖未认证调用的稳定性

### S2 速率限制调用守则（主代理与子 Agent 一律遵守）

涉及调用 Semantic Scholar（S2）的任务，无论主 Agent 还是子 Agent，必须遵守以下纪律，避免 429 和额度耗尽：

1. **绝不并发，必须串行**：一次需要多个请求时禁止并行，排队逐个执行，且每个请求之间必须 sleep。
2. **减少调用次数**：能走批量接口就不走单条接口。多个标识符用 `/paper/batch`，大批量检索用 `/paper/search/bulk`，不要反复调用 search。
3. **单次请求也要先 sleep**：即使只发一个请求，也要在发起前 sleep，避免与上一次请求间隔过短。
4. **sleep 时长**：覆盖 1 RPS 约束，建议每个请求前 sleep 1.5–2s；仍触发 429 时停止当前请求，按有界退避等待（≥15s，遵守有效 `Retry-After`），不要对同一请求立即重试。

额度以官方 API 产品页和 API docs 为准；429 后的重试上限与总预算见本文件「限流与请求预算」，S2 特有的故障处理见 [S2 站点经验](site-patterns/semanticscholar.org.md)。

### 搜索论文

```bash
# 关键词搜索（返回指定字段）
curl -s "https://api.semanticscholar.org/graph/v1/paper/search?query=attention+is+all+you+need&fields=title,authors,year,abstract,citationCount,externalIds,openAccessPdf&limit=10" \
  -H "x-api-key: YOUR_KEY"

# 按 DOI 查询单篇
curl -s "https://api.semanticscholar.org/graph/v1/paper/DOI:10.18653/v1/P16-1162?fields=title,authors,abstract,citationCount,openAccessPdf" \
  -H "x-api-key: YOUR_KEY"

# 按 arXiv ID 查询
curl -s "https://api.semanticscholar.org/graph/v1/paper/ARXIV:1706.03762?fields=title,authors,year,citationCount,openAccessPdf" \
  -H "x-api-key: YOUR_KEY"

# 批量查询（POST，最多 500 篇）
curl -s -X POST "https://api.semanticscholar.org/graph/v1/paper/batch?fields=title,year,citationCount" \
  -H "Content-Type: application/json" \
  -d '{"ids":["DOI:10.xxx/xxx","ARXIV:2301.00001"]}' \
  -H "x-api-key: YOUR_KEY"
```

**支持的论文 ID 类型**（`{paper_id}` 可用的形式）：

| 前缀 | 说明 | 示例 |
|------|------|------|
| （无前缀）`<sha>` | Semantic Scholar 主 ID | `649def34f8be52c8b66281af98ae884c09aef38b` |
| `CorpusId:` | Semantic Scholar 数值 ID | `CorpusId:215416146` |
| `DOI:` | Digital Object Identifier | `DOI:10.18653/v1/N18-3011` |
| `ARXIV:` | arXiv | `ARXIV:2106.15928` |
| `MAG:` | Microsoft Academic Graph | `MAG:112218234` |
| `ACL:` | Association for Computational Linguistics | `ACL:W12-3903` |
| `PMID:` | PubMed/Medline | `PMID:19872477` |
| `PMCID:` | PubMed Central | `PMCID:2323736` |
| `URL:` | 站点 URL（限 semanticscholar.org、arxiv.org、aclweb.org、acm.org、biorxiv.org） | `URL:https://arxiv.org/abs/2106.15928v1` |

**注意**：最多返回 1000 条按相关性排序的结果，需要更大规模时用 `/paper/search/bulk`；单次响应上限为 10 MB。

### 批量检索（/paper/search/bulk）

用于大规模检索基础元数据，不按相关性排序，与 `/paper/search` 不同；单次最多 1000 篇（用 `token` 续翻）。

```bash
# 首次请求，返回 total、首页 data 以及用于续翻的 token
curl -s "https://api.semanticscholar.org/graph/v1/paper/search/bulk?query=transformer&fields=title,year,venue,citationCount&sort=citationCount:desc" \
  -H "x-api-key: YOUR_KEY"

# 用返回的 token 获取下一批
curl -s "https://api.semanticscholar.org/graph/v1/paper/search/bulk?query=transformer&fields=title,year&token=SDKJFHSDKFHWIEFSFSGHEIURYC" \
  -H "x-api-key: YOUR_KEY"
```

**注意**：`total` 是匹配总数，未必等于精确文献数；支持 `sort=paperId`（默认）`/publicationDate`/`citationCount`；不支持嵌套数据（citations/references 等），需要时用 `/paper/{paper_id}` 逐个取。

### 文本片段搜索（/snippet/search）

按查询返回论文中匹配度最高的文本片段（约 500 词，截取自标题/摘要/正文，不含图表标题与参考文献）：

```bash
curl -s "https://api.semanticscholar.org/graph/v1/snippet/search?query=literature+graph&fields=snippet.text,snippet.snippetKind,snippet.section&limit=10" \
  -H "x-api-key: YOUR_KEY"
```

**注意**：`fields` 只控制 snippet 内部字段（`snippet.text`、`snippet.snippetKind`、`snippet.section`、`snippet.snippetOffset`、`snippet.annotations.*`），paper 信息和 `score` 始终返回；`limit` 默认 10、上限 1000。

### 作者查询

```bash
# 按作者名搜索
curl -s "https://api.semanticscholar.org/graph/v1/author/search?query=Yann+LeCun&fields=name,affiliations,paperCount,citationCount" \
  -H "x-api-key: YOUR_KEY"

# 获取作者全部论文（limit 最多 1000；最多取最近 10000 条引用/被引）
curl -s "https://api.semanticscholar.org/graph/v1/author/{author_id}/papers?fields=title,year,citationCount&limit=100" \
  -H "x-api-key: YOUR_KEY"

# 批量作者（POST，单次最多 1000 个作者 ID）
curl -s -X POST "https://api.semanticscholar.org/graph/v1/author/batch?fields=name,hIndex,citationCount" \
  -H "Content-Type: application/json" \
  -d '{"ids":["1741101","1780531"]}' \
  -H "x-api-key: YOUR_KEY"
```

**注意**：作者类接口单次响应最多 10 MB；`fields` 是查询参数而非请求体字段；默认只返回 `authorId` 和 `name`；`author/search` 的 `limit` 最多 1000。

### 引用/被引

```bash
# 获取引用该论文的文章（返回结构为 data[].citingPaper.*；limit 最多 1000）
# 支持 contexts（引文上下文）、intents（引文意图）、contextsWithIntent、isInfluential（重要引用标记）
curl -s "https://api.semanticscholar.org/graph/v1/paper/{paper_id}/citations?fields=title,year,authors,contexts,isInfluential&limit=50" \
  -H "x-api-key: YOUR_KEY"

# 获取该论文引用的文章（返回结构为 data[].citedPaper.*；limit 最多 1000）
curl -s "https://api.semanticscholar.org/graph/v1/paper/{paper_id}/references?fields=title,year,authors&limit=50" \
  -H "x-api-key: YOUR_KEY"
```

**引用/被引响应结构**：citations/references 返回的是批次对象（`data` 数组），每项含 `citingPaper`（citations）或 `citedPaper`（references）包装，具体字段嵌套在该子对象下：

| JSON 路径 | 标准字段 |
|-----------|---------|
| `data[].citingPaper.title` | citing_title |
| `data[].citingPaper.year` | citing_year |
| `data[].citingPaper.authors` | citing_authors |
| `data[].contexts` | citation_contexts（引文上下文片段） |
| `data[].intents` | citation_intents（引文意图） |
| `data[].contextsWithIntent` | citation_contexts_with_intent |
| `data[].isInfluential` | is_influential（是否重要引用） |

references 同理，用 `citedPaper` 替换 `citingPaper`。

**响应字段映射（单篇论文 / 搜索结果）**：

| JSON 字段 | 标准字段 |
|-----------|---------|
| `title` | title |
| `authors[].name` | authors[] |
| `year` | year |
| `abstract` | abstract |
| `citationCount` | citation_count |
| `externalIds.DOI` | doi |
| `externalIds.ArXiv` | arxiv_id |
| `openAccessPdf.url` | pdf_url |
| `venue` | venue |
| `publicationDate` | publication_date |
| `publicationTypes` | publication_types |
| `fieldsOfStudy` | fields_of_study |
| `s2FieldsOfStudy` | s2_fields_of_study |
| `influentialCitationCount` | influential_citation_count |
| `referenceCount` | reference_count |
| `isOpenAccess` | is_open_access |
| `tldr.text` | tldr |
| `citationStyles.bibtex` | bibtex |
| `corpusId` | corpus_id |

**注意**：`fields` 参数必须显式指定，否则默认只返回 `paperId` 和 `title`。

**响应字段映射（作者）**：

| JSON 字段 | 标准字段 |
|-----------|---------|
| `authorId` | author_id |
| `name` | authors[]（单个） |
| `affiliations[]` | affiliations |
| `paperCount` | paper_count |
| `citationCount` | citation_count |
| `hIndex` | h_index |
| `homepage` | homepage |
| `normalizedAffiliations[].rorId` / `.rorDisplayName` | normalized_affiliations（ROR） |

---

## Crossref

**根 URL**：`https://api.crossref.org`  
**鉴权**：无需；建议在请求中带 `mailto` 参数  
**格式**：JSON  
**适用**：跨学科 DOI、期刊、出版商、ISSN、参考文献基础核对

```bash
# 按 DOI 查询单篇
curl -s "https://api.crossref.org/works/10.1038/nature12373?mailto=your@email.com"

# 关键词搜索
curl -s "https://api.crossref.org/works?query.title=graph+neural+network&rows=10&mailto=your@email.com"

# 期刊 ISSN 查询
curl -s "https://api.crossref.org/journals/2041-1723/works?rows=10&mailto=your@email.com"
```

**响应字段映射**：

| JSON 字段 | 标准字段 |
|-----------|---------|
| `message.title[0]` | title |
| `message.author[].given/family` | authors[] |
| `message.published-print.date-parts` / `published-online` | publication_date / year |
| `message.container-title[0]` | venue |
| `message.DOI` | doi |
| `message.type` | publication_type |
| `message.ISSN[]` | issn |
| `message.ISBN[]` | isbn |
| `message.license[].URL` | license |

**注意**：Crossref 不保证摘要和 PDF。它适合作为 DOI/出版信息的权威补全，不应替代全文获取。

---

## OpenAlex

**根 URL**：`https://api.openalex.org`  
**鉴权**：当前官方文档允许无 Key 试用，API Key 可提升预算；认证和限额以 [官方 API 文档](https://help.openalex.org/api/) 为准（2026-09-05 核对），不假定匿名访问无限制
**格式**：JSON  
**适用**：跨学科作者、机构、概念、引用关系和开放获取状态补充

```bash
# 关键词搜索
curl -s "https://api.openalex.org/works?search=large+language+models&per-page=10&mailto=your@email.com"

# 按 DOI 查询
curl -s "https://api.openalex.org/works/https://doi.org/10.1038/nature12373?mailto=your@email.com"

# 作者搜索
curl -s "https://api.openalex.org/authors?search=Yann+LeCun&per-page=10&mailto=your@email.com"
```

**响应字段映射**：

| JSON 字段 | 标准字段 |
|-----------|---------|
| `title` | title |
| `authorships[].author.display_name` | authors[] |
| `publication_year` | year |
| `publication_date` | publication_date |
| `primary_location.source.display_name` | venue |
| `doi` | doi |
| `type` | publication_type |
| `cited_by_count` | citation_count |
| `open_access.oa_status` | open_access_status |
| `best_oa_location.pdf_url` / `primary_location.pdf_url` | pdf_url（候选，另记来源与验证状态） |

**注意**：OpenAlex 的概念分类适合跨学科召回，但具体期刊/会议质量仍应按 discipline profile 判断。

---

## Unpaywall

**根 URL**：`https://api.unpaywall.org/v2`  
**鉴权**：无需；必须带 email 参数  
**格式**：JSON  
**适用**：开放获取状态、合法 OA PDF 链接、出版商访问限制判定

```bash
# 按 DOI 查询开放获取状态
curl -s "https://api.unpaywall.org/v2/10.1038/nature12373?email=your@email.com"
```

**响应字段映射**：

| JSON 字段 | 标准字段 |
|-----------|---------|
| `doi` | doi |
| `title` | title |
| `year` | year |
| `journal_name` | venue |
| `is_oa` + `oa_status` | open_access_status |
| `best_oa_location.url_for_pdf` | pdf_url |
| `best_oa_location.license` | license |

**full_text_status 判定**：

| 条件 | 状态 |
|------|------|
| 可信来源明确提供 `best_oa_location.url_for_pdf` | 来源支持的 `open_pdf`，`pdf_verification_status` 未验证；下载后检查字节 |
| `is_oa=false` | 仅记录该来源未找到开放版本；若本次检查结束则 `no_open_pdf` 并记录范围 |
| 页面明确要求普通登录 | `login_required` |
| 页面明确要求机构订阅/权限 | `needs_institution` |
| PDF URL 返回 HTML | `html_not_pdf`；不能据此断言正文可读或无独立 PDF |
| 明确识别到 Cloudflare/验证码挑战 | `anti_bot_blocked`；单独 403 不足以确定原因 |

---

## PubMed（NCBI E-utilities）

**根 URL**：`https://eutils.ncbi.nlm.nih.gov/entrez/eutils/`  
**鉴权**：无需（有 API Key 可提升速率）  
**格式**：XML / JSON  
**速率**：无 Key 3 req/s；有 Key 10 req/s；请求加 `&email=your@email.com`

### 三步流程

```bash
# Step 1：esearch — 搜索，获取 PMID 列表
curl -s "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&term=CRISPR+gene+editing&retmax=20&retmode=json&email=your@email.com"

# Step 2：efetch — 按 PMID 批量获取详情（XML 格式，含摘要）
curl -s "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&id=12345678,23456789&rettype=abstract&retmode=xml&email=your@email.com"

# Step 3（可选）：elink — 获取相关文献
curl -s "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/elink.fcgi?dbfrom=pubmed&db=pubmed&id=12345678&linkname=pubmed_pubmed&retmode=json&email=your@email.com"
```

**元数据/摘要获取**（`esummary` 返回 JSON DocSum 元数据；需要摘要正文时改用 `efetch` XML）：

```bash
curl -s "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=pubmed&id=12345678&retmode=json&email=your@email.com"
```

**响应字段映射**（`esummary` / DocSum JSON）：

| JSON 字段 | 标准字段 |
|-----------|---------|
| `result[pmid].title` | title |
| `result[pmid].authors[].name` | authors[] |
| `result[pmid].pubdate`（前 4 位） | year |
| `result[pmid].source` | venue |
| `result[pmid].articleids[type=doi].value` | doi |
| `result[pmid].uid` | pubmed_id |

---

## Papers with Code（历史接口）

旧 `https://paperswithcode.com/api/v1/` 模板不作为默认运行路径。本次未确认旧接口持续返回所需 JSON；不得把历史 API 的存在当成当前可用性。

代码发现优先读取论文正文、作者项目页及其指向的官方仓库。目录或聚合页面可提供候选，但应核对论文标识与仓库作者关系。确需历史接口时，先检查响应状态、最终 URL 和 JSON schema；失败后记录限制并切换来源，不把失败解释为论文没有代码。

相关经验见 [paperswithcode.com](site-patterns/paperswithcode.com.md)。

---

## ACM Digital Library

**官方 API**：无公开免费 API  
**推荐方式**：WebFetch + Jina，或 CDP  
**DOI 前缀**：`10.1145/`

```bash
# 通过 DOI 获取页面（Jina 转 Markdown）
curl -s "https://r.jina.ai/dl.acm.org/doi/10.1145/3292500.3330701"

# 获取 BibTeX（无需登录）
curl -s "https://dl.acm.org/action/exportCitation?doi=10.1145%2F3292500.3330701&format=bibtex&downloadName=acm-bibtex"

# 直接访问 DOI 页面（JSON-LD 含结构化元数据）
curl -s "https://dl.acm.org/doi/10.1145/3292500.3330701" | grep -o '"@type".*"Article"[^}]*}'
```

**BibTeX 导出 URL 格式**：
```
https://dl.acm.org/action/exportCitation?doi={URL编码后的DOI}&format=bibtex
```
DOI 中的 `/` 编码为 `%2F`。

**注意**：该端点在部分网络环境下会返回 Cloudflare challenge 或 HTML 错页，不一定稳定；若未返回 BibTeX 文本，改用 CDP 点击页面上的导出按钮。

**JSON-LD 提取**（页面 `<script type="application/ld+json">` 中）：含 `name`（标题）、`author`、`datePublished`、`description`（摘要）。

---

## IEEE Xplore

**官方 API**：需机构订阅 Key（`https://developer.ieee.org`）  
**无 Key 时**：WebFetch / Jina 抓公开摘要页  
**文章 URL 格式**：`https://ieeexplore.ieee.org/document/{arnumber}/`

```bash
# 有 Key 时：搜索 API
curl -s "https://ieeexploreapi.ieee.org/api/v1/search/articles?querytext=deep+learning&max_records=10&apikey=YOUR_KEY"

# 无 Key：Jina 抓摘要页
curl -s "https://r.jina.ai/ieeexplore.ieee.org/document/9607200/"

# 直接抓页面（JSON-LD 在 <script> 中）
curl -s -A "Mozilla/5.0" "https://ieeexplore.ieee.org/document/9607200/"
```

**有 Key 时响应字段映射**：

| JSON 字段 | 标准字段 |
|-----------|---------|
| `title` | title |
| `authors.authors[].full_name` | authors[] |
| `publication_year` | year |
| `abstract` | abstract |
| `doi` | doi |
| `pdf_url` | pdf_url |
| `article_number` | ieee_id |

---

## Google Scholar

使用当前可用的浏览器能力，具体流程、历史选择器和失效回退见 [Scholar 站点经验](site-patterns/scholar.google.com.md)。

- 来源计数必须带平台与查询时间，不宣称任何平台的数字是全局真值。
- 先根据当前页面识别输入框、结果列表、空结果与挑战页；命中结果条件后再提取。
- `Cited by` 选择器失效或结果暂未渲染，不等于引用数为零。
- 使用自建 target，完成后仅关闭本任务创建的标签页。

## CNKI（中国知网）

检索入口、数据库代码和字段提取模板统一见 [CNKI 站点经验](site-patterns/cnki.net.md)，不要在此复制第二套选择器或固定等待流程。

当前能读取的字段取决于页面与会话状态。需要机构权限、登录或挑战时记录限制；元数据可读不代表全文开放。保留 `cnki_url` 和来源时间，引用/下载统计分别记录。浏览器通用闭环见 [browser-workflow](browser-workflow.md)。
