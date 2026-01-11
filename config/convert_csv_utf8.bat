@echo off
setlocal
cd /d "%~dp0"

echo ========================================================
echo   CSV Encoding Converter (GBK to UTF-8 No BOM)
echo ========================================================
echo.
echo Target: %CD%
echo.
echo WARNING: This script converts GBK/ANSI encoded files to UTF-8.
echo          DO NOT run this on files that are already UTF-8!
echo          Running on UTF-8 files will corrupt Chinese characters.
echo.
echo Press Ctrl+C to cancel, or any key to continue...
pause > nul

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
echo Done. Files have been converted from GBK to UTF-8.
echo ========================================================
pause
