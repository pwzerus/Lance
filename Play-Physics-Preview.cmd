@echo off
setlocal
set "GALUMU_LAUNCH=%~dp0builds\LanceAndLaurel-v0.5.0-c3\LanceAndLaurel.exe"
if not exist "%GALUMU_LAUNCH%" (
 echo The physics preview package is missing. Restore the complete v0.5.0-c3 folder in builds.
 pause
 exit /b 2
)
start "" "%GALUMU_LAUNCH%"
