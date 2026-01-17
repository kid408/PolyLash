# PowerShell脚本：将所有CSV文件转换为UTF-8 No BOM编码
# 使用方法：在PowerShell中运行此脚本

$csvFiles = Get-ChildItem -Path $PSScriptRoot -Filter "*.csv" -Recurse

foreach ($file in $csvFiles) {
    Write-Host "正在转换: $($file.FullName)"
    
    try {
        # 读取文件内容（自动检测编码）
        $content = Get-Content -Path $file.FullName -Encoding Default
        
        # 写入为UTF-8 No BOM
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllLines($file.FullName, $content, $utf8NoBom)
        
        Write-Host "✓ 转换成功: $($file.Name)" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ 转换失败: $($file.Name) - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n所有CSV文件转换完成！" -ForegroundColor Cyan
