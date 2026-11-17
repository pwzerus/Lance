@echo off
setlocal
set "GALUMU_LAUNCH=%~dp0builds\LanceAndLaurel-v0.4.53-c1\LanceAndLaurel.exe"
if not exist "%GALUMU_LAUNCH%" (
 echo The latest game package is missing. Restore the complete v0.4.53-c1 folder in builds.
 pause
 exit /b 2
)
start "" "%GALUMU_LAUNCH%"
