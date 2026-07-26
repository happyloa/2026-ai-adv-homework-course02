$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$envPath = Join-Path $projectRoot '.env'
$cloudflaredPath = Join-Path $projectRoot '.local-tools\cloudflared.exe'
$runtimeDir = Join-Path $projectRoot '.recording-runtime'
$localUrl = 'http://127.0.0.1:3001'

function Stop-TrackedProcess {
  param(
    [string]$PidFile,
    [string]$ExpectedName
  )

  if (-not (Test-Path -LiteralPath $PidFile)) {
    return
  }

  $trackedPid = [int](Get-Content -Raw -LiteralPath $PidFile)
  $trackedProcess = Get-Process -Id $trackedPid -ErrorAction SilentlyContinue
  if ($trackedProcess -and $trackedProcess.ProcessName -eq $ExpectedName) {
    Stop-Process -Id $trackedPid -Force
    $trackedProcess.WaitForExit()
  }

  Remove-Item -LiteralPath $PidFile -Force -ErrorAction SilentlyContinue
}

function Wait-ForHttp {
  param(
    [string]$Url,
    [int]$TimeoutSeconds = 30
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    try {
      $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5
      if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) {
        return
      }
    } catch {
      Start-Sleep -Milliseconds 500
    }
  }

  throw "Timed out waiting for $Url"
}

