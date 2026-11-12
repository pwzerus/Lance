@echo off
setlocal
set "GALUMU_LAUNCH=%~dp0builds\LanceAndLaurel-v0.4.42-r2\LanceAndLaurel.exe"
if not exist "%GALUMU_LAUNCH%" (
 echo The latest game package is missing. Restore the complete v0.4.42-r2 folder in builds.
 pause
 exit /b 2
)
start "" "%GALUMU_LAUNCH%"
