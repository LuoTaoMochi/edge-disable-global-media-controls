#requires -version 5.1
<#
    Edge Global Media Controls 禁用脚本
    One-click disable of Chromium/Edge Global Media Controls

    作用：
      将以下命令行特性开关注入 Edge 的常用启动入口：
        --disable-features=GlobalMediaControls

    用法 Usage (建议管理员 PowerShell / run as Administrator):
      .\edge_disable_global_media_controls.ps1
          应用修改 / apply

      .\edge_disable_global_media_controls.ps1 -RestartEdge
          应用并立即重启 Edge / apply & restart

      .\edge_disable_global_media_controls.ps1 -DisableRestartApps
          同时关闭 Windows “重新启动应用”

      .\edge_disable_global_media_controls.ps1 -Undo
          撤销本脚本修改 / revert

    兼容性：
      本脚本的启动入口处理方式与 MSCMonster/edge-no-rounded-corners 保持一致：
      快捷方式、Startup Boost、自启动项、Edge 协议关联、StartupBoostEnabled
      以及 Windows RestartApps 均按同一思路处理。

      本脚本只管理 GlobalMediaControls，不会解析、合并、删除或修改
      msForceNoRoundedCornerAndMargin / msVisualRejuvRounding 等其它 Feature。

      两个项目共享 StartupBoostEnabled=0。-Undo 时会检测圆角项目是否仍在
      使用相关启动参数；若仍在使用，不会删除共享策略。
#>

param(
    [switch]$Undo,
    [switch]$RestartEdge,
    [switch]$DisableRestartApps
)

$VERSION = '1.2.0'
$flag = '--disable-features=GlobalMediaControls'

# ============================================================
# Localization
# ============================================================

$lang = switch -Regex ([System.Globalization.CultureInfo]::CurrentUICulture.Name) {
    '^zh' { 'zh' }
    '^ja' { 'ja' }
    default { 'en' }
}

$T = (@{
    zh = @{
        Patched = '已修改'; Reverted = '已撤销'; AlreadyOk = '无需修改'; Failed = '修改失败'
        Updated = '已更新'; NeedAdmin = '(需要管理员权限)'; MaybePerm = '(权限不足?)'
        Startup = '自启动项'; Protocol = '协议命令'; Shortcut = '快捷方式'; Policy = '启动加速策略'
        RestartApps = '登录后重启应用'
        RestartAppsWarn = '警告: Windows "重新启动应用" 处于开启状态, 系统重启后自动恢复的 Edge 不带本参数, Global Media Controls 可能恢复(手动重开 Edge 即可消除)。运行时加 -DisableRestartApps 可关闭该功能'
        SharedPolicy = '检测到圆角项目仍在使用 StartupBoostEnabled=0, 保留共享策略以确保兼容'
        Restarted = 'Edge 已重启并恢复会话'; ExeNotFound = '未找到 msedge.exe, 请手动重启 Edge'; Done = '完成。'
    }
    ja = @{
        Patched = '変更しました'; Reverted = '元に戻しました'; AlreadyOk = '変更不要'; Failed = '変更に失敗しました'
        Updated = '更新しました'; NeedAdmin = '（管理者権限が必要）'; MaybePerm = '（権限不足の可能性）'
        Startup = '自動起動エントリ'; Protocol = 'プロトコルコマンド'; Shortcut = 'ショートカット'; Policy = 'Startup Boost ポリシー'
        RestartApps = 'サインイン後のアプリ再起動'
        RestartAppsWarn = '警告: Windows の「アプリの再起動」が有効です。再起動後に自動復元される Edge にパラメータが付かず、Global Media Controls が復活する場合があります。-DisableRestartApps で無効化できます。'
        SharedPolicy = '角丸プロジェクトが StartupBoostEnabled=0 を使用中のため、互換性維持のため共有ポリシーを保持します。'
        Restarted = 'Edge を再起動し、セッションを復元しました'; ExeNotFound = 'msedge.exe が見つかりません。Edge を手動で再起動してください'; Done = '完了。'
    }
    en = @{
        Patched = 'Patched'; Reverted = 'Reverted'; AlreadyOk = 'Already OK'; Failed = 'Failed'
        Updated = 'Updated'; NeedAdmin = '(administrator rights required)'; MaybePerm = '(insufficient permissions?)'
        Startup = 'startup entry'; Protocol = 'protocol command'; Shortcut = 'shortcut'; Policy = 'startup boost policy'
        RestartApps = 'restart apps after sign-in'
        RestartAppsWarn = 'Warning: Windows "restart apps after sign-in" is ON. A restored Edge process may not carry this flag, so Global Media Controls may return. Pass -DisableRestartApps to turn it off.'
        SharedPolicy = 'The rounded-corner project still appears to use StartupBoostEnabled=0; keeping the shared policy for compatibility.'
        Restarted = 'Edge restarted with session restored'; ExeNotFound = 'msedge.exe not found, please restart Edge manually'; Done = 'Done.'
    }
})[$lang]

