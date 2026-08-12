@echo off
setlocal

rem Run the PowerShell script with administrator privileges.
rem The elevated PowerShell window uses -NoExit so the result stays visible.

set "SCRIPT=%~dp0edge_disable_global_media_controls.ps1"
set "ARGS=%*"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
 "$script = $env:SCRIPT; $argsText = $env:ARGS; $argumentList = '-NoProfile -ExecutionPolicy Bypass -NoExit -File \"' + $script + '\"'; if ($argsText) { $argumentList += ' ' + $argsText }; Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') -Verb RunAs -WorkingDirectory (Split-Path -Parent $script) -ArgumentList $argumentList"

endlocal
