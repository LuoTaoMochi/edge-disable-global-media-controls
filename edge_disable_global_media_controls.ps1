#requires -version 5.1
<#
    Edge Global Media Controls 禁用脚本
    One-click disable of Chromium/Edge Global Media Controls

    作用：
      将以下参数注入 Edge 的常用启动入口：
        --disable-features=GlobalMediaControls

    用法：
      .\edge_disable_global_media_controls.ps1
          应用修改

      .\edge_disable_global_media_controls.ps1 -RestartEdge
          应用修改并立即重启 Edge

      .\edge_disable_global_media_controls.ps1 -Undo
          撤销本脚本做出的修改

      .\edge_disable_global_media_controls.ps1 -DisableRestartApps
          应用修改，同时关闭 Windows“重新启动应用”

    建议：
      使用“以管理员身份运行”的 PowerShell 执行，以便修改
      HKCR 协议关联和 HKLM 启动策略。

    注意：
      本脚本只移除/恢复它自己注入的 GlobalMediaControls 参数。
      不会修改任何其它 Edge 启动参数，也不会处理其它 --disable-features 参数。
      与 MSCMonster/edge-no-rounded-corners 可同时使用。
#>

param(
    [switch]$Undo,
    [switch]$RestartEdge,
    [switch]$DisableRestartApps
)

$VERSION = '1.0.0'
$flag = '--disable-features=GlobalMediaControls'
$marker = 'GlobalMediaControls'

# Compatibility guarantee:
# Only this exact standalone flag belongs to this script.
# The rounded-corner project uses:
#   --enable-features=msForceNoRoundedCornerAndMargin
#   --disable-features=msVisualRejuvRounding
# Those parameters are never parsed, rewritten, merged, or removed here.

$lang = switch -Regex ([System.Globalization.CultureInfo]::CurrentUICulture.Name) {
    '^zh' { 'zh' }
    '^ja' { 'ja' }
    default { 'en' }
}

$T = @{
    zh = @{
        Patched = '已修改'; Reverted = '已撤销'; AlreadyOk = '无需修改'; Failed = '修改失败'; Updated = '已更新'; NeedAdmin = '(需要管理员权限)'; MaybePerm = '(权限不足?)'; Startup = '启动项'; Protocol = '协议命令'; Shortcut = '快捷方式'; Policy = '启动加速策略'; RestartApps = '登录后重启应用'; RestartAppsWarn = '警告：Windows“重新启动应用”处于开启状态。系统重启后自动恢复的 Edge 可能不带此参数，Global Media Controls 可能恢复。可加 -DisableRestartApps 关闭该功能。'; Restarted = 'Edge 已重启'; ExeNotFound = '未找到 msedge.exe，请手动重启 Edge'; Done = '完成。'
    }
    ja = @{
        Patched = '変更しました'; Reverted = '元に戻しました'; AlreadyOk = '変更不要'; Failed = '変更に失敗しました'; Updated = '更新しました'; NeedAdmin = '（管理者権限が必要）'; MaybePerm = '（権限不足の可能性）'; Startup = 'スタートアップ'; Protocol = 'プロトコルコマンド'; Shortcut = 'ショートカット'; Policy = 'Startup Boost ポリシー'; RestartApps = 'サインイン後のアプリ再起動'; RestartAppsWarn = '警告：Windows の「アプリの再起動」が有効です。再起動後の Edge にパラメータが付かない場合があります。-DisableRestartApps で無効化できます。'; Restarted = 'Edge を再起動しました'; ExeNotFound = 'msedge.exe が見つかりません。手動で Edge を再起動してください'; Done = '完了。'
    }
    en = @{
        Patched = 'Patched'; Reverted = 'Reverted'; AlreadyOk = 'Already OK'; Failed = 'Failed'; Updated = 'Updated'; NeedAdmin = '(administrator rights required)'; MaybePerm = '(insufficient permissions?)'; Startup = 'startup entry'; Protocol = 'protocol command'; Shortcut = 'shortcut'; Policy = 'startup boost policy'; RestartApps = 'restart apps after sign-in'; RestartAppsWarn = 'Warning: Windows "restart apps after sign-in" is ON. A restored Edge process may not carry this flag. Pass -DisableRestartApps to turn it off.'; Restarted = 'Edge restarted'; ExeNotFound = 'msedge.exe not found; please restart Edge manually'; Done = 'Done.'
    }
}[$lang]

"edge_disable_global_media_controls.ps1 v$VERSION"

function Remove-OurFlag([string]$v) {
    if ([string]::IsNullOrWhiteSpace($v)) { return '' }
    # Only remove our exact standalone flag. Never parse or rewrite other feature flags.
    $v = $v -replace '(?<!\S)--disable-features=GlobalMediaControls(?!\S)', ''
    return $v.Trim()
}

function Add-OurFlag([string]$v) {
    $clean = Remove-OurFlag $v
    if ($Undo) { return $clean }
    # Keep our flag independent from every other feature flag.
    return "$flag $clean".Trim()
}

function Get-ActionText([string]$old) {
    if ($Undo) { return $T.Reverted }
    if ($old -match '(?<!\S)--disable-features=GlobalMediaControls(?!\S)') { return $T.Updated }
    return $T.Patched
}

$edgeExe = $null

