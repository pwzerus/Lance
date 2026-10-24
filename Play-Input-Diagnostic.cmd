@echo off
start "" "%~dp0builds\qa-v04-release\LanceAndLaurel-QA.exe" --script "%~dp0game\tests\manual_input_probe_v04.gd" --log-file "%~dp0docs\development\logs\v04-user-mouse-runtime.log" -- --test-profile
