@echo off
setlocal
cd /d "%~dp0"

echo ========================================================
echo   GBK (Excel) to UTF-8 No BOM Converter
echo ========================================================
echo.
echo Target: %CD%
echo WARNING: This script assumes source files are GBK/ANSI.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$gbk = [System.Text.Encoding]::GetEncoding(936); " ^
    "$utf8NoBom = New-Object System.Text.UTF8Encoding $False; " ^
    "$path = Get-Location; " ^
    "$files = Get-ChildItem -Path $path -Filter *.csv -Recurse; " ^
    "if ($files.Count -eq 0) { Write-Host 'No .csv files found.' -ForegroundColor Yellow; exit } " ^
    "foreach ($f in $files) { " ^
    "   try { " ^
    "       $content = [System.IO.File]::ReadAllText($f.FullName, $gbk); " ^
    "       [System.IO.File]::WriteAllText($f.FullName, $content, $utf8NoBom); " ^
    "       Write-Host 'Converted: ' $f.FullName.Substring($path.Path.Length + 1) -ForegroundColor Green; " ^
    "   } catch { " ^
    "       Write-Host 'Error: ' $f.Name ' (Check file permissions)' -ForegroundColor Red; " ^
    "   } " ^
    "}"

echo.
echo ========================================================
echo Done.
echo ========================================================
pause