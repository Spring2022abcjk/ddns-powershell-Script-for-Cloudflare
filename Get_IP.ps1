param(
    [string]$OutputFile,
    [string]$NetworkAdapter,
    [ValidateSet("IPv4", "IPv6", "All")]
    [string]$IPType = "All"
)

function Get-NetworkAdapters {
    return Get-CimInstance -Class Win32_NetworkAdapterConfiguration -Filter IPEnabled=$true |
        Select-Object Description, Index, @{Name='IPv4';Expression={$_.IPAddress | Where-Object {$_ -like '*.*'}}}, @{Name='IPv6';Expression={$_.IPAddress | Where-Object {$_ -like '*:*'}}}
}

function Show-NetworkAdapters {
    param($adapters)
    Write-Host "`n可用的网络适配器:"
    for ($i = 0; $i -lt $adapters.Count; $i++) {
        Write-Host "[$i] $($adapters[$i].Description)"
        $ipv4 = if ($adapters[$i].IPv4) { $adapters[$i].IPv4 -join ', ' } else { "无" }
        $ipv6 = if ($adapters[$i].IPv6) { $adapters[$i].IPv6 -join ', ' } else { "无" }
        Write-Host "    IPv4: $ipv4"
        Write-Host "    IPv6: $ipv6"
    }
}

function Get-SelectedIP {
    param($adapter, $ipType)
    
    switch ($ipType) {
        "IPv4" { return $adapter.IPv4 }
        "IPv6" { return $adapter.IPv6 }
        "All" { 
            $result = @()
            if ($adapter.IPv4) { $result += $adapter.IPv4 }
            if ($adapter.IPv6) { $result += $adapter.IPv6 }
            return $result
        }
    }
}

# 检查是否提供了命令行参数
$isCommandLineMode = $PSBoundParameters.Count -gt 0

if ($isCommandLineMode) {
    # 命令行模式
    if (-not $OutputFile -or -not $NetworkAdapter) {
        Write-Host "错误: 缺少必要参数。" -ForegroundColor Red
        Write-Host "用法: .\Get_IP.ps1 -OutputFile <文件路径> -NetworkAdapter <网卡名称或索引> [-IPType <IPv4|IPv6|All>]" -ForegroundColor Yellow
        exit 1
    }
    
    $adapters = Get-NetworkAdapters
    $selectedAdapter = $null
    
    # 检查是否为索引
    if ($NetworkAdapter -match '^\d+$') {
        $index = [int]$NetworkAdapter
        if ($index -ge 0 -and $index -lt $adapters.Count) {
            $selectedAdapter = $adapters[$index]
        }
    } else {
        # 按名称查找
        $selectedAdapter = $adapters | Where-Object { $_.Description -like "*$NetworkAdapter*" } | Select-Object -First 1
    }
    
    if (-not $selectedAdapter) {
        Write-Host "错误: 找不到指定的网络适配器。" -ForegroundColor Red
        exit 1
    }
    
    $selectedIP = Get-SelectedIP -adapter $selectedAdapter -ipType $IPType
    
    if (-not $selectedIP) {
        Write-Host "错误: 所选网卡没有符合条件的IP地址。" -ForegroundColor Red
        exit 1
    }
    
    try {
        $selectedIP | Set-Content -Path $OutputFile -Force
        Write-Host "IP地址已成功写入到: $OutputFile" -ForegroundColor Green
    } catch {
        Write-Host "错误: 无法写入文件 $OutputFile" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }
} else {
    # 交互模式
    Write-Host "DDNS IP 获取工具 - 交互模式" -ForegroundColor Cyan
    
    # 询问输出文件
    $OutputFile = Read-Host "请输入要保存IP地址的文件路径 (如: C:\IP.txt)"
    
    # 获取并显示网络适配器
    $adapters = Get-NetworkAdapters
    Show-NetworkAdapters -adapters $adapters
    
    # 用户选择网卡
    [int]$adapterIndex = Read-Host "`n请选择要查看的网卡编号"
    if ($adapterIndex -lt 0 -or $adapterIndex -ge $adapters.Count) {
        Write-Host "无效的选择!" -ForegroundColor Red
        exit 1
    }
    $selectedAdapter = $adapters[$adapterIndex]
    
    # 用户选择IP类型
    Write-Host "`n请选择IP地址类型:"
    Write-Host "[1] IPv4"
    Write-Host "[2] IPv6"
    Write-Host "[3] 全部 (默认)"
    $typeChoice = Read-Host "请选择 (1-3)"
    
    $IPType = switch ($typeChoice) {
        "1" { "IPv4" }
        "2" { "IPv6" }
        default { "All" }
    }
    
    # 获取并显示选择的IP
    $selectedIPs = Get-SelectedIP -adapter $selectedAdapter -ipType $IPType
    
    if (-not $selectedIPs -or $selectedIPs.Count -eq 0) {
        Write-Host "所选网卡没有符合条件的IP地址。" -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host "`n可用的IP地址:"
    for ($i = 0; $i -lt $selectedIPs.Count; $i++) {
        Write-Host "[$i] $($selectedIPs[$i])"
    }
    
    # 用户选择要写入的IP
    [int]$ipIndex = Read-Host "`n请选择要写入文件的IP地址编号"
    if ($ipIndex -lt 0 -or $ipIndex -ge $selectedIPs.Count) {
        Write-Host "无效的选择!" -ForegroundColor Red
        exit 1
    }
    $ipToWrite = $selectedIPs[$ipIndex]
    
    # 写入文件
    try {
        $ipToWrite | Set-Content -Path $OutputFile -Force
        Write-Host "IP地址 $ipToWrite 已成功写入到: $OutputFile" -ForegroundColor Green
    } catch {
        Write-Host "错误: 无法写入文件 $OutputFile" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }
}