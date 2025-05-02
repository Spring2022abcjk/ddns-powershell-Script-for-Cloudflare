function Get-CloudflareConfig {
    param (
        [string]$CloudflareConfigPath,
        [string]$RecordConfigPath,
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

    $ScriptDir = Split-Path -Parent (Get-Variable MyInvocation -Scope 1).Value.MyCommand.Definition
    
    # 处理 Cloudflare 配置文件
    if (-not $CloudflareConfigPath) {
        $CloudflareConfigFile = Join-Path -Path $ScriptDir -ChildPath "cloudflare.toml"
    } else {
        $CloudflareConfigFile = $CloudflareConfigPath
    }
    
    Write-Host "使用 Cloudflare 配置文件: $CloudflareConfigFile"
    
    # 尝试从 Cloudflare 配置文件读取配置
    if (Test-Path -Path $CloudflareConfigFile) {
        try {
            $CloudflareConfig = Get-Content -Path $CloudflareConfigFile -Raw | ConvertFrom-Toml
            if ($CloudflareConfig.cloudflare) {
                # 处理 API Key
                if ($CloudflareConfig.cloudflare.api_key) {
                    # 检查是否是环境变量引用
                    if ($CloudflareConfig.cloudflare.api_key -match '^\{env:(.+)\}$') {
                        $envVarName = $matches[1]
                        $ConfigResult.ApiToken = (Get-Item -Path "env:$envVarName" -ErrorAction SilentlyContinue).Value
                        if (-not $ConfigResult.ApiToken) {
                            Write-Warning "环境变量 $envVarName 不存在或为空，将尝试读取默认环境变量。"
                        }
                    } else {
                        $ConfigResult.ApiToken = $CloudflareConfig.cloudflare.api_key
                    }
                }
                
                # 处理 Account ID
                if ($CloudflareConfig.cloudflare.account_id) {
                    # 检查是否是环境变量引用
                    if ($CloudflareConfig.cloudflare.account_id -match '^\{env:(.+)\}$') {
                        $envVarName = $matches[1]
                        $ConfigResult.AccountID = (Get-Item -Path "env:$envVarName" -ErrorAction SilentlyContinue).Value
                        if (-not $ConfigResult.AccountID) {
                            Write-Warning "环境变量 $envVarName 不存在或为空，将尝试读取默认环境变量。"
                        }
                    } else {
                        $ConfigResult.AccountID = $CloudflareConfig.cloudflare.account_id
                    }
                }
                
                # 处理 Zone ID
                if ($CloudflareConfig.cloudflare.zone_id) {
                    # 检查是否是环境变量引用
                    if ($CloudflareConfig.cloudflare.zone_id -match '^\{env:(.+)\}$') {
                        $envVarName = $matches[1]
                        $ConfigResult.ZoneID = (Get-Item -Path "env:$envVarName" -ErrorAction SilentlyContinue).Value
                        if (-not $ConfigResult.ZoneID) {
                            Write-Warning "环境变量 $envVarName 不存在或为空，将尝试读取默认环境变量。"
                        }
                    } else {
                        $ConfigResult.ZoneID = $CloudflareConfig.cloudflare.zone_id
                    }
                }
            } else {
                Write-Warning "Cloudflare 配置文件中缺少 [cloudflare] 部分，将尝试读取环境变量。"
            }
        } catch {
            Write-Warning "读取或解析 Cloudflare 配置文件失败: $($_.Exception.Message)，将尝试读取环境变量。"
        }
    } else {
        Write-Warning "Cloudflare 配置文件不存在: $CloudflareConfigFile，将尝试读取环境变量。"
    }
    
    # 如果需要 SVCB 记录配置，则处理记录配置文件
    if ($RequireSVCB) {
        if (-not $RecordConfigPath) {
            $RecordConfigFile = Join-Path -Path $ScriptDir -ChildPath "svcb_record.toml"
        } else {
            $RecordConfigFile = $RecordConfigPath
        }
        
        Write-Host "使用记录配置文件: $RecordConfigFile"
        
        # 尝试从记录配置文件读取配置
        if (Test-Path -Path $RecordConfigFile) {
            try {
                $RecordConfig = Get-Content -Path $RecordConfigFile -Raw | ConvertFrom-Toml
                
                if ($RecordConfig.record) {
                    $ConfigResult.DNSRecordName = $RecordConfig.record.dns_record_name
                    $ConfigResult.DNSRecordType = $RecordConfig.record.dns_record_type
                    $ConfigResult.TTL = $RecordConfig.record.ttl
                } else {
                    Write-Warning "记录配置文件中缺少 [record] 部分。"
                }
                
                if ($RecordConfig.svcb) {
                    $ConfigResult.SVCB.Priority = $RecordConfig.svcb.priority
                    $ConfigResult.SVCB.Target = $RecordConfig.svcb.target
                    $ConfigResult.SVCB.Port = $RecordConfig.svcb.port
                    $ConfigResult.SVCB.ALPN = $RecordConfig.svcb.alpn
                    $ConfigResult.SVCB.IPv4Hint = $RecordConfig.svcb.ipv4hint
                    $ConfigResult.SVCB.IPv6Hint = $RecordConfig.svcb.ipv6hint
                    $ConfigResult.SVCB.ECHConfig = $RecordConfig.svcb.echconfig
                    $ConfigResult.SVCB.Modelist = $RecordConfig.svcb.modelist
                    $ConfigResult.SVCB.Params = $RecordConfig.svcb.params
                    $ConfigResult.SVCB.Comment = $RecordConfig.svcb.comment
                } else {
                    Write-Warning "记录配置文件中缺少 [svcb] 部分。"
                }
            } catch {
                Write-Warning "读取或解析记录配置文件失败: $($_.Exception.Message)"
            }
        } else {
            Write-Warning "记录配置文件不存在: $RecordConfigFile"
        }
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