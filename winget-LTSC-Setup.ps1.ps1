<#
.SYNOPSIS
    Enterprise Post-Installation & App Lifecycle Engine for Windows 10/11 & LTSC.
.DESCRIPTION
    Detects installed apps, missing apps, and apps needing update.
    Shows [OK], [INSTALL], and [UPDATE], and waits for approval before making changes.
#>

[CmdletBinding()]
param(
    [switch]$AutoApprove
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!] Elevating privileges to Administrator..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath) -Verb RunAs
    exit 0
}

Clear-Host
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "      Windows Post-Installation Automated Setup      " -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan

Write-Host "`n[+] Verifying Package Manager engine..." -ForegroundColor Cyan

function Install-WingetBootstrap {
    Write-Host "[*] WinGet not found. Bootstrapping it..." -ForegroundColor Yellow
    $ProgressPreference = 'SilentlyContinue'
    $TempDir = "$env:TEMP\WinGetBootstrap"
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

    try {
        $BundlePath = Join-Path $TempDir 'Microsoft.DesktopAppInstaller.msixbundle'
        $DownloadUrl = 'https://aka.ms/getwinget'

        Invoke-WebRequest -Uri $DownloadUrl -OutFile $BundlePath -UseBasicParsing
        Add-AppxPackage -Path $BundlePath -ForceApplicationShutdown

        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-Host "[OK] WinGet installed successfully." -ForegroundColor Green
            return $true
        }

        throw 'WinGet is still unavailable after installation.'
    }
    catch {
        Write-Host "[X] Automatic WinGet bootstrap failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "    Please install App Installer manually from Microsoft Store or visit: https://aka.ms/getwinget" -ForegroundColor Yellow
        return $false
    }
    finally {
        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    if (-not (Install-WingetBootstrap)) {
        exit 1
    }
}
else {
    Write-Host "[OK] WinGet is operational." -ForegroundColor Green
}

Write-Host "[*] Updating WinGet source repositories..." -ForegroundColor Cyan
winget source update --disable-interactivity | Out-Null

$SystemRuntimes = @(
    'Microsoft.AppInstaller',
    'Microsoft.DotNet.DesktopRuntime.8',
    'Microsoft.DotNet.DesktopRuntime.9',
    'Microsoft.DotNet.Native.Runtime',
    'Microsoft.DirectX',
    'Microsoft.WindowsTerminal',
    'Microsoft.EdgeWebView2Runtime',
    'Microsoft.UI.Xaml.2.8',
    'Microsoft.WindowsAppRuntime.1.6',
    'Microsoft.WindowsAppRuntime.1.8',
    'Microsoft.WindowsAppRuntime.2',
    'Microsoft.VCLibs.14',
    'Microsoft.VCLibs.Desktop.14',
    'Microsoft.VCRedist.2005.x86',
    'Microsoft.VCRedist.2008.x64',
    'Microsoft.VCRedist.2008.x86',
    'Microsoft.VCRedist.2010.x64',
    'Microsoft.VCRedist.2010.x86',
    'Microsoft.VCRedist.2013.x64',
    'Microsoft.VCRedist.2015+.x64',
    'Microsoft.VCRedist.2015+.x86',
    'Microsoft.VSTOR',
    'Microsoft.XNARedist',
    'Python.Python.3.13',
    'Python.Launcher'
)

$EssentialApps = @(
    'Bitwarden.Bitwarden',
    'Brave.Brave',
    'Flow-Launcher.Flow-Launcher',
    'Git.Git',
    'Google.Chrome',
    'Microsoft.Edge',
    'Microsoft.PowerShell',
    'Microsoft.VisualStudioCode',
    'JanDeDobbeleer.OhMyPosh',
    'Telegram.TelegramDesktop',
    'VideoLAN.VLC',
    '7zip.7zip',
    'qBittorrent.qBittorrent',
    'Rufus.Rufus',
    'Ventoy.Ventoy',
    'RARLab.WinRAR',
    'GuoJikun.QuickLook',
    'CodecGuide.K-LiteCodecPack.Mega',
    'OpenWhisperSystems.Signal',
    'Notepad++.Notepad++',
    'BleachBit.BleachBit',
    'OnlyOffice.OnlyOffice',
    'Discord.Discord',
    'Microsoft.WindowsTerminal',
    'Python.Python.3.13'
)

$OptionalApps = @(
    'Microsoft.AppInstaller',
    'erez-c137.NetSpeedTray',
    'Apple.iTunes',
    'Oracle.JavaRuntimeEnvironment',
    'Apple.QuickTime',
    'CreativeTechnology.OpenAL',
    'SublimeHQ.SublimeText.4',
    'WhatsApp.WhatsApp'
)

function Test-AppxPackageInstalled {
    param(
        [string[]]$NamePatterns
    )

    foreach ($Pattern in $NamePatterns) {
        $Match = Get-AppxPackage -Name $Pattern -ErrorAction SilentlyContinue
        if ($Match) {
            return $true
        }
    }

    return $false
}

