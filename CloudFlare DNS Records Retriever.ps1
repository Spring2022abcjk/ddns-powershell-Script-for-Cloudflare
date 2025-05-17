# CloudFlare DNS Records Retriever
# This script fetches DNS records for a specified domain in JSON format
# It uses CloudFlare API and reads configuration from cloudflare_config.ps1

param(
    [Parameter(Mandatory=$true)]
    [string]$Domain,
    
    [Parameter(Mandatory=$false)]
    [string[]]$RecordTypes = @("AAAA", "A"),
    
    [Parameter(Mandatory=$false)]
    [string]$CloudflareConfigPath
)

# Import CloudFlare configuration
. ".\cloudflare_config.ps1"

# 调用配置函数获取API配置
$Config = Get-CloudflareConfig -CloudflareConfigPath $CloudflareConfigPath

# 确保配置读取成功
if (-not $Config.Success) {
    Write-Error $Config.ErrorMessage
    exit 1
}

# 提取配置值
$CF_API_TOKEN = $Config.ApiToken
$CF_ZONE_ID = $Config.ZoneID

# 确保配置值可用
if (-not $CF_ZONE_ID -or -not $CF_API_TOKEN) {
    Write-Error "CloudFlare API Token或Zone ID缺失。请检查配置。"
    exit 1
}

# API endpoint for DNS records
$ApiUrl = "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records"

# Request headers with authentication
$Headers = @{
    "Authorization" = "Bearer $CF_API_TOKEN"
    "Content-Type" = "application/json"
}

$Results = @()

# Query each record type
foreach ($Type in $RecordTypes) {
    $QueryParams = @{
        name = $Domain
        type = $Type
    }
    
    $QueryString = ($QueryParams.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "&"
    $RequestUrl = "$ApiUrl`?$QueryString"
    
    try {
        $Response = Invoke-RestMethod -Uri $RequestUrl -Headers $Headers -Method Get
        if ($Response.success -eq $true) {
            $Results += $Response.result
        } else {
            Write-Warning "Failed to get $Type records for $Domain"
        }
    } catch {
        Write-Error "Error querying $Type records for $Domain : $_"
    }
}

# Output results in JSON format
$Results | ConvertTo-Json -Depth 5