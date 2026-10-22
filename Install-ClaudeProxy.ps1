# Cai dat proxy + CA cert cho Claude Code (user hien tai)
# Dung: chuot phai -> "Run with PowerShell"
param([string]$CertSource = (Join-Path $PSScriptRoot 'ca_179.crt'))

# Serialize JSON theo dinh dang chuan (2 space, "key": value) giong Claude Code
function ConvertTo-StdJson($v, [int]$level = 0) {
    $pad  = '  ' * $level
    $pad1 = '  ' * ($level + 1)
    if ($null -eq $v) { return 'null' }
    if ($v -is [bool]) { return $v.ToString().ToLower() }
    if ($v -is [string] -or $v -is [char]) {
        $t = ConvertTo-Json -InputObject ([string]$v) -Compress
        foreach ($c in 0x27,0x26,0x3c,0x3e) { $t = $t.Replace(('\u{0:x4}' -f $c), [string][char]$c) }
        return $t
    }
    if ($v -is [datetime]) { return '"' + $v.ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'") + '"' }
    if ($v -is [System.Collections.IDictionary] -or $v -is [System.Management.Automation.PSCustomObject]) {
        $props = if ($v -is [System.Collections.IDictionary]) {
            $v.Keys | ForEach-Object { [pscustomobject]@{ Name = $_; Value = $v[$_] } }
        } else { $v.PSObject.Properties }
        $items = @($props | ForEach-Object { $pad1 + (ConvertTo-StdJson ([string]$_.Name) 0) + ': ' + (ConvertTo-StdJson $_.Value ($level + 1)) })
        if ($items.Count -eq 0) { return '{}' }
        return "{`n" + ($items -join ",`n") + "`n$pad}"
    }
    if ($v -is [System.Collections.IEnumerable]) {
        $items = @($v | ForEach-Object { $pad1 + (ConvertTo-StdJson $_ ($level + 1)) })
        if ($items.Count -eq 0) { return '[]' }
        return "[`n" + ($items -join ",`n") + "`n$pad]"
    }
    return [string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0}', $v)
}

$ErrorActionPreference = 'Stop'
try {
    $claudeDir = Join-Path $env:USERPROFILE '.claude'
    $settings  = Join-Path $claudeDir 'settings.json'
    $certDest  = Join-Path $claudeDir 'ca_179.crt'

    if (-not (Test-Path -LiteralPath $CertSource)) { throw "Khong tim thay file cert: $CertSource" }
    if (-not (Test-Path -LiteralPath $claudeDir)) { New-Item -ItemType Directory -Path $claudeDir | Out-Null }

    # 1. Copy cert
    if ([IO.Path]::GetFullPath($CertSource) -ne [IO.Path]::GetFullPath($certDest)) {
        Copy-Item -LiteralPath $CertSource -Destination $certDest -Force
    }
    Write-Host "Da copy cert: $certDest"

    # 2. Cap nhat settings.json
    $json = $null
    if (Test-Path -LiteralPath $settings) {
        $raw = [IO.File]::ReadAllText($settings)
        if ($raw.Trim()) {
            Copy-Item -LiteralPath $settings -Destination "$settings.bak" -Force
            $json = $raw | ConvertFrom-Json
        }
    }
    if ($null -eq $json) { $json = New-Object psobject }

    if ($null -eq $json.PSObject.Properties['env'] -or $null -eq $json.env) {
        $json | Add-Member -NotePropertyName env -NotePropertyValue (New-Object psobject) -Force
    }

    $noProxy = 'localhost,127.0.0.1,::1,bitbucket.org,bitbucket.io,*.bitbucket.org,*.bitbucket.io,github.com,*.github.com,gitlab.com,*.gitlab.com,atlassian.com,atlassian.net,atlassian.io,*.atlassian.com,*.atlassian.net,*.atlassian.io,*.azure.com,*.visualstudio.com,*.azureedge.net,*.blob.core.windows.net,raw.githubusercontent.com,objects.githubusercontent.com,npmjs.org,*.npmjs.org,npmjs.com,*.npmjs.com,pypi.org,*.pypi.org,files.pythonhosted.org,figma.com,*.figma.com,*.googleapis.com'
    $values = [ordered]@{
        'HTTPS_PROXY'                              = 'http://172.16.50.179:8080'
        'HTTP_PROXY'                               = 'http://172.16.50.179:8080'
        'NODE_EXTRA_CA_CERTS'                      = $certDest   # ConvertTo-Json tu doi \ thanh \
        'NO_PROXY'                                 = $noProxy
        'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC' = '1'
    }
    # NO_PROXY: gop voi gia tri hien co (khong trung lap)
    $cur = $json.env.PSObject.Properties['NO_PROXY']
    if ($cur -and $cur.Value) {
        $list = New-Object System.Collections.Generic.List[string]
        foreach ($e in (($cur.Value + ',' + $noProxy) -split ',')) {
            $e = $e.Trim()
            if ($e -and -not ($list | Where-Object { $_ -ieq $e })) { $list.Add($e) }
        }
        $values['NO_PROXY'] = $list -join ','
    }
    foreach ($k in $values.Keys) {
        $json.env | Add-Member -NotePropertyName $k -NotePropertyValue $values[$k] -Force
    }

    $out = (ConvertTo-StdJson $json) + "`n"
    [IO.File]::WriteAllText($settings, $out, (New-Object Text.UTF8Encoding($false)))
    Write-Host "Da cap nhat: $settings"
    Write-Host "`nCac key da ghi vao env:" -ForegroundColor Cyan
    foreach ($k in $values.Keys) {
        Write-Host "  $k" -ForegroundColor Yellow
        Write-Host "    = $($values[$k])"
    }
    Write-Host "`nHoan tat. Hay khoi dong lai Claude Code." -ForegroundColor Green
} catch {
    Write-Host "LOI: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host "`nNhan phim bat ky de thoat..."
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