function Wait-ForPublicDns {
  param(
    [string]$Url,
    [int]$TimeoutSeconds = 60
  )

  $hostName = ([System.Uri]$Url).DnsSafeHost
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    try {
      $records = Resolve-DnsName `
        -Name $hostName `
        -Server '1.1.1.1' `
        -Type A `
        -DnsOnly `
        -ErrorAction Stop
      if ($records | Where-Object { $_.IPAddress }) {
        return
      }
    } catch {
      Start-Sleep -Seconds 1
    }
  }

  throw "Timed out waiting for public DNS record for $hostName"
}

if (-not (Test-Path -LiteralPath $envPath)) {
  throw 'Missing .env. Create it from .env.example and set JWT_SECRET first.'
}

if (-not (Test-Path -LiteralPath $cloudflaredPath)) {
  throw 'Missing .local-tools\cloudflared.exe. Download the official Windows binary first.'
}

$nodeCommand = Get-Command node.exe -ErrorAction Stop
New-Item -ItemType Directory -Force -Path $runtimeDir | Out-Null

$serverPidFile = Join-Path $runtimeDir 'server.pid'
$tunnelPidFile = Join-Path $runtimeDir 'cloudflared.pid'
Stop-TrackedProcess -PidFile $serverPidFile -ExpectedName 'node'
Stop-TrackedProcess -PidFile $tunnelPidFile -ExpectedName 'cloudflared'

try {
  $existingResponse = Invoke-WebRequest -Uri $localUrl -UseBasicParsing -TimeoutSec 2
  if ($existingResponse) {
    throw 'Port 3001 already has a running HTTP service. Stop it before continuing.'
  }
} catch {
  if ($_.Exception.Message -like 'Port 3001*') {
    throw
  }
}

$tunnelOutLog = Join-Path $runtimeDir 'cloudflared.out.log'
$tunnelErrLog = Join-Path $runtimeDir 'cloudflared.err.log'
$serverOutLog = Join-Path $runtimeDir 'server.out.log'
$serverErrLog = Join-Path $runtimeDir 'server.err.log'

Remove-Item -LiteralPath $tunnelOutLog,$tunnelErrLog,$serverOutLog,$serverErrLog -Force -ErrorAction SilentlyContinue

$tunnelProcess = Start-Process `
  -FilePath $cloudflaredPath `
  -ArgumentList @('tunnel', '--no-autoupdate', '--url', $localUrl) `
  -WorkingDirectory $projectRoot `
  -RedirectStandardOutput $tunnelOutLog `
  -RedirectStandardError $tunnelErrLog `
  -WindowStyle Hidden `
  -PassThru

$tunnelProcess.Id | Set-Content -LiteralPath $tunnelPidFile -Encoding ASCII

$publicUrl = $null
$tunnelDeadline = (Get-Date).AddSeconds(60)
while ((Get-Date) -lt $tunnelDeadline -and -not $publicUrl) {
  if ($tunnelProcess.HasExited) {
    $details = Get-Content -Raw -LiteralPath $tunnelErrLog -ErrorAction SilentlyContinue
    throw "cloudflared exited before creating a URL.`n$details"
  }

  $combinedLog = @(
    Get-Content -Raw -LiteralPath $tunnelOutLog -ErrorAction SilentlyContinue
    Get-Content -Raw -LiteralPath $tunnelErrLog -ErrorAction SilentlyContinue
  ) -join "`n"

  $match = [regex]::Match($combinedLog, 'https://[-a-z0-9]+\.trycloudflare\.com')
  if ($match.Success) {
    $publicUrl = $match.Value
    break
  }

  Start-Sleep -Milliseconds 500
}

if (-not $publicUrl) {
  Stop-TrackedProcess -PidFile $tunnelPidFile -ExpectedName 'cloudflared'
  throw 'Timed out waiting for a trycloudflare.com URL.'
}

try {
  Wait-ForPublicDns -Url $publicUrl -TimeoutSeconds 60
} catch {
  Stop-TrackedProcess -PidFile $tunnelPidFile -ExpectedName 'cloudflared'
  throw
}

$envContent = Get-Content -Raw -LiteralPath $envPath
if ($envContent -match '(?m)^BASE_URL=.*$') {
  $envContent = [regex]::Replace($envContent, '(?m)^BASE_URL=.*$', "BASE_URL=$publicUrl")
} else {
  $envContent = $envContent.TrimEnd() + "`r`nBASE_URL=$publicUrl`r`n"
}

$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($envPath, $envContent, $utf8WithoutBom)
[System.IO.File]::WriteAllText((Join-Path $runtimeDir 'public-url.txt'), $publicUrl, $utf8WithoutBom)

$serverProcess = Start-Process `
  -FilePath $nodeCommand.Source `
  -ArgumentList @('server.js') `
  -WorkingDirectory $projectRoot `
  -RedirectStandardOutput $serverOutLog `
  -RedirectStandardError $serverErrLog `
  -WindowStyle Hidden `
  -PassThru

$serverProcess.Id | Set-Content -LiteralPath $serverPidFile -Encoding ASCII

try {
  Wait-ForHttp -Url $localUrl -TimeoutSeconds 30
} catch {
  $serverDetails = Get-Content -Raw -LiteralPath $serverErrLog -ErrorAction SilentlyContinue
  Stop-TrackedProcess -PidFile $serverPidFile -ExpectedName 'node'
  Stop-TrackedProcess -PidFile $tunnelPidFile -ExpectedName 'cloudflared'
  throw "$($_.Exception.Message)`n$serverDetails"
}

$publicCheckPassed = $true
try {
  Wait-ForHttp -Url $publicUrl -TimeoutSeconds 60
} catch {
  $publicCheckPassed = $false
  Write-Warning 'The tunnel is connected, but this computer could not verify the public URL yet. DNS propagation can take another minute.'
}

Write-Host ''
Write-Host 'Recording environment is ready.' -ForegroundColor Green
Write-Host "Public URL : $publicUrl" -ForegroundColor Cyan
Write-Host "Local URL  : $localUrl"
Write-Host 'BASE_URL was updated in the ignored .env file.'
if ($publicCheckPassed) {
  Write-Host 'Public HTTPS check passed.' -ForegroundColor Green
} else {
  Write-Host 'Before recording, open the Public URL in Chrome once to confirm it loads.' -ForegroundColor Yellow
}
Write-Host 'Keep this PowerShell session and network connection available during recording.'
Write-Host 'When finished, run: npm run recording:stop'