function Get-PackageStatus {
    param(
        [string[]]$PackageList,
        [string]$SectionName
    )

    Write-Host "`n===== $SectionName =====" -ForegroundColor Cyan
    $InstalledDump = (winget list --accept-source-agreements --disable-interactivity 2>$null) | Out-String
    $UpgradeDump   = (winget upgrade --accept-source-agreements --disable-interactivity 2>$null) | Out-String

    $InstalledList = [System.Collections.Generic.List[string]]::new()
    $UpgradeList   = [System.Collections.Generic.List[string]]::new()
    $MissingList   = [System.Collections.Generic.List[string]]::new()

    foreach ($Pkg in $PackageList) {
        $IsInstalled = $InstalledDump -match "(?m)^\s*.*\s+$([regex]::Escape($Pkg))\s+"
        $NeedsUpgrade = $UpgradeDump -match "(?m)^\s*.*\s+$([regex]::Escape($Pkg))\s+"

        if (-not $IsInstalled) {
            $AppxPatterns = @()
            switch ($Pkg) {
                'Discord.Discord' { $AppxPatterns = @('*Discord*') }
                'WhatsApp.WhatsApp' { $AppxPatterns = @('*WhatsApp*', '*5319275A.WhatsAppDesktop*') }
                default { $AppxPatterns = @() }
            }

            if ($AppxPatterns.Count -gt 0) {
                $IsInstalled = Test-AppxPackageInstalled -NamePatterns $AppxPatterns
            }
        }

        if ($NeedsUpgrade) {
            Write-Host "[UPDATE] $Pkg" -ForegroundColor Yellow
            $UpgradeList.Add($Pkg)
        }
        elseif ($IsInstalled) {
            $StoreHint = $false
            if ($Pkg -eq 'Discord.Discord' -or $Pkg -eq 'WhatsApp.WhatsApp') {
                $StoreHint = $true
            }

            Write-Host "[OK] $Pkg" -ForegroundColor Green
            if ($StoreHint) {
                Write-Host "     [!] Microsoft Store app detected. Check the Store for newer versions if needed." -ForegroundColor Yellow
            }
            $InstalledList.Add($Pkg)
        }
        else {
            Write-Host "[INSTALL] $Pkg" -ForegroundColor Red
            $MissingList.Add($Pkg)
        }
    }

    return [pscustomobject]@{
        Installed = $InstalledList
        Upgrade = $UpgradeList
        Missing = $MissingList
    }
}

function Invoke-AppInstallation {
    param(
        [string[]]$PackageIds,
        [string]$Mode
    )

    foreach ($Id in $PackageIds) {
        Write-Host "`n[*] Executing $Mode for: $Id..." -ForegroundColor Cyan
        if ($Mode -eq 'Install') {
            winget install --id $Id --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
        }
        else {
            winget upgrade --id $Id --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
        }
    }
}

Write-Host "`n[*] Querying installed packages and pending upgrades..." -ForegroundColor Cyan

$RuntimeStatus = Get-PackageStatus -PackageList $SystemRuntimes -SectionName 'SYSTEM RUNTIMES'
$EssentialStatus = Get-PackageStatus -PackageList $EssentialApps -SectionName 'ESSENTIAL APPLICATIONS'
$OptionalStatus = Get-PackageStatus -PackageList $OptionalApps -SectionName 'OPTIONAL APPLICATIONS'

$AllMissing = @($RuntimeStatus.Missing + $EssentialStatus.Missing + $OptionalStatus.Missing)
$AllUpgrade = @($RuntimeStatus.Upgrade + $EssentialStatus.Upgrade + $OptionalStatus.Upgrade)
$AllOk = @($RuntimeStatus.Installed + $EssentialStatus.Installed + $OptionalStatus.Installed)

Write-Host "`n=====================================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "[OK]     $($AllOk.Count)" -ForegroundColor Green
Write-Host "[INSTALL] $($AllMissing.Count)" -ForegroundColor Red
Write-Host "[UPDATE]  $($AllUpgrade.Count)" -ForegroundColor Yellow
Write-Host "=====================================================" -ForegroundColor Cyan

if ($AllMissing.Count -gt 0) {
    if ($AutoApprove) {
        Invoke-AppInstallation -PackageIds $AllMissing -Mode 'Install'
    }
    else {
        $InstallPrompt = Read-Host 'Install missing packages? (y/n)'
        if ($InstallPrompt.Trim().ToLower() -eq 'y') {
            Invoke-AppInstallation -PackageIds $AllMissing -Mode 'Install'
        }
    }
}

if ($AllUpgrade.Count -gt 0) {
    if ($AutoApprove) {
        Invoke-AppInstallation -PackageIds $AllUpgrade -Mode 'Upgrade'
    }
    else {
        $UpgradePrompt = Read-Host 'Update available packages? (y/n)'
        if ($UpgradePrompt.Trim().ToLower() -eq 'y') {
            Invoke-AppInstallation -PackageIds $AllUpgrade -Mode 'Upgrade'
        }
    }
}

if ($AllMissing.Count -eq 0 -and $AllUpgrade.Count -eq 0) {
    Write-Host "`n[OK] All essential and optional packages are up to date." -ForegroundColor Green
}

$env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')

Write-Host "`nPress Enter to exit..." -ForegroundColor Gray
Read-Host | Out-Null
