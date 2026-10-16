param(
    [string]$TargetPath = 'C:\ProgramData\Topaz Labs LLC\Topaz Video\models\video-encoders.json'
)
$ErrorActionPreference = 'Stop'
$expectedDefault = 'C:\ProgramData\Topaz Labs LLC\Topaz Video\models\video-encoders.json'
if ([IO.Path]::GetFullPath($TargetPath) -eq $expectedDefault) {
    $principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Run this installer from an Administrator PowerShell window.'
    }
    if (Get-Process -Name 'Topaz Video' -ErrorAction SilentlyContinue) {
        Write-Warning 'Restart Topaz Video after current exports finish to load the updated profile.'
    }
}
$target = (Resolve-Path -LiteralPath $TargetPath).ProviderPath
$entry = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'prores-4444-entry.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($entry.id -ne 'prores-4444-win' -or $entry.pixFmt -ne 'yuv444p10le' -or $entry.encoderName -ne 'prores_ks') { throw 'Unexpected encoder entry.' }
$original = @(Get-Content -LiteralPath $target -Raw -Encoding UTF8 | ConvertFrom-Json)
$updated = [Collections.Generic.List[object]]::new()
$inserted = $false
foreach ($item in $original) {
    if ($item.id -eq $entry.id -or $item.id -eq 'prores-4444-rec709-win') {
        if (-not $inserted) {$updated.Add($entry); $inserted = $true}
        continue
    }
    $updated.Add($item)
    if ($item.id -eq 'prores-422-hq-win' -and -not $inserted) {
        $updated.Add($entry); $inserted = $true
    }
}
if (-not $inserted) {$updated.Add($entry)}
$payload = ConvertTo-Json -InputObject $updated.ToArray() -Depth 100
$null = ConvertFrom-Json -InputObject $payload
$backup = $target + '.backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.bak'
Copy-Item -LiteralPath $target -Destination $backup
[IO.File]::WriteAllText($target, $payload + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
$verified = @(Get-Content -LiteralPath $target -Raw -Encoding UTF8 | ConvertFrom-Json)
if (@($verified | Where-Object {$_.id -eq $entry.id}).Count -ne 1) {throw 'Installed profile verification failed.'}
$result = [ordered]@{status='installed'; target=$target; backup=$backup; profile=$entry.profile; entries=$verified.Count; sha256=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash}
$result | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'install-result.json') -Encoding UTF8
$result | ConvertTo-Json
