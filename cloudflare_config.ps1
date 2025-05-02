function Get-CloudflareConfig {
    param (
        [string]$ConfigPath,
        [switch]$RequireSVCB
    )

    $ConfigResult = @{
        Success = $true
        ErrorMessage = $null
        ApiToken = $null
        AccountID = $null
        ZoneID = $null
        DNSRecordName = $null
        DNSRecordType = $null
        TTL = $null
        SVCB = @{
            Priority = $null
            Target = $null
            Port = $null
            ALPN = $null
            IPv4Hint = $null
            IPv6Hint = $null
            ECHConfig = $null
            Modelist = $null
            Params = $null
            Comment = $null
        }
    }

    # 如果未指定配置文件路径，则使用脚本所在目录下的config.toml
    if (-not $ConfigPath) {
        $ScriptDir = Split-Path -Parent (Get-Variable MyInvocation -Scope 1).Value.MyCommand.Definition
        $ConfigFile = Join-Path -Path $ScriptDir -ChildPath "config.toml"
    } else {
        $ConfigFile = $ConfigPath
    }

    Write-Host "使用配置文件: $ConfigFile"

    # 尝试从配置文件读取配置
    if (Test-Path -Path $ConfigFile) {
        try {
            $Config = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Toml
            if ($Config.cloudflare) {
                $ConfigResult.ApiToken = $Config.cloudflare.api_key
                $ConfigResult.AccountID = $Config.cloudflare.account_id
                $ConfigResult.ZoneID = $Config.cloudflare.zone_id
                $ConfigResult.DNSRecordName = $Config.cloudflare.dns_record_name
                $ConfigResult.DNSRecordType = $Config.cloudflare.dns_record_type
                $ConfigResult.TTL = $Config.cloudflare.ttl
            } else {
                Write-Warning "配置文件中缺少 [cloudflare] 部分，将尝试读取环境变量。"
            }

            if ($RequireSVCB -and $Config.svcb) {
                $ConfigResult.SVCB.Priority = $Config.svcb.priority
                $ConfigResult.SVCB.Target = $Config.svcb.target
                $ConfigResult.SVCB.Port = $Config.svcb.port
                $ConfigResult.SVCB.ALPN = $Config.svcb.alpn
                $ConfigResult.SVCB.IPv4Hint = $Config.svcb.ipv4hint
                $ConfigResult.SVCB.IPv6Hint = $Config.svcb.ipv6hint
                $ConfigResult.SVCB.ECHConfig = $Config.svcb.echconfig
                $ConfigResult.SVCB.Modelist = $Config.svcb.modelist
                $ConfigResult.SVCB.Params = $Config.svcb.params
                $ConfigResult.SVCB.Comment = $Config.svcb.comment
            } elseif ($RequireSVCB) {
                Write-Warning "配置文件中缺少 [svcb] 部分，将使用默认的 SVCB 配置或尝试从环境变量读取（如果适用）。"
            }

        } catch {
            Write-Warning "读取或解析配置文件失败: $($_.Exception.Message)，将尝试读取环境变量。"
        }
    } else {
        Write-Warning "配置文件不存在: $ConfigFile，将尝试读取环境变量。"
    }

    # 如果从配置文件中没有成功读取到所有必要的 API 配置，则尝试从环境变量中读取
    if (-not $ConfigResult.ApiToken) {
        Write-Host "从环境变量中读取 Cloudflare API 配置..."
        $ConfigResult.ApiToken = $env:CLOUDFLARE_API_KEY
    }
    
    if (-not $ConfigResult.AccountID) {
        $ConfigResult.AccountID = $env:CLOUDFLARE_ACCOUNT_ID
    }
    
    if (-not $ConfigResult.ZoneID) {
        $ConfigResult.ZoneID = $env:CLOUDFLARE_ZONE_ID
    }

    # 从环境变量中读取 DNS 记录配置 (如果配置文件中没有)
    if (-not $ConfigResult.DNSRecordName) {
        $ConfigResult.DNSRecordName = $env:CLOUDFLARE_DNS_RECORD_NAME
    }

    # 设置默认值
    if (-not $ConfigResult.DNSRecordType) { 
        $ConfigResult.DNSRecordType = "SVCB"
    }
    
    if (-not $ConfigResult.TTL) {
        $ConfigResult.TTL = 60
    }
    
    if (-not $ConfigResult.SVCB.Comment) {
        $ConfigResult.SVCB.Comment = "使用脚本更新的dns记录"
    }

    # 验证必要配置
    if (-not $ConfigResult.ApiToken) {
        $ConfigResult.Success = $false
        $ConfigResult.ErrorMessage = "未找到 Cloudflare API 的相关配置 (配置文件或环境变量中)，请检查配置。"
    }

    return $ConfigResult
}