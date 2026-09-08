# Winget LTSC Setup

A PowerShell automation script for setting up a Windows LTSC / Windows 10 / Windows 11 machine with commonly used productivity, system, and utility applications.

This script checks whether WinGet is available, bootstraps it if needed, reviews installed packages, and offers to install or upgrade missing packages from a curated list.

## What it does

- Verifies administrator privileges
- Ensures WinGet is installed and working
- Refreshes WinGet sources
- Detects installed runtime components and software
- Lists:
  - installed apps
  - apps needing upgrade
  - missing apps
- Prompts before installing or upgrading packages
- Supports automatic approval via the `-AutoApprove` switch

## Included categories

### System runtimes
- Microsoft App Installer
- .NET Desktop Runtime 8/9
- Visual C++ Redistributables
- DirectX / WinUI / App Runtime dependencies
- Python 3.13

### Essential applications
- Bitwarden
- Brave
- Flow Launcher
- Git
- Google Chrome
- Microsoft Edge
- PowerShell
- Visual Studio Code
- Oh My Posh
- Telegram
- VLC
- 7-Zip
- qBittorrent
- Rufus
- Ventoy
- WinRAR
- QuickLook
- K-Lite Codec Pack
- Signal
- Notepad++
- BleachBit
- OnlyOffice
- Discord
- Windows Terminal
- Python 3.13

### Optional applications
- Microsoft App Installer
- NetSpeedTray
- iTunes
- Java Runtime Environment
- QuickTime
- OpenAL
- Sublime Text 4
- WhatsApp

## Requirements

- Windows 10 / Windows 11 / LTSC
- PowerShell 5.1 or newer
- Administrator privileges
- Internet access to download WinGet dependencies and packages

## Usage

Open PowerShell as Administrator and run:

```powershell
./winget-LTSC-Setup.ps1
```

To skip prompts and automatically approve all installs/upgrades:

```powershell
./winget-LTSC-Setup.ps1 -AutoApprove
```

## Notes

- The script uses `winget` for package installation and upgrade checks.
- Some packages may be installed via Microsoft Store or AppX package detection logic.
- The script waits for Enter before closing, so you can review output.

## License

This project is provided as-is for personal and educational use. Please review and confirm package licensing terms before installing software on managed devices.

## Contributing

If you want to improve the package list, add detection logic, or improve the user experience, feel free to fork the repository and submit a pull request.
