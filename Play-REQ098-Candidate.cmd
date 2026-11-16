@echo off
setlocal
rem REQ-098 review candidate. Heraldry slot decision is still pending.
set "GALUMU_CANDIDATE=%~dp0builds\LanceAndLaurel-v0.4.51-c1\LanceAndLaurel.exe"
if not exist "%GALUMU_CANDIDATE%" (
 echo The REQ-098 candidate has not been packaged yet.
 pause
 exit /b 2
)
start "" "%GALUMU_CANDIDATE%"
