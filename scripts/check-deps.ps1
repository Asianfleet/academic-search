# academic-search：环境检查并确保 CDP Proxy 就绪

$proxyPort = $env:CDP_PROXY_PORT
if ([string]::IsNullOrEmpty($proxyPort)) {
    $proxyPort = '3456'
}
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# 在与 Bash 脚本相同的超时范围内检查本地 TCP 端口是否可连接。
function Test-TcpPort {
    param(
        [int]$Port,
        [int]$TimeoutMilliseconds = 2000
    )

    $client = New-Object System.Net.Sockets.TcpClient
    $asyncResult = $null
    try {
        $asyncResult = $client.BeginConnect('127.0.0.1', $Port, $null, $null)
        if (-not $asyncResult.AsyncWaitHandle.WaitOne($TimeoutMilliseconds)) {
            return $false
        }
        $client.EndConnect($asyncResult)
        return $true
    } catch {
        return $false
    } finally {
        if ($null -ne $asyncResult -and $null -ne $asyncResult.AsyncWaitHandle) {
            $asyncResult.AsyncWaitHandle.Close()
        }
        $client.Close()
    }
}

# 调用外部 curl，并避免诊断 stderr 影响脚本输出。
function Invoke-CurlText {
    param(
        [string]$CurlPath,
        [string[]]$Arguments
    )

    $result = & $CurlPath @Arguments 2>$null
    if ($null -eq $result) {
        return ''
    }
    return ($result -join [Environment]::NewLine)
}

# 从活动端口文件或标准回退端口中定位可用的 Chrome DevTools 端口。
function Find-ChromeDebugPort {
    $userHome = [Environment]::GetFolderPath('UserProfile')
    if ([string]::IsNullOrEmpty($userHome)) {
        $userHome = $env:HOME
    }
    $platform = [Environment]::OSVersion.Platform.ToString()
    $activePortFiles = @()

    if ($platform -eq 'Win32NT') {
        $localAppData = $env:LOCALAPPDATA
        if ([string]::IsNullOrEmpty($localAppData)) {
            $localAppData = Join-Path $userHome 'AppData\Local'
        }
        $activePortFiles += Join-Path $localAppData 'Google\Chrome\User Data\DevToolsActivePort'
        $activePortFiles += Join-Path $localAppData 'Chromium\User Data\DevToolsActivePort'
    } elseif ($env:OSTYPE -like 'darwin*') {
        $activePortFiles += Join-Path $userHome 'Library\Application Support\Google\Chrome\DevToolsActivePort'
        $activePortFiles += Join-Path $userHome 'Library\Application Support\Google\Chrome Canary\DevToolsActivePort'
        $activePortFiles += Join-Path $userHome 'Library\Application Support\Chromium\DevToolsActivePort'
    } else {
        $activePortFiles += Join-Path $userHome '.config\google-chrome\DevToolsActivePort'
        $activePortFiles += Join-Path $userHome '.config\chromium\DevToolsActivePort'
    }

    foreach ($filePath in $activePortFiles) {
        try {
            if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
                continue
            }
            $firstLine = ((Get-Content -LiteralPath $filePath -Raw).Trim() -split '\r?\n' | Where-Object { $_ -ne '' } | Select-Object -First 1)
            $port = 0
            if ([int]::TryParse($firstLine, [ref]$port) -and $port -gt 0 -and $port -lt 65536) {
                if (Test-TcpPort -Port $port) {
                    return $port
                }
            }
        } catch {
            continue
        }
    }

    foreach ($port in @(9222, 9229, 9333)) {
        if (Test-TcpPort -Port $port) {
            return $port
        }
    }
    return $null
}

# 检查候选环境变量是否已设置，但不暴露其值。
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

$nodeCommand = Get-Command -Name 'node.exe' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $nodeCommand) {
    $nodeCommand = Get-Command -Name 'node' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
}
$nodePath = $null
if ($null -ne $nodeCommand) {
    $nodePath = $nodeCommand.Source
    $nodeVersion = (& $nodePath --version 2>$null | Out-String).Trim()
    if ($nodeVersion -match '^v(\d+)') {
        if ([int]$Matches[1] -ge 22) {
            Write-Output "node: ok ($nodeVersion)"
        } else {
            Write-Output "node: warn ($nodeVersion, 建议升级到 22+，低版本需安装 ws 模块)"
        }
    } else {
        Write-Output "node: warn ($nodeVersion, 建议升级到 22+，低版本需安装 ws 模块)"
    }
} else {
    Write-Output 'node: missing — CDP 浏览器模式不可用（Google Scholar 等需要）；arXiv/S2/PubMed 等 API 模式仍可正常使用'
}

