param(
    [string]$CloudflareConfigPath
)

Import-Module -Name PSToml

# 导入配置模块
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. "$ScriptDir\Cloudflare_Config.ps1"

# 获取配置 (不需要 SVCB 记录配置)
$Config = Get-CloudflareConfig -CloudflareConfigPath $CloudflareConfigPath

if (-not $Config.Success) {
    Write-Error $Config.ErrorMessage
    exit 1
}

# 提取必要的配置值
$API_TOKEN = $Config.ApiToken

function Get-ZoneId {
    param (
        [string]$Domain
    )
    
    $url = "https://api.cloudflare.com/client/v4/zones"
    $headers = @{
        "Authorization" = "Bearer $API_TOKEN"
        "Content-Type" = "application/json"
    }
    
    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
    
    if (-not $response.success) {
        Write-Host "错误: $($response.errors | ConvertTo-Json)"
        exit 1
    }
    
    foreach ($zone in $response.result) {
        if ($zone.name -eq $Domain) {
            return $zone.id
        }
    }
    
    Write-Host "域名 $Domain 在您的Cloudflare账户中未找到"
    exit 1
}

function Get-DnsRecords {
    param (
        [string]$ZoneId
    )
    
    $url = "https://api.cloudflare.com/client/v4/zones/$ZoneId/dns_records"
    $headers = @{
        "Authorization" = "Bearer $API_TOKEN"
        "Content-Type" = "application/json"
    }
    
    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
    
    if (-not $response.success) {
        Write-Host "错误: $($response.errors | ConvertTo-Json)"
        exit 1
    }
    
    return $response.result
}

function Main {
    param(
        [Parameter(ValueFromRemainingArguments=$true)]
        $InputArgs
    )
    
    # 检查是否有命令行参数
    if ($InputArgs.Count -eq 0) {
        # 如果没有参数，提示用户输入域名
        $domain = Read-Host "请输入要查询的域名"
        if ([string]::IsNullOrWhiteSpace($domain)) {
            Write-Host "错误: 域名不能为空"
            exit 1
        }
    } elseif ($InputArgs.Count -eq 1) {
        # 如果有一个参数，使用该参数作为域名
        $domain = $InputArgs[0]
    } else {
        # 如果参数过多，显示用法
        Write-Host "用法: $($MyInvocation.MyCommand.Name) [域名]"
        Write-Host "      如果不提供域名参数，程序将提示您输入"
        exit 1
    }
    
    if (-not $API_TOKEN) {
        Write-Host "错误: 未设置API_TOKEN变量"
        exit 1
    }
    
    Write-Host "正在获取 $domain 的zone ID..."
    $zoneId = Get-ZoneId -Domain $domain
    Write-Host "Zone ID: $zoneId"
    
    Write-Host "`n正在列出 $domain 的DNS记录..."
    $records = Get-DnsRecords -ZoneId $zoneId
    
    Write-Host "`n$("名称".PadRight(40)) $("类型".PadRight(10)) $("TTL".PadRight(10)) $("内容".PadRight(20))"
    Write-Host ("-" * 80)
    
    foreach ($record in $records) {
        Write-Host "$($record.name.PadRight(40)) $($record.type.PadRight(10)) $($record.ttl.ToString().PadRight(10)) $($record.content.PadRight(20))"
    }
}

# Call Main with script arguments
Main $args