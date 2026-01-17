@echo off
REM 批处理文件：调用PowerShell脚本转换CSV编码
REM 使用方法：双击此文件或在cmd中运行

setlocal enabledelayedexpansion

REM 获取当前脚本所在目录
set "scriptDir=%~dp0"

REM 调用PowerShell脚本
powershell -NoProfile -ExecutionPolicy Bypass -File "%scriptDir%convert_csv_utf8.ps1"

pause
