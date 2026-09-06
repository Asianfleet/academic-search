# IEEE Xplore & ACM Digital Library API Cookbook

计算机领域两大英文出版商平台调用速查。所有示例均可直接复制执行。

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
