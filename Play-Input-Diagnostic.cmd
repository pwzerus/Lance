@echo off
start "" "%~dp0builds\qa-v03\LanceAndLaurel-QA.exe" --script "%~dp0game\tests\manual_input_probe_v03.gd" --log-file "%~dp0docs\development\logs\v03-user-mouse-runtime.log" -- --test-profile
