@echo off
setlocal
set "SCRIPT=%~dp0bin\sshx.ps1"
powershell.exe -NoLogo -NoExit -ExecutionPolicy Bypass -File "%SCRIPT%" %*
endlocal
