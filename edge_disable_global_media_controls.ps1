#requires -version 5.1
# Edge Global Media Controls disable script.
# Windows PowerShell 5.1 compatible. ASCII source only.

param(
    [switch]$Undo,
    [switch]$RestartEdge,
    [switch]$DisableRestartApps
)

$Version = '1.4.6'
$Changes = New-Object System.Collections.Generic.List[string]

function Add-Change {
    param([string]$Text)
    if (-not [string]::IsNullOrWhiteSpace($Text)) {
        [void]$script:Changes.Add($Text)
    }
}

$Flag = '--disable-features=GlobalMediaControls'
$Shell = New-Object -ComObject WScript.Shell
$script:EdgeExe = $null

# Automatic UAC elevation.
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    # Only use variables that are populated when PowerShell is actually running a .ps1 file.
    # Do not use Join-Path with an empty $PSScriptRoot.
    $scriptPath = $PSCommandPath
    if ([string]::IsNullOrWhiteSpace($scriptPath)) {
        $scriptPath = $MyInvocation.MyCommand.Path
    }

    if ([string]::IsNullOrWhiteSpace($scriptPath) -or -not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        Write-Host 'ERROR: The script file path is unavailable.'
        Write-Host 'Run the downloaded .ps1 file directly; do not paste its contents into the PowerShell console.'
        Read-Host 'Press Enter to close' | Out-Null
        exit 1
    }

    $scriptPath = (Resolve-Path -LiteralPath $scriptPath -ErrorAction Stop).Path
    $workingDirectory = Split-Path -Parent -Path $scriptPath
    $quotedScriptPath = '"' + $scriptPath + '"'
    $argumentList = '-NoProfile -ExecutionPolicy Bypass -File ' + $quotedScriptPath

    if ($Undo) { $argumentList += ' -Undo' }
    if ($RestartEdge) { $argumentList += ' -RestartEdge' }
    if ($DisableRestartApps) { $argumentList += ' -DisableRestartApps' }

    try {
        Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Verb RunAs -WorkingDirectory $workingDirectory -ArgumentList $argumentList -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Host ("ERROR: UAC elevation failed: {0}" -f $_.Exception.Message)
        Read-Host 'Press Enter to close' | Out-Null
        exit 1
    }
    exit 0
}

