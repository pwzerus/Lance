@echo off
"%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe" -NoProfile -File "%~dp0Start-MemoryBound.ps1" -Executable "%~dp0builds\LanceAndLaurel-v0.4.39-r2\LanceAndLaurel.exe" -TimeoutSeconds 0
if errorlevel 1 (
 echo Game stopped or launch refused by the resource protector. See the message above.
 pause
)
