# 函数1: 获取 Cloudflare API 配置信息
function Get-CloudflareApiConfig {
    param (
        [string]$CloudflareConfigPath
    )
    
    $ConfigResult = @{
        Success = $true
        ErrorMessage = $null
        ApiToken = $null
        AccountID = $null
        ZoneID = $null
    }
    
    $ScriptDir = Split-Path -Parent (Get-Variable MyInvocation -Scope 1).Value.MyCommand.Definition
    
    # 处理配置文件路径
    if (-not $CloudflareConfigPath) {
        $CloudflareConfigFile = Join-Path -Path $ScriptDir -ChildPath "cloudflare.toml"
    } else {
        $CloudflareConfigFile = $CloudflareConfigPath
    }
    
    Write-Host "使用 Cloudflare 配置文件: $CloudflareConfigFile"
    
    # 尝试从配置文件读取 API 配置
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
    
    # 如果配置文件中未找到，尝试从环境变量中读取
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
    
    # 验证必要配置
    if (-not $ConfigResult.ApiToken) {
        $ConfigResult.Success = $false
        $ConfigResult.ErrorMessage = "未找到 Cloudflare API Token (配置文件或环境变量中)，请检查配置。"
    }
    
    return $ConfigResult
}

# 函数2: 获取 DNS 记录配置信息
function Get-DnsRecordConfig {
    param (
        [string]$RecordConfigPath,
        [ValidateSet("SVCB", "HTTPS")]
        [string]$PreferredRecordType = "SVCB"
    )
    
    $ConfigResult = @{
        Success = $true
        ErrorMessage = $null
        DNSRecordName = $null
        DNSRecordType = $PreferredRecordType
        TTL = 60
        ServiceParams = @{
            Priority = $null
            Target = $null
            Port = $null
            ALPN = $null
            IPv4Hint = $null
            IPv6Hint = $null
            ECHConfig = $null
            Modelist = $null
            Params = $null
            Comment = "使用脚本更新的 $PreferredRecordType 记录"
        }
    }
    
    $ScriptDir = Split-Path -Parent (Get-Variable MyInvocation -Scope 1).Value.MyCommand.Definition
    
    # 确定使用的记录配置文件
    if (-not $RecordConfigPath) {
        # 优先使用与记录类型匹配的配置文件
        $TypeSpecificConfigFile = Join-Path -Path $ScriptDir -ChildPath "$($PreferredRecordType.ToLower())_record.toml"
        $GenericConfigFile = Join-Path -Path $ScriptDir -ChildPath "service_record.toml"
        
        if (Test-Path -Path $TypeSpecificConfigFile) {
            $RecordConfigFile = $TypeSpecificConfigFile
        } else {
            $RecordConfigFile = $GenericConfigFile
        }
    } else {
        $RecordConfigFile = $RecordConfigPath
    }
    
    Write-Host "使用记录配置文件: $RecordConfigFile"
    
    # 尝试从记录配置文件读取配置
    if (Test-Path -Path $RecordConfigFile) {
        try {
            $RecordConfig = Get-Content -Path $RecordConfigFile -Raw | ConvertFrom-Toml
            
            # 读取基本记录配置
            if ($RecordConfig.record) {
                $ConfigResult.DNSRecordName = $RecordConfig.record.dns_record_name
                
                # 只有在未指定首选记录类型的情况下才使用配置文件中的类型
                if ($RecordConfig.record.dns_record_type) {
                    $ConfigResult.DNSRecordType = $RecordConfig.record.dns_record_type
                }
                
                if ($RecordConfig.record.ttl) {
                    $ConfigResult.TTL = $RecordConfig.record.ttl
                }
            } else {
                Write-Warning "记录配置文件中缺少 [record] 部分。"
            }
            
            # 读取记录类型特定的参数
            # 尝试读取与当前记录类型匹配的部分
            $recordTypeLower = $ConfigResult.DNSRecordType.ToLower()
            $serviceSection = $null
            
            # 优先读取匹配记录类型的部分
            if ($RecordConfig.$recordTypeLower) {
                $serviceSection = $RecordConfig.$recordTypeLower
            }
            # 如果没有特定类型的部分，尝试读取通用部分
            elseif ($RecordConfig.service_params) {
                $serviceSection = $RecordConfig.service_params
            }
            
            if ($serviceSection) {
                $ConfigResult.ServiceParams.Priority = $serviceSection.priority
                $ConfigResult.ServiceParams.Target = $serviceSection.target
                $ConfigResult.ServiceParams.Port = $serviceSection.port
                $ConfigResult.ServiceParams.ALPN = $serviceSection.alpn
                $ConfigResult.ServiceParams.IPv4Hint = $serviceSection.ipv4hint
                $ConfigResult.ServiceParams.IPv6Hint = $serviceSection.ipv6hint
                $ConfigResult.ServiceParams.ECHConfig = $serviceSection.echconfig
                $ConfigResult.ServiceParams.Modelist = $serviceSection.modelist
                $ConfigResult.ServiceParams.Params = $serviceSection.params
                
                if ($serviceSection.comment) {
                    $ConfigResult.ServiceParams.Comment = $serviceSection.comment
                }
            } else {
                Write-Warning "记录配置文件中缺少 [$recordTypeLower] 或 [service_params] 部分。"
            }
        } catch {
            Write-Warning "读取或解析记录配置文件失败: $($_.Exception.Message)"
            $ConfigResult.Success = $false
            $ConfigResult.ErrorMessage = "读取记录配置文件失败: $($_.Exception.Message)"
        }
    } else {
        Write-Warning "记录配置文件不存在: $RecordConfigFile"
        $ConfigResult.DNSRecordName = $env:CLOUDFLARE_DNS_RECORD_NAME
    }
    
    # 更新评论以包含记录类型
    $ConfigResult.ServiceParams.Comment = "使用脚本更新的 $($ConfigResult.DNSRecordType) 记录"
    
    return $ConfigResult
}

