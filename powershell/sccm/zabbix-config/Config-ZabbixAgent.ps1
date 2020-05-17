<#
.SYNOPSIS
    Configures a Zabbix Agent running on Windows.

.DESCRIPTION
    This is a do-everything script for Zabbix Agents on Windows, and it does the following:
        - Set the main config file
        - Set the HostInterface config file
        - Set the HostMetadata config file
        - Restart the Zabbix Agent service

.NOTE
    This script is intended to be run through SCCM on SCCM clients.

.PARAMETER MetadataTags
    A string of zabbix metadata tags, of the form "tag1,tag2,tag3"

    This name is purposely verbose because if you are running this script from SCCM you
    will only see the parameter name and no description.

.EXAMPLE
    .\Config-ZabbixAgent.ps1 -MetadataTags "windows,desktops,labs,ps"
        The equivalent of this through SCCM's 'Run Script', not actually from the command line.
#>

Param(
    # A string of zabbix metadata tags, of the form "tag1,tag2,tag3"
    [Parameter(Mandatory=$true)]
    [String]
    $MetadataTags
)

function Set-MainConfig {
    $SourceFile = '\\redacted\redacted'
    $ZabbixPath = 'C:\Program Files\Zabbix Agent\'
    if (Test-Path -LiteralPath $ZabbixPath -PathType Container) {
	    Copy-Item -Path $SourceFile -Destination $ZabbixPath
    }
    else {
	    Write-Error -Message "Directory does not exist. Failed to write content."
    }
}

function Set-HostInterfaceConfig {
    $SourceFile = '\\redacted\redacted\Zabbix\zabbix_agentd.conf.d\zabbix_hostinterface.conf'
    $ConfigPath = 'C:\Program Files\Zabbix Agent\zabbix_agentd.conf.d'

    # Get FQDN of host
    $HostFQDN = ([System.Net.Dns]::GetHostByName(($env:computerName))).Hostname

    $SourceContent = Get-Content -Path $SourceFile
    if ( Test-Path -Path $ConfigPath -PathType Container ) {
	    $SourceContent -replace '%VALUE%', $HostFQDN | Set-Content -Path $ConfigPath\zabbix_hostinterface.conf
    }
    else {
	    Write-Error -Message "Directory does not exist. Failed to write content."
    }
}

function Set-HostMetadataConfig {
    Param(
        # A string of zabbix metadata tags, of the form "tag1,tag2,tag3"
        [Parameter(Mandatory=$true)]
        [String]
        $Tags
    )

    $SourceFile = '\\redacted\redacted\Zabbix\zabbix_agentd.conf.d\zabbix_hostmetadata.conf'
    $ConfigPath = 'C:\Program Files\Zabbix Agent\zabbix_agentd.conf.d'

    $SourceContent = Get-Content -Path $SourceFile
    if ( Test-Path -Path $ConfigPath -PathType Container ) {
	    $SourceContent -replace '%VALUE%', $Tags | Set-Content -Path $ConfigPath\zabbix_hostmetadata.conf
    }
    else {
	    Write-Error -Message "Directory does not exist. Failed to write content."
    }  
}

function Restart-AgentService {
    $ServiceName='Zabbix Agent'
    if ( Get-Service -Name $ServiceName -ErrorAction SilentlyContinue ) {
	    Restart-Service -Name $ServiceName
    }
    else {
	    Write-Error -Message 'Zabbix Agent Service not found.'
    }
}

Set-MainConfig
Set-HostInterfaceConfig
Set-HostMetadataConfig -Tags $MetadataTags
Restart-AgentService