# 1. Common Edge shortcuts
$dirs = @(
    [Environment]::GetFolderPath('Desktop'),
    [Environment]::GetFolderPath('CommonDesktopDirectory'),
    "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar",
    [Environment]::GetFolderPath('Programs'),
    [Environment]::GetFolderPath('CommonPrograms')
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

try {
    $sh = New-Object -ComObject WScript.Shell
    foreach ($d in $dirs) {
        foreach ($f in (Get-ChildItem $d -Filter *.lnk -Recurse -ErrorAction SilentlyContinue)) {
            try {
                $lnk = $sh.CreateShortcut($f.FullName)
                if ($lnk.TargetPath -notlike '*msedge.exe') { continue }
                $edgeExe = $lnk.TargetPath
                $cur = [string]$lnk.Arguments
                $want = Add-OurFlag $cur
                if ($cur -eq $want) { "$($T.AlreadyOk): $($T.Shortcut) $($f.FullName)"; continue }
                $lnk.Arguments = $want
                $lnk.Save()
                "$(Get-ActionText $cur): $($T.Shortcut) $($f.FullName)"
            } catch { "$($T.Failed) $($T.MaybePerm): $($f.FullName)" }
        }
    }
} catch { "$($T.Failed): $($T.Shortcut)" }

# 2. Edge Startup Boost autorun entries
foreach ($rk in @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\Run')) {
    if (-not (Test-Path $rk)) { continue }
    try {
        foreach ($name in ((Get-Item $rk).GetValueNames() | Where-Object { $_ -like 'MicrosoftEdgeAutoLaunch*' })) {
            $v = (Get-ItemProperty $rk -Name $name).$name
            $want = Add-OurFlag ([string]$v)
            if ($v -eq $want) { "$($T.AlreadyOk): $($T.Startup) $name"; continue }
            try {
                Set-ItemProperty $rk -Name $name -Value $want -ErrorAction Stop
                "$(Get-ActionText $v): $($T.Startup) $name"
            } catch { "$($T.Failed) $($T.MaybePerm): $($T.Startup) $name" }
        }
    } catch { "$($T.Failed): $($T.Startup)" }
}

# 3. Edge protocol associations
foreach ($cls in @('MSEdgeHTM', 'microsoft-edge', 'microsoft-edge-holographic')) {
    $key = "Registry::HKEY_CLASSES_ROOT\$cls\shell\open\command"
    if (-not (Test-Path $key)) { continue }
    try {
        $v = (Get-ItemProperty $key).'(default)'
        $want = Add-OurFlag ([string]$v)
        if ($v -eq $want) { "$($T.AlreadyOk): $($T.Protocol) $cls"; continue }
        Set-ItemProperty $key -Name '(default)' -Value $want -ErrorAction Stop
        "$(Get-ActionText $v): $($T.Protocol) $cls"
    } catch { "$($T.Failed) $($T.NeedAdmin): $($T.Protocol) $cls" }
}

# 4. Disable Startup Boost so Edge does not reuse a parameter-less background process
$polKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$polVal = (Get-ItemProperty $polKey -Name StartupBoostEnabled -ErrorAction SilentlyContinue).StartupBoostEnabled
if ($Undo) {
    if ($null -eq $polVal) { "$($T.AlreadyOk): $($T.Policy)" }
    else {
        try { Remove-ItemProperty $polKey -Name StartupBoostEnabled -ErrorAction Stop; "$($T.Reverted): $($T.Policy) StartupBoostEnabled" }
        catch { "$($T.Failed) $($T.NeedAdmin): $($T.Policy)" }
    }
} elseif ($polVal -eq 0) {
    "$($T.AlreadyOk): $($T.Policy)"
} else {
    try {
        if (-not (Test-Path $polKey)) { New-Item $polKey -Force -ErrorAction Stop | Out-Null }
        Set-ItemProperty $polKey -Name StartupBoostEnabled -Value 0 -Type DWord -ErrorAction Stop
        "$($T.Patched): $($T.Policy) StartupBoostEnabled=0"
    } catch { "$($T.Failed) $($T.NeedAdmin): $($T.Policy)" }
}

# 5. Windows restart-apps behavior
$wlKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon'
$ra = (Get-ItemProperty $wlKey -Name RestartApps -ErrorAction SilentlyContinue).RestartApps
if (-not $Undo -and $ra -eq 1) {
    if ($DisableRestartApps) {
        try {
            Set-ItemProperty $wlKey -Name RestartApps -Value 0 -Type DWord -ErrorAction Stop
            "$($T.Patched): $($T.RestartApps) RestartApps=0"
        } catch { "$($T.Failed): $($T.RestartApps)" }
    } else { $T.RestartAppsWarn }
}

# 6. Optionally restart Edge
if ($RestartEdge) {
    $procs = Get-Process msedge -ErrorAction SilentlyContinue
    if ($procs) {
        $procs | Where-Object { $_.MainWindowHandle -ne 0 } | ForEach-Object { $null = $_.CloseMainWindow() }
        $deadline = (Get-Date).AddSeconds(15)
        while ((Get-Process msedge -ErrorAction SilentlyContinue) -and ((Get-Date) -lt $deadline)) { Start-Sleep -Milliseconds 500 }
        Get-Process msedge -ErrorAction SilentlyContinue | Stop-Process -Force -Confirm:$false
        Start-Sleep -Seconds 2
    }
    if (-not $edgeExe) { $edgeExe = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe' -ErrorAction SilentlyContinue).'(default)' }
    if (-not $edgeExe) { $edgeExe = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe' -ErrorAction SilentlyContinue).'(default)' }
    if ($edgeExe -and (Test-Path $edgeExe)) {
        if ($Undo) { Start-Process $edgeExe -ArgumentList '--restore-last-session' }
        else { Start-Process $edgeExe -ArgumentList "$flag --restore-last-session" }
        $T.Restarted
    } else { $T.ExeNotFound }
}

$T.Done