# 函数3: 主函数，根据参数决定使用哪个读取函数
function Get-CloudflareConfig {
    param (
        [string]$CloudflareConfigPath,
        [string]$RecordConfigPath,
        [switch]$RequireRecordConfig,
        [ValidateSet("SVCB", "HTTPS")]
        [string]$PreferredRecordType = "SVCB"
    )
    
    # 创建返回值对象
    $ConfigResult = @{
        Success = $true
        ErrorMessage = $null
        ApiToken = $null
        AccountID = $null
        ZoneID = $null
        DNSRecordName = $null
        DNSRecordType = $PreferredRecordType
        TTL = 60
        ServiceParams = @{
            Priority = $null
            Target = $null
            Port = $null
            ALPN = $null
            IPv4Hint = $null
            IPv6Hint = $null
            ECHConfig = $null
            Modelist = $null
            Params = $null
            Comment = "使用脚本更新的DNS记录"
        }
    }
    
    # 始终获取 Cloudflare API 配置
    $ApiConfig = Get-CloudflareApiConfig -CloudflareConfigPath $CloudflareConfigPath
    
    # 复制 API 配置到结果
    $ConfigResult.ApiToken = $ApiConfig.ApiToken
    $ConfigResult.AccountID = $ApiConfig.AccountID
    $ConfigResult.ZoneID = $ApiConfig.ZoneID
    $ConfigResult.Success = $ApiConfig.Success
    $ConfigResult.ErrorMessage = $ApiConfig.ErrorMessage
    
    # 如果 API 配置获取失败，则直接返回
    if (-not $ConfigResult.Success) {
        return $ConfigResult
    }
    
    # 如果需要DNS记录配置，则获取DNS记录配置
    if ($RequireRecordConfig) {
        $RecordConfig = Get-DnsRecordConfig -RecordConfigPath $RecordConfigPath -PreferredRecordType $PreferredRecordType
        
        # 复制记录配置到结果
        $ConfigResult.DNSRecordName = $RecordConfig.DNSRecordName
        $ConfigResult.DNSRecordType = $RecordConfig.DNSRecordType
        $ConfigResult.TTL = $RecordConfig.TTL
        $ConfigResult.ServiceParams = $RecordConfig.ServiceParams
        
        # 如果记录配置获取失败，更新成功状态和错误消息
        if (-not $RecordConfig.Success) {
            $ConfigResult.Success = $false
            $ConfigResult.ErrorMessage = $RecordConfig.ErrorMessage
        }
    }
    
    return $ConfigResult
}