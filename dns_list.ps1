#!/usr/bin/env pwsh

# Cloudflare API credentials
# 使用环境变量存储API密钥更安全
$API_TOKEN = $env:CF_API_TOKEN

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
    if ($args.Count -ne 1) {
        Write-Host "用法: $($MyInvocation.MyCommand.Name) <域名>"
        exit 1
    }
    
    $domain = $args[0]
    
    if (-not $API_TOKEN) {
        Write-Host "错误: 未设置CF_API_TOKEN环境变量"
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