"edge_disable_global_media_controls.ps1 v$VERSION"

# ============================================================
# Our flag handling
# ============================================================

function Remove-OurFlag([string]$v) {
    if (-not $v) { return '' }

    # IMPORTANT:
    # Remove ONLY our exact standalone flag.
    # Do not parse or rewrite any other --disable-features argument.
    $v = $v -replace '(?<!\S)--disable-features=GlobalMediaControls(?!\S)', ''
    return $v.Trim()
}

function Edit-ShortcutArguments([string]$v) {
    $clean = Remove-OurFlag $v
    if ($Undo) { return $clean }
    return "$flag $clean".Trim()
}

function Edit-Command([string]$v) {
    $clean = Remove-OurFlag $v
    if ($Undo) { return $clean }

    # Match the original project's placement: executable first, then arguments.
    if ($clean -match 'msedge\.exe"') {
        return $clean.Replace('msedge.exe"', "msedge.exe`" $flag")
    }

    # Conservative fallback for an unquoted executable path.
    if ($clean -match '(?i)\bmsedge\.exe\b') {
        return $clean -replace '(?i)(\bmsedge\.exe\b)', ('$1 ' + $flag)
    }

    return $clean
}

function Get-ActionText([string]$old) {
    if ($Undo) { return $T.Reverted }
    if ($old -match '(?<!\S)--disable-features=GlobalMediaControls(?!\S)') { return $T.Updated }
    return $T.Patched
}

$edgeExe = $null

# ============================================================
# 1. Shortcuts: Desktop / Common Desktop / Taskbar / Start Menu
# ============================================================

$dirs = @(
    [Environment]::GetFolderPath('Desktop'),
    [Environment]::GetFolderPath('CommonDesktopDirectory'),
    "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar",
    [Environment]::GetFolderPath('Programs'),
    [Environment]::GetFolderPath('CommonPrograms')
) | Where-Object { $_ -and (Test-Path $_) }

$sh = New-Object -ComObject WScript.Shell
foreach ($d in $dirs) {
    foreach ($f in (Get-ChildItem $d -Filter *.lnk -Recurse -ErrorAction SilentlyContinue)) {
        $lnk = $sh.CreateShortcut($f.FullName)
        if ($lnk.TargetPath -notlike '*msedge.exe') { continue }

        $edgeExe = $lnk.TargetPath
        $cur = [string]$lnk.Arguments
        $want = Edit-ShortcutArguments $cur

        if ($cur -eq $want) {
            "$($T.AlreadyOk): $($T.Shortcut) $($f.FullName)"
            continue
        }

        try {
            $lnk.Arguments = $want
            $lnk.Save()
            "$(Get-ActionText $cur): $($T.Shortcut) $($f.FullName)"
        }
        catch {
            "$($T.Failed) $($T.MaybePerm): $($f.FullName)"
        }
    }
}

# ============================================================
# 2. Startup Boost autorun entries
# ============================================================

foreach ($rk in @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'
)) {
    if (-not (Test-Path $rk)) { continue }

    foreach ($name in ((Get-Item $rk).GetValueNames() | Where-Object { $_ -like 'MicrosoftEdgeAutoLaunch*' })) {
        $v = (Get-ItemProperty $rk -Name $name).$name
        $want = Edit-Command ([string]$v)

        if ($v -eq $want) {
            "$($T.AlreadyOk): $($T.Startup) $name"
            continue
        }

        try {
            Set-ItemProperty $rk -Name $name -Value $want -ErrorAction Stop
            "$(Get-ActionText $v): $($T.Startup) $name"
        }
        catch {
            "$($T.Failed): $($T.Startup) $name - $($_.Exception.Message)"
        }
    }
}

# ============================================================
# 3. Edge protocol associations
#    Same classes as edge-no-rounded-corners.
# ============================================================

foreach ($cls in @('MSEdgeHTM', 'microsoft-edge')) {
    $key = "Registry::HKEY_CLASSES_ROOT\$cls\shell\open\command"
    if (-not (Test-Path $key)) { continue }

    $v = (Get-ItemProperty $key).'(default)'
    $want = Edit-Command ([string]$v)

    if ($v -eq $want) {
        "$($T.AlreadyOk): $($T.Protocol) $cls"
        continue
    }

    try {
        Set-ItemProperty $key -Name '(default)' -Value $want -ErrorAction Stop
        "$(Get-ActionText $v): $($T.Protocol) $cls"
    }
    catch {
        "$($T.Failed) $($T.NeedAdmin): $($T.Protocol) $cls"
    }
}

# ============================================================
# 4. Startup Boost policy
#    This policy is shared with edge-no-rounded-corners.
# ============================================================

$polKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$polVal = (Get-ItemProperty $polKey -Name StartupBoostEnabled -ErrorAction SilentlyContinue).StartupBoostEnabled

function Test-RoundedCornerProjectActive {
    $patterns = @(
        'msForceNoRoundedCornerAndMargin',
        'msVisualRejuvRounding',
        'msOmniboxFocusRingRoundEmphasize'
    )

    foreach ($d in $dirs) {
        foreach ($f in (Get-ChildItem $d -Filter *.lnk -Recurse -ErrorAction SilentlyContinue)) {
            try {
                $lnk = $sh.CreateShortcut($f.FullName)
                if ($lnk.TargetPath -notlike '*msedge.exe') { continue }
                foreach ($p in $patterns) {
                    if ([string]$lnk.Arguments -like "*$p*") { return $true }
                }
            } catch { }
        }
    }

    foreach ($rk in @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'
    )) {
        if (-not (Test-Path $rk)) { continue }
        foreach ($name in ((Get-Item $rk).GetValueNames() | Where-Object { $_ -like 'MicrosoftEdgeAutoLaunch*' })) {
            $v = [string]((Get-ItemProperty $rk -Name $name).$name)
            foreach ($p in $patterns) {
                if ($v -like "*$p*") { return $true }
            }
        }
    }

    foreach ($cls in @('MSEdgeHTM', 'microsoft-edge')) {
        $key = "Registry::HKEY_CLASSES_ROOT\$cls\shell\open\command"
        if (-not (Test-Path $key)) { continue }
        try {
            $v = [string](Get-ItemProperty $key).'(default)'
            foreach ($p in $patterns) {
                if ($v -like "*$p*") { return $true }
            }
        } catch { }
    }

    return $false
}

if ($Undo) {
    if ($null -eq $polVal) {
        "$($T.AlreadyOk): $($T.Policy)"
    }
    elseif (Test-RoundedCornerProjectActive) {
        $T.SharedPolicy
    }
    else {
        try {
            Remove-ItemProperty $polKey -Name StartupBoostEnabled -ErrorAction Stop
            "$($T.Reverted): $($T.Policy) StartupBoostEnabled"
        }
        catch {
            "$($T.Failed) $($T.NeedAdmin): $($T.Policy)"
        }
    }
}
elseif ($polVal -eq 0) {
    "$($T.AlreadyOk): $($T.Policy)"
}
else {
    try {
        if (-not (Test-Path $polKey)) {
            New-Item $polKey -Force -ErrorAction Stop | Out-Null
        }
        Set-ItemProperty $polKey -Name StartupBoostEnabled -Value 0 -Type DWord -ErrorAction Stop
        "$($T.Patched): $($T.Policy) StartupBoostEnabled=0"
    }
    catch {
        "$($T.Failed) $($T.NeedAdmin): $($T.Policy)"
    }
}

# ============================================================
# 5. Windows "Restart apps after sign-in"
# ============================================================

$wlKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon'
$ra = (Get-ItemProperty $wlKey -Name RestartApps -ErrorAction SilentlyContinue).RestartApps

if (-not $Undo -and $ra -eq 1) {
    if ($DisableRestartApps) {
        try {
            Set-ItemProperty $wlKey -Name RestartApps -Value 0 -Type DWord -ErrorAction Stop
            "$($T.Patched): $($T.RestartApps) RestartApps=0"
        }
        catch {
            "$($T.Failed): $($T.RestartApps)"
        }
    }
    else {
        $T.RestartAppsWarn
    }
}

# ============================================================
# 6. Optional immediate Edge restart
# ============================================================

if ($RestartEdge) {
    $procs = Get-Process msedge -ErrorAction SilentlyContinue

    if ($procs) {
        # Graceful close first so the session can be saved, then terminate leftovers.
        $procs | Where-Object { $_.MainWindowHandle -ne 0 } | ForEach-Object { $null = $_.CloseMainWindow() }
        $deadline = (Get-Date).AddSeconds(15)
        while ((Get-Process msedge -ErrorAction SilentlyContinue) -and (Get-Date) -lt $deadline) {
            Start-Sleep -Milliseconds 500
        }
        Get-Process msedge -ErrorAction SilentlyContinue | Stop-Process -Force -Confirm:$false
        Start-Sleep -Seconds 2
    }

    if (-not $edgeExe) {
        $edgeExe = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe' -ErrorAction SilentlyContinue).'(default)'
    }

    if (-not $edgeExe) {
        $edgeExe = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe' -ErrorAction SilentlyContinue).'(default)'
    }

    if ($edgeExe -and (Test-Path $edgeExe)) {
        $restartArgs = if ($Undo) { '--restore-last-session' } else { "$flag --restore-last-session" }
        Start-Process $edgeExe -ArgumentList $restartArgs
        $T.Restarted
    }
    else {
        $T.ExeNotFound
    }
}

$T.Done
