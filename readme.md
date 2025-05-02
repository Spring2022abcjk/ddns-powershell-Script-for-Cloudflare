# Cloudflare SVCB DNS Record Updater

## Synopsis
Updates SVCB DNS records in Cloudflare using either a TOML configuration file or environment variables.

## Description
This script updates SVCB (Service binding) DNS records in Cloudflare DNS. It supports configuration through
either a TOML file or environment variables. The script handles the construction of SVCB record parameters
like port, ALPN, IPv4Hint, IPv6Hint, ECHConfig, etc., and then updates the record using Cloudflare's API.

## Parameters

### ConfigPath
Optional. Path to the TOML configuration file. If not specified, the script uses a config.toml file in the
same directory as the script.

## Requirements
- PowerShell 5.1 or higher
- PSToml module (`Import-Module -Name PSToml`)
- Cloudflare API key with permissions to edit DNS records
- Existing SVCB record to update

## Configuration
The configuration can be provided either in a TOML file or environment variables:

### TOML file structure:
```toml
[cloudflare]
api_key = "your_api_key"
account_id = "your_account_id"
zone_id = "your_zone_id"
dns_record_name = "your_dns_record_name"
dns_record_type = "SVCB"
ttl = 60

[svcb]
priority = 1
target = "example.com"
port = 443
alpn = ["h2", "http/1.1"]
ipv4hint = ["192.0.2.1", "192.0.2.2"]
ipv6hint = ["2001:db8::1", "2001:db8::2"]
echconfig = "your_echconfig_value"
modelist = "your_modelist_value"
params = ["additional_param1", "additional_param2"]
comment = "Comment for this DNS record"
```

### Environment variables:
- `CLOUDFLARE_API_KEY`
- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_ZONE_ID`
- `CLOUDFLARE_DNS_RECORD_NAME`

## Examples

```powershell
# Uses the config.toml in the script directory
.\update_svcb.ps1
```

```powershell
# Uses a specific configuration file
.\update_svcb.ps1 -ConfigPath "C:\path\to\my-config.toml"
```

## Notes
- Priority and Target are required SVCB parameters
- At least one of these parameters is required: port, alpn, ipv4hint, ipv6hint, echconfig, modelist, or params
- For target=".", it's recommended to configure at least ipv4hint or ipv6hint
- For _https services, it's recommended to configure the alpn parameter
- The script will check for existing records before updating
- Detailed error messages will be shown if any API calls fail