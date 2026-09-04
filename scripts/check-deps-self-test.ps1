# academic-search：check-deps.ps1 回归测试

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'check-deps.ps1'
$powerShellPath = (Get-Process -Id $PID).Path
$sentinel = 'check-deps-secret-must-not-appear'
$originalPort = $env:CDP_PROXY_PORT
$originalKey = $env:S2_API_KEY
$originalPath = $env:Path
$originalLocalAppData = $env:LOCALAPPDATA
$tempPath = $null
$fakeServerProcess = $null

# 断言命令调用返回预期退出码和输出片段。
function Assert-OutputContains {
    param(
        [string]$Output,
        [string]$Needle,
        [string]$Label
    )

    if ($Output -notlike "*$Needle*") {
        throw "$Label -- expected to find '$Needle', got: $Output"
    }
}

# 等待伪端点进程公布其原子绑定的端口。
function Wait-ForEndpointPorts {
    param(
        [string]$Path,
        [int]$TimeoutMilliseconds = 5000
    )

    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        if (Test-Path -LiteralPath $Path) {
            $content = Get-Content -LiteralPath $Path -Raw -ErrorAction SilentlyContinue
            if (-not [string]::IsNullOrEmpty($content)) {
                try {
                    return $content | ConvertFrom-Json
                } catch {
                    # 子进程可能仍在写入单行 JSON 输出。
                }
            }
        }
        Start-Sleep -Milliseconds 100
    }
    throw 'Fake CDP endpoints did not start in time'
}

try {
    $env:CDP_PROXY_PORT = $testPort
    $env:S2_API_KEY = $sentinel

    $normalOutput = (& $powerShellPath -NoProfile -ExecutionPolicy Bypass -File $scriptPath 2>&1 | Out-String).Trim()
    $normalExitCode = $LASTEXITCODE

    if ($normalExitCode -ne 0) {
        throw "normal invocation returned exit code $normalExitCode -- output: $normalOutput"
    }
    Assert-OutputContains $normalOutput 'node: ' 'node check'
    Assert-OutputContains $normalOutput 'curl: ok' 'curl check'
    Assert-OutputContains $normalOutput "proxy: skipped (Chrome 未连接，API 模式不需要 proxy)" 'Chrome non-blocking behavior'
    Assert-OutputContains $normalOutput 'S2_API_KEY' 'credential variable name'
    if ($normalOutput -like "*$sentinel*") {
        throw 'credential value was printed'
    }

    $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) ('academic-search-check-deps-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempPath | Out-Null
    $fakeServerPath = Join-Path $tempPath 'fake-cdp-endpoints.mjs'
    $fakeServerOutput = Join-Path $tempPath 'fake-cdp-endpoints.out'
    $fakeServerError = Join-Path $tempPath 'fake-cdp-endpoints.err'
    $fakeLocalAppData = Join-Path $tempPath 'local-app-data'
    $fakeServerSource = @'
import http from 'node:http';
import net from 'node:net';

const chromeServer = net.createServer((socket) => socket.end());
const proxyServer = http.createServer((request, response) => {
  response.writeHead(200, { 'Content-Type': 'application/json' });
  response.end('[]');
});

chromeServer.listen(0, '127.0.0.1', () => {
  proxyServer.listen(0, '127.0.0.1', () => {
    console.log(JSON.stringify({
      chromePort: chromeServer.address().port,
      proxyPort: proxyServer.address().port,
    }));
  });
});
'@
    [IO.File]::WriteAllText($fakeServerPath, $fakeServerSource, (New-Object Text.UTF8Encoding($false)))
    $nodePath = (Get-Command -Name 'node.exe' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source
    if ([string]::IsNullOrEmpty($nodePath)) {
        $nodePath = (Get-Command -Name 'node' -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    }
    $fakeServerProcess = Start-Process -FilePath $nodePath -ArgumentList ('"' + $fakeServerPath + '"') -PassThru -RedirectStandardOutput $fakeServerOutput -RedirectStandardError $fakeServerError
    $endpointPorts = Wait-ForEndpointPorts -Path $fakeServerOutput
    $fakeChromePort = [int]$endpointPorts.chromePort
    $fakeProxyPort = [int]$endpointPorts.proxyPort
    $activePortDirectory = Join-Path $fakeLocalAppData 'Google\Chrome\User Data'
    New-Item -ItemType Directory -Path $activePortDirectory -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $activePortDirectory 'DevToolsActivePort') -Value $fakeChromePort -NoNewline
    $env:LOCALAPPDATA = $fakeLocalAppData
    $env:CDP_PROXY_PORT = $fakeProxyPort
    $readyOutput = (& $powerShellPath -NoProfile -ExecutionPolicy Bypass -File $scriptPath 2>&1 | Out-String).Trim()
    $readyExitCode = $LASTEXITCODE
    if ($readyExitCode -ne 0) {
        throw "custom proxy invocation returned exit code $readyExitCode -- output: $readyOutput"
    }
    Assert-OutputContains $readyOutput "chrome: ok (port $fakeChromePort)" 'fake Chrome detection'
    Assert-OutputContains $readyOutput "proxy: ready (port $fakeProxyPort)" 'custom proxy port'
    Stop-Process -Id $fakeServerProcess.Id -Force
    $fakeServerProcess = $null

    $env:Path = $tempPath
    $missingCurlOutput = (& $powerShellPath -NoProfile -ExecutionPolicy Bypass -File $scriptPath 2>&1 | Out-String).Trim()
    $missingCurlExitCode = $LASTEXITCODE

    if ($missingCurlExitCode -ne 1) {
        throw "missing curl invocation returned exit code $missingCurlExitCode -- output: $missingCurlOutput"
    }
    Assert-OutputContains $missingCurlOutput 'curl: missing — 请安装 curl' 'missing curl behavior'

    Write-Output 'PASS: academic-search check-deps PowerShell self-test'
} finally {
    if ($null -eq $originalPort) { Remove-Item Env:CDP_PROXY_PORT -ErrorAction SilentlyContinue } else { $env:CDP_PROXY_PORT = $originalPort }
    if ($null -eq $originalKey) { Remove-Item Env:S2_API_KEY -ErrorAction SilentlyContinue } else { $env:S2_API_KEY = $originalKey }
    if ($null -ne $fakeServerProcess -and -not $fakeServerProcess.HasExited) { Stop-Process -Id $fakeServerProcess.Id -Force -ErrorAction SilentlyContinue }
    if ($null -eq $originalPath) { Remove-Item Env:Path -ErrorAction SilentlyContinue } else { $env:Path = $originalPath }
    if ($null -eq $originalLocalAppData) { Remove-Item Env:LOCALAPPDATA -ErrorAction SilentlyContinue } else { $env:LOCALAPPDATA = $originalLocalAppData }
    if ($null -ne $tempPath) { Remove-Item -Recurse -Force $tempPath -ErrorAction SilentlyContinue }
}
