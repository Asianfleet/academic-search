# 开放 API 平台 Cookbook（arXiv / Crossref / OpenAlex / Unpaywall / PubMed / Papers with Code）

无需浏览器自动化、可直接 curl 调用的学术平台 API 速查。所有示例均可直接复制执行。

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
**鉴权**：无需；建议带 `mailto` 参数  
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
| `primary_location.pdf_url` | pdf_url |

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
| `best_oa_location.url_for_pdf` 存在且响应为 PDF | `open_pdf` |
| `is_oa=false` | `no_open_pdf` |
| 出版商页面存在但 PDF 需要登录/订阅 | `needs_institution` |
| PDF URL 返回 HTML | `html_not_pdf` |
| 403、Cloudflare、验证码 | `anti_bot_blocked` |

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

## Papers with Code

**根 URL**：`https://paperswithcode.com/api/v1`  
**鉴权**：无需  
**格式**：JSON  
**速率**：无官方说明，适度使用

```bash
# 搜索论文
curl -s "https://paperswithcode.com/api/v1/papers/?q=object+detection&items_per_page=10"

# 获取论文详情
curl -s "https://paperswithcode.com/api/v1/papers/{paper_id}/"

# 获取论文对应代码仓库
curl -s "https://paperswithcode.com/api/v1/papers/{paper_id}/repositories/"

# 获取论文在 benchmark 上的结果
curl -s "https://paperswithcode.com/api/v1/papers/{paper_id}/results/"

# 按方法搜索
curl -s "https://paperswithcode.com/api/v1/methods/?q=transformer"
```

**响应字段映射**：

| JSON 字段 | 标准字段 |
|-----------|---------|
| `title` | title |
| `authors` | authors[] |
| `published` | year（前 4 位） |
| `abstract` | abstract |
| `arxiv_id` | arxiv_id |
| `url_pdf` | pdf_url |

**独特价值**：`repositories` 端点可直接获取论文对应 GitHub 仓库（stars、框架、官方/非官方标注）。
