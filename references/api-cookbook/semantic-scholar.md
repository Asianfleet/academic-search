# Semantic Scholar API Cookbook

Semantic Scholar 学术图谱 API 调用速查。所有示例均可直接复制执行。

**根 URL**：`https://api.semanticscholar.org/graph/v1`  
**鉴权**：Header `x-api-key: YOUR_KEY`（免费注册，高频必需；低频可不加 Key）  
**格式**：JSON  
**速率**：无 Key 时，所有匿名用户共享 1000 req/s 的全局池，不保证稳定，高峰期会被进一步限流；有 Key 时速率为 1 RPS（所有 endpoints 累计计算）。请求应尽量使用 API key，并对 HTTP 429 做指数退避

## 搜索论文

### 相关性检索（/paper/search）

```bash
# 关键词搜索（返回指定字段；limit 默认 100，最多 100）
curl -s "https://api.semanticscholar.org/graph/v1/paper/search?query=attention+is+all+you+need&fields=title,authors,year,abstract,citationCount,externalIds,openAccessPdf&limit=10" \
  -H "x-api-key: YOUR_KEY"

# 按 DOI 查询单篇
curl -s "https://api.semanticscholar.org/graph/v1/paper/DOI:10.18653/v1/P16-1162?fields=title,authors,abstract,citationCount,openAccessPdf" \
  -H "x-api-key: YOUR_KEY"

# 按 arXiv ID 查询
curl -s "https://api.semanticscholar.org/graph/v1/paper/ARXIV:1706.03762?fields=title,authors,year,citationCount,openAccessPdf" \
  -H "x-api-key: YOUR_KEY"

# 批量查询（POST，最多 500 篇 / 9999 条引用）
curl -s -X POST "https://api.semanticscholar.org/graph/v1/paper/batch?fields=title,year,citationCount" \
  -H "Content-Type: application/json" \
  -d '{"ids":["DOI:10.xxx/xxx","ARXIV:2301.00001"]}' \
  -H "x-api-key: YOUR_KEY"
```

**支持的论文 ID 类型**（`{paper_id}` 可用的形式）：

| 前缀 | 说明 | 示例 |
|------|------|------|
| （无）\/ `<sha>` | Semantic Scholar 主 ID | `649def34f8be52c8b66281af98ae884c09aef38b` |
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

用于大规模检索基础元数据，不按相关性排序，与 `/paper/search` 不同。

```bash
# 首次请求，返回 total、首页 data 以及用于续翻的 token
curl -s "https://api.semanticscholar.org/graph/v1/paper/search/bulk?query=transformer&fields=title,year,venue,citationCount&sort=citationCount:desc" \
  -H "x-api-key: YOUR_KEY"

# 用返回的 token 获取下一批
curl -s "https://api.semanticscholar.org/graph/v1/paper/search/bulk?query=transformer&fields=title,year&token=SDKJFHSDKFHWIEFSFSGHEIURYC" \
  -H "x-api-key: YOUR_KEY"
```

**注意**：单次最多 1000 篇（用 `token` 续翻，最多可拉 1000 万篇）；对匹配总数（`total`）小心，未必等于精确文献数；支持 `sort=paperId`（默认）`/publicationDate`/`citationCount`；不支持嵌套数据（citations/references 等），需要时用 `/paper/{paper_id}` 逐个取。

---

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

## 引用/被引

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

## 作者查询

```bash
# 按作者名搜索（limit 最多 1000）
curl -s "https://api.semanticscholar.org/graph/v1/author/search?query=Yann+LeCun&fields=name,affiliations,paperCount,citationCount" \
  -H "x-api-key: YOUR_KEY"

# 获取作者全部论文（limit 最多 1000；最多取最近 10000 条引用/被引）
curl -s "https://api.semanticscholar.org/graph/v1/author/{author_id}/papers?fields=title,year,citationCount&limit=100" \
  -H "x-api-key: YOUR_KEY"
```

**批量作者（/author/batch）**：

```bash
curl -s -X POST "https://api.semanticscholar.org/graph/v1/author/batch?fields=name,hIndex,citationCount" \
  -H "Content-Type: application/json" \
  -d '{"ids":["1741101","1780531"]}' \
  -H "x-api-key: YOUR_KEY"
```

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

**注意**：单次最多 1000 个作者 ID；响应最多 10 MB；`fields` 是查询参数而非请求体字段；默认只返回 `authorId` 和 `name`。

### 文本片段搜索（/snippet/search）

按查询返回论文中匹配度最高的文本片段（约 500 词，截取自标题/摘要/正文，不含图表标题与参考文献）：

```bash
curl -s "https://api.semanticscholar.org/graph/v1/snippet/search?query=literature+graph&fields=snippet.text,snippet.snippetKind,snippet.section&limit=10" \
  -H "x-api-key: YOUR_KEY"
```

**注意**：`fields` 只控制 snippet 内部字段（`snippet.text`、`snippet.snippetKind`、`snippet.section`、`snippet.snippetOffset`、`snippet.annotations.*`），paper 信息和 `score` 始终返回；`limit` 默认 10、上限 1000。
