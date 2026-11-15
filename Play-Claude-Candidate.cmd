@echo off
rem Claude ART-090 through FEEL-097 candidate, checkpointed by Codex SYNC-098.
rem v0.4.50-c1 is pending independent acceptance; use the root memory protector.
rem The official release entry remains Play-Latest.cmd (Codex packaging).
setlocal
set "GALUMU_CANDIDATE=%~dp0builds\LanceAndLaurel-v0.4.50-c1\runtime\LanceAndLaurel.exe"
if not exist "%GALUMU_CANDIDATE%" (
 echo The v0.4.50-c1 candidate is missing.
 pause
 exit /b 2
)
"%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe" -NoProfile -File "%~dp0Start-MemoryBound.ps1" -Executable "%GALUMU_CANDIDATE%" -TimeoutSeconds 0
if errorlevel 1 (
 echo Game stopped or launch refused by the resource protector. See the message above.
 pause
)
