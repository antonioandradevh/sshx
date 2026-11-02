@echo off
setlocal
set "SCRIPT=%~dp0bin\xsshx.ps1"
powershell.exe -NoLogo -NoExit -ExecutionPolicy Bypass -File "%SCRIPT%" %*
endlocal
