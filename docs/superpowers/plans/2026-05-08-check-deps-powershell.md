# check-deps PowerShell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Windows PowerShell implementation of `check-deps.sh` and update every documented invocation to select the platform-appropriate script.

**Architecture:** Keep the existing Bash script unchanged. Add an independent PowerShell implementation that uses native PowerShell 5.1 APIs for environment checks, TCP probing, process startup, HTTP polling, and environment-variable inspection, while continuing to launch `cdp-proxy.mjs` with Node.js. Add a PowerShell self-test that exercises the externally observable contract without requiring Chrome.

**Tech Stack:** Windows PowerShell-compatible syntax, Node.js, external `curl.exe`, Markdown documentation.

## Global Constraints

- Preserve `check-deps.sh` observable behavior and messages; the PowerShell version mirrors its exit codes and checks.
- The PowerShell script must run on Windows PowerShell, not only PowerShell 7.
- Credentials are detected by variable name only; values must never be printed.
- Chrome not being connected remains non-blocking so API-only usage exits successfully.
- `CDP_PROXY_PORT` defaults to `3456` and overrides the proxy port when non-empty.
- Do not add a runtime dependency beyond Node.js and curl.

---

### Task 1: Add PowerShell regression coverage

**Files:**
- Create: `scripts/check-deps-self-test.ps1`

**Interfaces:**
- Consumes: `scripts/check-deps.ps1`, the current PowerShell process environment, and an unused local test port.
- Produces: exit code `0` with `PASS: academic-search check-deps PowerShell self-test` when the contract holds.

- [x] **Step 1: Write the failing test**

Create a PowerShell 5.1-compatible test that invokes the target script with a sentinel credential value, then asserts Node/curl status, Chrome's non-blocking message, the credential variable name, and absence of the sentinel value. Start temporary fake Chrome and Proxy endpoints on available ports, set `CDP_PROXY_PORT` to the fake Proxy port, then assert that Chrome discovery and `proxy: ready` use those ports. Add a second invocation with a temporary PATH containing no `curl.exe`; assert exit code `1` and the exact `curl: missing` output. The test must fail clearly when `check-deps.ps1` does not exist.

- [x] **Step 2: Run test to verify it fails**

Run: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/check-deps-self-test.ps1` on Windows PowerShell.

Expected: FAIL because `scripts/check-deps.ps1` is not yet present.

- [x] **Step 3: Keep the test as the regression harness**

The test itself is the deliverable for this task; no production implementation is added in this task.

---

### Task 2: Implement the Windows PowerShell script

**Files:**
- Create: `scripts/check-deps.ps1`

**Interfaces:**
- Consumes: `CDP_PROXY_PORT`, Node.js, `curl.exe`, Chrome `DevToolsActivePort` files, and `scripts/cdp-proxy.mjs`.
- Produces: the same check sections and exit behavior as `check-deps.sh`; returns `1` when curl is unavailable or Proxy startup polling times out, otherwise returns `0`.

- [x] **Step 1: Write the minimal implementation for the failing test**

Implement a UTF-8-with-BOM PowerShell script compatible with Windows PowerShell:

```powershell
$proxyPort = $env:CDP_PROXY_PORT
if ([string]::IsNullOrEmpty($proxyPort)) { $proxyPort = '3456' }
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$node = Get-Command node.exe -ErrorAction SilentlyContinue
if ($null -eq $node) { $node = Get-Command node -CommandType Application -ErrorAction SilentlyContinue }
if ($null -ne $node) {
    $nodeVersion = (& $node.Source --version 2>$null | Out-String).Trim()
    if ($nodeVersion -match '^v(\d+)') {
        if ([int]$Matches[1] -ge 22) { Write-Output "node: ok ($nodeVersion)" }
        else { Write-Output "node: warn ($nodeVersion, 建议升级到 22+，低版本需安装 ws 模块)" }
    } else {
        Write-Output "node: warn ($nodeVersion, 建议升级到 22+，低版本需安装 ws 模块)"
    }
} else {
    Write-Output 'node: missing — CDP 浏览器模式不可用（Google Scholar 等需要）；arXiv/S2/PubMed 等 API 模式仍可正常使用'
}