function Remove-OurFlag {
    param([AllowEmptyString()][string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    return ($Value -replace '(?<!\S)--disable-features=GlobalMediaControls(?!\S)', '').Trim()
}

function Edit-ShortcutArguments {
    param([AllowEmptyString()][string]$Value)
    $clean = Remove-OurFlag $Value
    if ($Undo) { return $clean }
    return ("{0} {1}" -f $Flag, $clean).Trim()
}

function Edit-CommandLine {
    param([AllowEmptyString()][string]$Value)
    $clean = Remove-OurFlag $Value
    if ($Undo) { return $clean }
    $match = [regex]::Match($clean, '(?i)^(?<exe>".*?msedge\.exe"|[^\s"]*msedge\.exe)(?<rest>.*)$')
    if ($match.Success) { return ("{0} {1}{2}" -f $match.Groups['exe'].Value, $Flag, $match.Groups['rest'].Value).Trim() }
    return $clean
}

function Get-EdgeExe {
    if ($script:EdgeExe -and (Test-Path -LiteralPath $script:EdgeExe)) { return $script:EdgeExe }
    foreach ($path in @(
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:LocalAppData\Microsoft\Edge\Application\msedge.exe"
    )) {
        if ($path -and (Test-Path -LiteralPath $path)) { $script:EdgeExe = $path; return $path }
    }
    foreach ($key in @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe'
    )) {
        try {
            $path = (Get-ItemProperty -LiteralPath $key -ErrorAction Stop).'(default)'
            if ($path -and (Test-Path -LiteralPath $path)) { $script:EdgeExe = $path; return $path }
        }
        catch {}
    }
    return $null
}

$ShortcutDirs = @(
    [Environment]::GetFolderPath('Desktop'),
    [Environment]::GetFolderPath('CommonDesktopDirectory'),
    "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar",
    [Environment]::GetFolderPath('Programs'),
    [Environment]::GetFolderPath('CommonPrograms')
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique

function Test-RoundedCornerProjectActive {
    $patterns = @('msForceNoRoundedCornerAndMargin','msVisualRejuvRounding','msOmniboxFocusRingRoundEmphasize')
    foreach ($dir in $ShortcutDirs) {
        foreach ($file in (Get-ChildItem -LiteralPath $dir -Filter '*.lnk' -Recurse -ErrorAction SilentlyContinue)) {
            try {
                $link = $Shell.CreateShortcut($file.FullName)
                if ($link.TargetPath -notlike '*msedge.exe') { continue }
                foreach ($pattern in $patterns) { if ([string]$link.Arguments -like "*$pattern*") { return $true } }
            }
            catch {}
        }
    }
    foreach ($root in @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\Run')) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        foreach ($name in ((Get-Item -LiteralPath $root).GetValueNames() | Where-Object { $_ -like 'MicrosoftEdgeAutoLaunch*' })) {
            try {
                $value = [string](Get-ItemProperty -LiteralPath $root -Name $name).$name
                foreach ($pattern in $patterns) { if ($value -like "*$pattern*") { return $true } }
            }
            catch {}
        }
    }
    foreach ($className in @('MSEdgeHTM','microsoft-edge','microsoft-edge-holographic')) {
        $key = "Registry::HKEY_CLASSES_ROOT\$className\shell\open\command"
        if (-not (Test-Path -LiteralPath $key)) { continue }
        try {
            $value = [string](Get-ItemProperty -LiteralPath $key).'(default)'
            foreach ($pattern in $patterns) { if ($value -like "*$pattern*") { return $true } }
        }
        catch {}
    }
    return $false
}

Write-Host ''
Write-Host "edge_disable_global_media_controls.ps1 v$Version"
Write-Host ''

# Shortcuts.
foreach ($dir in $ShortcutDirs) {
    foreach ($file in (Get-ChildItem -LiteralPath $dir -Filter '*.lnk' -Recurse -ErrorAction SilentlyContinue)) {
        try {
            $link = $Shell.CreateShortcut($file.FullName)
            if ($link.TargetPath -notlike '*msedge.exe') { continue }
            $script:EdgeExe = $link.TargetPath
            $old = [string]$link.Arguments
            $new = Edit-ShortcutArguments $old
            if ($old -eq $new) { Write-Host ("Already OK: shortcut {0}" -f $file.FullName); continue }
            $link.Arguments = $new
            $link.Save()
            if ($Undo) { $message = ("Reverted: shortcut {0}" -f $file.FullName) } else { $message = ("Patched: shortcut {0}" -f $file.FullName) }
            Write-Host $message
            Add-Change $message
        }
        catch { Write-Host ("Failed: shortcut {0} - {1}" -f $file.FullName, $_.Exception.Message) }
    }
}

# Startup Boost autorun entries.
foreach ($root in @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\Run')) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    foreach ($name in ((Get-Item -LiteralPath $root).GetValueNames() | Where-Object { $_ -like 'MicrosoftEdgeAutoLaunch*' })) {
        try {
            $old = [string](Get-ItemProperty -LiteralPath $root -Name $name).$name
            $new = Edit-CommandLine $old
            if ($old -eq $new) { Write-Host ("Already OK: startup entry {0}" -f $name); continue }
            Set-ItemProperty -LiteralPath $root -Name $name -Value $new -ErrorAction Stop
            if ($Undo) { $message = ("Reverted: startup entry {0}" -f $name) } else { $message = ("Patched: startup entry {0}" -f $name) }
            Write-Host $message
            Add-Change $message
        }
        catch { Write-Host ("Failed: startup entry {0} - {1}" -f $name, $_.Exception.Message) }
    }
}

# Protocol associations.
foreach ($className in @('MSEdgeHTM','microsoft-edge','microsoft-edge-holographic')) {
    $key = "Registry::HKEY_CLASSES_ROOT\$className\shell\open\command"
    if (-not (Test-Path -LiteralPath $key)) { continue }
    try {
        $old = [string](Get-ItemProperty -LiteralPath $key).'(default)'
        $new = Edit-CommandLine $old
        if ($old -eq $new) { Write-Host ("Already OK: protocol {0}" -f $className); continue }
        Set-ItemProperty -LiteralPath $key -Name '(default)' -Value $new -ErrorAction Stop
        if ($Undo) { $message = ("Reverted: protocol {0}" -f $className) } else { $message = ("Patched: protocol {0}" -f $className) }
        Write-Host $message
        Add-Change $message
    }
    catch { Write-Host ("Failed: protocol {0} - {1}" -f $className, $_.Exception.Message) }
}

