#!/usr/bin/env bash
# Run only when bundled browser access is needed; --api-only never launches Chrome.
# Credential checks run in both modes and never print secret values.
set -euo pipefail

if [ "$#" -gt 1 ]; then
  echo 'Usage: check-deps.sh [--api-only]' >&2
  exit 1
fi
if [ "$#" -eq 1 ] && [ "$1" != '--api-only' ]; then
  echo 'Usage: check-deps.sh [--api-only]' >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo 'curl: missing — 请安装 curl' >&2
  exit 1
fi
echo 'curl: ok'

# --- API Key / 凭据检查（只输出是否可用，不打印 key 内容） ---
echo ""
echo "--- API Key / 凭据检查 ---"

# 检查一组候选环境变量中是否有任一非空；只输出变量名，绝不输出其值。
# 用法：check_cred <类别> <平台名> <说明> <候选变量名...>
check_cred() {
  local category="$1"
  local platform="$2"
  local note="$3"
  shift 3
  local found=""
  for var in "$@"; do
    if [ -n "${!var:-}" ]; then
      found="$var"
      break
    fi
  done
  if [ -n "$found" ]; then
    printf '%-8s %-20s: ok (检测到 $%s)\n' "$category" "$platform" "$found"
  else
    printf '%-8s %-20s: missing (可选变量: %s)\n' "$category" "$platform" "$*"
    if [ -n "$note" ]; then
      printf '          %s\n' "$note"
    fi
  fi
}

# 真正需要 API Key 的平台（鉴权 header / apikey 参数）
check_cred "api-key" "Semantic Scholar" "无 Key 时速率上限极低，多次调用易触发 429" \
  S2_API_KEY SEMANTIC_SCHOLAR_API_KEY SEMANTICSCHOLAR_API_KEY

check_cred "api-key" "IEEE Xplore" "无 Key 无法用官方 API，可回退 WebFetch/CDP" \
  IEEE_API_KEY IEEE_XPLORE_API_KEY XPLORE_API_KEY

check_cred "api-key" "PubMed/NCBI" "无 Key 时 3 req/s，有 Key 10 req/s" \
  NCBI_API_KEY EUTILS_API_KEY NCBI_EUTILS_API_KEY

check_cred "api-key" "Crossref" "Crossref-Plus Key 提升速率；无 Key 时用 mailto 参数" \
  CROSSREF_API_KEY CROSSREF_PLUS_API_KEY CR_API_KEY

# 邮箱类凭据（不是 API Key，但影响 polite pool / 必填参数）
check_cred "email" "OpenAlex" "设置邮箱进入 polite pool（User-Agent/mailto 带邮箱）" \
  OPENALEX_EMAIL CONTACT_EMAIL

check_cred "email" "Unpaywall" "必须带 email 参数" \
  UNPAYWALL_EMAIL

if [ "${1:-}" = '--api-only' ]; then
  echo 'browser: skipped (API-only)'
  exit 0
fi
if ! command -v node >/dev/null 2>&1; then
  echo 'node: missing — 浏览器模式需要 Node.js 22+；API-only 无需 Node.js' >&2
  exit 1
fi
if ! node -e 'process.exit(Number(process.versions.node.split(".")[0]) >= 22 ? 0 : 1)'; then
  echo 'node: unsupported — 请升级到 Node.js 22+' >&2
  exit 1
fi
echo "node: ok ($(node --version))"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec node "$SCRIPT_DIR/ensure-proxy.mjs"
