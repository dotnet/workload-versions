@echo off
powershell -NoLogo -NoProfile -ExecutionPolicy ByPass -Command "& """%~dp0eng\common\build.ps1""" -build -restore -msbuildEngine vs %*"
exit /b %ErrorLevel%