# Startup Boost policy.
$policyKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$policyValue = $null
try { $policyValue = (Get-ItemProperty -LiteralPath $policyKey -Name StartupBoostEnabled -ErrorAction Stop).StartupBoostEnabled } catch {}

if ($Undo) {
    if ($null -eq $policyValue) {
        Write-Host 'Already OK: StartupBoostEnabled is not set.'
    }
    elseif (Test-RoundedCornerProjectActive) {
        Write-Host 'Keeping StartupBoostEnabled=0 for compatibility with the rounded-corner project.'
    }
    else {
        try {
            Remove-ItemProperty -LiteralPath $policyKey -Name StartupBoostEnabled -ErrorAction Stop
            $message = 'Reverted: StartupBoostEnabled'
            Write-Host $message
            Add-Change $message
        }
        catch { Write-Host ("Failed: StartupBoostEnabled - {0}" -f $_.Exception.Message) }
    }
}
elseif ($policyValue -eq 0) {
    Write-Host 'Already OK: StartupBoostEnabled=0'
}
else {
    try {
        if (-not (Test-Path -LiteralPath $policyKey)) { New-Item -Path $policyKey -Force -ErrorAction Stop | Out-Null }
        Set-ItemProperty -LiteralPath $policyKey -Name StartupBoostEnabled -Value 0 -Type DWord -ErrorAction Stop
        $message = 'Patched: StartupBoostEnabled=0'
        Write-Host $message
        Add-Change $message
    }
    catch { Write-Host ("Failed: StartupBoostEnabled - {0}" -f $_.Exception.Message) }
}

# Windows RestartApps.
$winlogonKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon'
$restartApps = $null
try { $restartApps = (Get-ItemProperty -LiteralPath $winlogonKey -Name RestartApps -ErrorAction Stop).RestartApps } catch {}

if (-not $Undo -and $restartApps -eq 1) {
    if ($DisableRestartApps) {
        try {
            Set-ItemProperty -LiteralPath $winlogonKey -Name RestartApps -Value 0 -Type DWord -ErrorAction Stop
            $message = 'Patched: Windows RestartApps=0'
            Write-Host $message
            Add-Change $message
        }
        catch { Write-Host ("Failed: Windows RestartApps - {0}" -f $_.Exception.Message) }
    }
    else {
        Write-Host 'Warning: Windows RestartApps is enabled.'
        Write-Host 'Use -DisableRestartApps to disable it.'
    }
}

# Optional Edge restart.
if ($RestartEdge) {
    Write-Host 'Restarting Edge...'
    $processes = Get-Process -Name msedge -ErrorAction SilentlyContinue
    if ($processes) {
        $processes | Where-Object { $_.MainWindowHandle -ne 0 } | ForEach-Object { $null = $_.CloseMainWindow() }
        $deadline = (Get-Date).AddSeconds(15)
        while ((Get-Process -Name msedge -ErrorAction SilentlyContinue) -and ((Get-Date) -lt $deadline)) { Start-Sleep -Milliseconds 500 }
        Get-Process -Name msedge -ErrorAction SilentlyContinue | Stop-Process -Force -Confirm:$false
        Start-Sleep -Seconds 2
    }
    $exe = Get-EdgeExe
    if ($exe) {
        if ($Undo) { Start-Process -FilePath $exe -ArgumentList '--restore-last-session' } else { Start-Process -FilePath $exe -ArgumentList "$Flag --restore-last-session" }
        $message = 'Edge restarted.'
        Write-Host $message
        Add-Change $message
    }
    else { Write-Host 'ERROR: msedge.exe could not be located.' }
}

Write-Host ''
Write-Host 'Changes made:'
if ($script:Changes.Count -eq 0) { Write-Host '  (none)' } else { foreach ($item in $script:Changes) { Write-Host ("  - {0}" -f $item) } }
Write-Host ''
Write-Host 'Done.'
Read-Host 'Press Enter to close' | Out-Null