$curlCommand = Get-Command -Name 'curl.exe' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $curlCommand) {
    $curlCommand = Get-Command -Name 'curl' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
}
if ($null -eq $curlCommand) {
    Write-Output 'curl: missing — 请安装 curl'
    exit 1
}
$curlPath = $curlCommand.Source
Write-Output 'curl: ok'

$chromePort = $null
if ($null -ne $nodePath) {
    $chromePort = Find-ChromeDebugPort
}
if ($null -eq $chromePort) {
    Write-Output 'chrome: not connected — 请打开 chrome://inspect/#remote-debugging 并勾选 Allow remote debugging'
    Write-Output '  注：Chrome 调试连接仅在访问需要浏览器自动化的平台（如 Google Scholar）时必需'
    Write-Output '  使用 arXiv、Semantic Scholar、PubMed 等 API 平台无需此步骤'
} else {
    Write-Output "chrome: ok (port $chromePort)"
}

if ($null -ne $chromePort) {
    $targetsUrl = 'http://127.0.0.1:{0}/targets' -f $proxyPort
    $targets = Invoke-CurlText -CurlPath $curlPath -Arguments @('-s', '--connect-timeout', '3', $targetsUrl)
    if ($targets -match '^\[') {
        Write-Output "proxy: ready (port $proxyPort)"
    } else {
        Write-Output "proxy: connecting (port $proxyPort)..."
        $proxyScript = Join-Path $scriptDir 'cdp-proxy.mjs'
        $logBase = Join-Path ([IO.Path]::GetTempPath()) ('academic-search-cdp-proxy-' + [Guid]::NewGuid().ToString('N'))
        $stdoutLog = "$logBase.log"
        $stderrLog = "$logBase.err.log"
        try {
            Start-Process -FilePath $nodePath -ArgumentList @('"' + $proxyScript + '"') -WorkingDirectory $scriptDir -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog -ErrorAction Stop | Out-Null
        } catch {
            # 保持既有的就绪轮询与超时输出，不泄露 PowerShell 异常细节。
        }
        Start-Sleep -Seconds 2
        for ($i = 1; $i -le 15; $i++) {
            $targets = Invoke-CurlText -CurlPath $curlPath -Arguments @('-s', '--connect-timeout', '5', '--max-time', '8', $targetsUrl)
            if ($targets -match '^\[') {
                Write-Output "proxy: ready (port $proxyPort)"
                exit 0
            }
            if ($i -eq 1) {
                Write-Output '⚠️  Chrome 可能有授权弹窗，请点击「允许」后等待连接...'
            }
        }
        Write-Output '❌ 连接超时，请检查 Chrome 调试设置'
        exit 1
    }
} else {
    Write-Output 'proxy: skipped (Chrome 未连接，API 模式不需要 proxy)'
}

Write-Output ''
Write-Output '--- API Key / 凭据检查 ---'

Test-Credential 'api-key' 'Semantic Scholar' '无 Key 时速率上限极低，多次调用易触发 429' @('S2_API_KEY', 'SEMANTIC_SCHOLAR_API_KEY', 'SEMANTICSCHOLAR_API_KEY')
Test-Credential 'api-key' 'IEEE Xplore' '无 Key 无法用官方 API，可回退 WebFetch/CDP' @('IEEE_API_KEY', 'IEEE_XPLORE_API_KEY', 'XPLORE_API_KEY')
Test-Credential 'api-key' 'PubMed/NCBI' '无 Key 时 3 req/s，有 Key 10 req/s' @('NCBI_API_KEY', 'EUTILS_API_KEY', 'NCBI_EUTILS_API_KEY')
Test-Credential 'api-key' 'Crossref' 'Crossref-Plus Key 提升速率；无 Key 时用 mailto 参数' @('CROSSREF_API_KEY', 'CROSSREF_PLUS_API_KEY', 'CR_API_KEY')
Test-Credential 'email' 'OpenAlex' '设置邮箱进入 polite pool（User-Agent/mailto 带邮箱）' @('OPENALEX_EMAIL', 'CONTACT_EMAIL')
Test-Credential 'email' 'Unpaywall' '必须带 email 参数' @('UNPAYWALL_EMAIL')
