@echo off
"%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe" -NoProfile -File "%~dp0Start-MemoryBound.ps1" -Executable "%~dp0builds\LanceAndLaurel-v0.4.18-memory2\LanceAndLaurel.exe" -Arguments "-- --test-profile" -TimeoutSeconds 60
if errorlevel 1 pause