$curl = Get-Command curl.exe -ErrorAction SilentlyContinue
if ($null -eq $curl) { $curl = Get-Command curl -CommandType Application -ErrorAction SilentlyContinue }
if ($null -eq $curl) {
    Write-Output 'curl: missing — 请安装 curl'
    exit 1
}
Write-Output 'curl: ok'
```

Then add focused helpers with comment-based purpose documentation: a TCP port probe using `TcpClient.BeginConnect`/`WaitOne` with a 2-second timeout; a curl wrapper that returns text and suppresses stderr; a credential checker that reads only environment-variable presence; and Chrome active-port discovery for Windows, macOS, and Linux paths. Probe active port files first, then ports `9222`, `9229`, and `9333`. When Chrome is unavailable, print the three existing explanatory lines and skip Proxy startup.

When Chrome is available, request `/targets`; accept a response beginning with `[`. Otherwise start `cdp-proxy.mjs` through `Start-Process`, redirecting stdout and stderr to temporary-directory log files, wait two seconds, poll up to 15 times, print the existing authorization warning on the first iteration, and exit `1` on timeout. Finish with the exact API Key / credential checks and notes from `check-deps.sh`.

- [x] **Step 2: Run the regression test**

Run: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/check-deps-self-test.ps1`.

Expected: `PASS: academic-search check-deps PowerShell self-test` and exit code `0`.

- [x] **Step 3: Run direct syntax validation**

Run: `powershell.exe -NoProfile -Command "$errors = $null; [System.Management.Automation.Language.Parser]::ParseFile('scripts/check-deps.ps1', [ref]$null, [ref]$errors) | Out-Null; if ($errors.Count -gt 0) { $errors | Format-List; exit 1 }"`.

Expected: no parser errors and exit code `0`.

---

### Task 3: Update all documentation and script inventories

**Files:**
- Modify: `SKILL.md`
- Modify: `README.md`
- Modify: `README.en.md`
- Modify: `references/api-cookbook.md`
- Modify: `references/cdp-api.md`
- Modify: `project-introduction.md`

**Interfaces:**
- Consumes: the new platform-selection command convention.
- Produces: no documentation call site that instructs every platform to run only `check-deps.sh`; all inventories list both script variants.

- [x] **Step 1: Replace documented invocations**

For every shell-only `bash .../check-deps.sh` example, show the platform-specific form:

```text
Windows PowerShell:
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-deps.ps1

macOS / Linux / Bash:
bash scripts/check-deps.sh
```

Use equivalent installed-skill paths in README examples. For prose such as the CDP error table, refer to `check-deps.ps1` or `check-deps.sh` according to platform rather than naming only the Bash script.

- [x] **Step 2: Update project structure listings**

Add `check-deps.ps1` beside `check-deps.sh` in every project-structure or script-inventory section, describing it as the Windows PowerShell implementation. Add the PowerShell self-test to the inventory if that section lists regression scripts.

- [x] **Step 3: Verify documentation coverage**

Run: `rg -n -i --hidden -g '!\.git' 'check-deps' .`

Expected: every invocation is either explicitly platform-qualified or is a platform-neutral reference naming both `check-deps.ps1` and `check-deps.sh`; no stale Bash-only instruction remains.

---

### Task 4: Final verification and diff hygiene

**Files:**
- Verify: all files changed by Tasks 1-3

- [x] **Step 1: Run the PowerShell test and parser validation again**

Run the commands from Task 2 in a fresh shell and confirm both exit `0`.

- [x] **Step 2: Run existing repository checks where available**

Run: `make test`.

Expected: the existing Bash regression suite passes, or the environment limitation is recorded exactly if Chrome or Make is unavailable.

- [x] **Step 3: Inspect the final diff**

Run: `git diff --check && git status --short && git diff --stat`.

Expected: no whitespace errors, and only the new PowerShell implementation, its regression test, the implementation plan, and documentation updates are changed.
