# academic-search：环境与凭据检查，并确保 CDP Proxy 就绪（与 scripts/check-deps.sh 对齐）
# 用法：powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-deps.ps1 [--api-only]
# 只输出凭据对应的环境变量名，绝不输出其值。浏览器模式仅在使用 bundled CDP 运行时需要。

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# 打印用法并以失败退出；参数集合与 check-deps.sh 保持一致。
function Write-UsageAndExit {
    Write-Output 'Usage: check-deps.ps1 [--api-only]'
    exit 1
}

# 检查候选环境变量中是否有任一非空，只输出变量名，绝不输出变量值。
# 用法：Test-Credential -Category <类别> -Platform <平台名> -Note <说明> -VariableNames <候选变量名...>
function Test-Credential {
    param(
        [string]$Category,
        [string]$Platform,
        [string]$Note,
        [string[]]$VariableNames
    )

    $found = $null
    foreach ($variableName in $VariableNames) {
        $value = [Environment]::GetEnvironmentVariable($variableName, 'Process')
        if (-not [string]::IsNullOrEmpty($value)) {
            $found = $variableName
            break
        }
    }

    if (-not [string]::IsNullOrEmpty($found)) {
        Write-Output ('{0,-8} {1,-20}: ok (检测到 ${2})' -f $Category, $Platform, $found)
    } else {
        Write-Output ('{0,-8} {1,-20}: missing (可选变量: {2})' -f $Category, $Platform, ($VariableNames -join ' '))
        if (-not [string]::IsNullOrEmpty($Note)) {
            Write-Output ('          {0}' -f $Note)
        }
    }
}

$apiOnly = $false
if ($args.Count -gt 1) { Write-UsageAndExit }
if ($args.Count -eq 1) {
    if ($args[0] -ne '--api-only') { Write-UsageAndExit }
    $apiOnly = $true
}

# curl 是 API 调用的前提。PowerShell 5.1 的 curl 是 Invoke-WebRequest 别名，优先查找可执行文件。
$curlCommand = Get-Command -Name 'curl.exe' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $curlCommand) {
    $curlCommand = Get-Command -Name 'curl' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
}
if ($null -eq $curlCommand) {
    Write-Output 'curl: missing — 请安装 curl'
    exit 1
}
Write-Output 'curl: ok'

# --- API Key / 凭据检查（只输出是否可用，不打印 key 内容） ---
Write-Output ''
Write-Output '--- API Key / 凭据检查 ---'

# 真正需要 API Key 的平台（鉴权 header / apikey 参数）
Test-Credential -Category 'api-key' -Platform 'Semantic Scholar' -Note '无 Key 时速率上限极低，多次调用易触发 429' `
    -VariableNames @('S2_API_KEY', 'SEMANTIC_SCHOLAR_API_KEY', 'SEMANTICSCHOLAR_API_KEY')

Test-Credential -Category 'api-key' -Platform 'IEEE Xplore' -Note '无 Key 无法用官方 API，可回退 WebFetch/CDP' `
    -VariableNames @('IEEE_API_KEY', 'IEEE_XPLORE_API_KEY', 'XPLORE_API_KEY')

Test-Credential -Category 'api-key' -Platform 'PubMed/NCBI' -Note '无 Key 时 3 req/s，有 Key 10 req/s' `
    -VariableNames @('NCBI_API_KEY', 'EUTILS_API_KEY', 'NCBI_EUTILS_API_KEY')

Test-Credential -Category 'api-key' -Platform 'Crossref' -Note 'Crossref-Plus Key 提升速率；无 Key 时用 mailto 参数' `
    -VariableNames @('CROSSREF_API_KEY', 'CROSSREF_PLUS_API_KEY', 'CR_API_KEY')

# 邮箱类凭据（不是 API Key，但影响 polite pool / 必填参数）
Test-Credential -Category 'email' -Platform 'OpenAlex' -Note '设置邮箱进入 polite pool（User-Agent/mailto 带邮箱）' `
    -VariableNames @('OPENALEX_EMAIL', 'CONTACT_EMAIL')

Test-Credential -Category 'email' -Platform 'Unpaywall' -Note '必须带 email 参数' `
    -VariableNames @('UNPAYWALL_EMAIL')

if ($apiOnly) {
    Write-Output 'browser: skipped (API-only)'
    exit 0
}

# Node.js 22+ 只在浏览器模式下必需；版本门与 check-deps.sh 一致。
$nodeCommand = Get-Command -Name 'node.exe' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $nodeCommand) {
    $nodeCommand = Get-Command -Name 'node' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
}
if ($null -eq $nodeCommand) {
    Write-Output 'node: missing — 浏览器模式需要 Node.js 22+；API-only 无需 Node.js'
    exit 1
}

$nodePath = $nodeCommand.Source
$nodeVersion = (& $nodePath --version 2>$null | Out-String).Trim()
# 版本门与 check-deps.sh 一致：解析主版本号，非 v<数字> 或低于 22 都拒绝。
$nodeMajor = $null
if ($nodeVersion -match '^v(\d+)') {
    $nodeMajor = [int]$Matches[1]
}
if ($null -eq $nodeMajor -or $nodeMajor -lt 22) {
    Write-Output "node: unsupported — 请升级到 Node.js 22+（当前 $nodeVersion）"
    exit 1
}
Write-Output "node: ok ($nodeVersion)"

# 委托 v1.4 运行时：ensure-proxy.mjs 负责专用 profile、端口归属核验与有界启动。
& $nodePath (Join-Path $scriptDir 'ensure-proxy.mjs')
$exitCode = $LASTEXITCODE
if ($null -eq $exitCode) { $exitCode = 1 }
exit $exitCode
