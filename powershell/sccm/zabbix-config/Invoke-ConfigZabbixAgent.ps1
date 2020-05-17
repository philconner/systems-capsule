<#
.SYNOPSIS
    Configures Zabbix Agents running on Windows.

.DESCRIPTION
    This is a do-everything script that runs the Config-ZabbixAgent SCCM
    script on all the collections specified in the zabbix_metadata database, by default.
    
    The zabbix_metadata database is running on redacted currently.

.NOTES
    *This script should be run normally, not through SCCM's 'Run Script'*
    
    If you wish to run this script on one specific collection, use the Config-ZabbixAgent script in SCCM instead.

    This script requires you to have the ConfigurationManager and SimplySql modules.
        The ConfigurationManager module comes with the SCCM Console installation, but can also be downloaded/installed by itself.
        The SimplySql module can be installed with the command 'Install-Module SimplySql'.

.EXAMPLE
    .\Invoke-ConfigZabbixAgent.ps1
#>

try {
    Import-Module SimplySql -ErrorAction Stop
}
catch [System.IO.FileNotFoundException] {
    Write-Host "You don't have the SimplySql Powershell module installed. Install it first with 'Install-Module SimplySql'."
}

try {
    Import-Module 'C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1' -ErrorAction Stop
}
catch [System.IO.FileNotFoundException] {
    Write-Host "You don't have the ConfigurationManager Powershell module installed."
}

function Get-MySqlConnection {
    Open-MySqlConnection `
        -Server redacted `
        -Database redacted `
        -UserName redacted `
        -Password redacted
}

function Get-MetadataTags {
    $SqlQuery = Invoke-SqlQuery -Query "SELECT * FROM redacted WHERE Type = 'sccm'"
    $UniqueIDs = $SqlQuery.ID | Get-Unique

    # Hashtable of {CollectionID : tags}
    [Hashtable]$CollectionTags = @{}

    foreach ($ID in $UniqueIDs) {
        $Tags = [System.Collections.ArrayList]@()
    
        foreach ($Row in $SqlQuery) {
            if($Row.ID -eq $ID) {
                $Tags.Add($Row.Tag) | Out-Null
            }
        }
        $JoinedTags = $Tags -join ','
        $CollectionTags.Add($ID, $JoinedTags)
    }

    $CollectionTags
}

function Invoke-SCCMScript {
    [OutputType([System.Management.ManagementBaseObject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$SiteServer
        ,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$SiteCode
        ,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ScriptName
        ,
        [Parameter(Mandatory=$false)]
        [Hashtable]$InputParameters = @{}
        ,
        [Parameter(Mandatory=$false)]
        [string]$TargetCollectionID = ""
    )
    
    $ErrorActionPreference = "Stop"

    [string]$Namespace = "ROOT\SMS\site_$( $SiteCode )"

    # Get the script
    $Script = [wmi](Get-WmiObject -class SMS_Scripts -Namespace $Namespace -ComputerName $SiteServer -Filter "ScriptName = '$ScriptName'").__PATH

    if ( -not $Script ) {
        throw "Could not find a script with name '$ScriptName'."
    }
    if ( $Script.ApprovalState -ne 3 ) {
        throw "The script '$ScriptName' could not be invoked because it is not approved."
    }
    # Parse the parameter definition
    $Parameters = [xml]([string]::new([Convert]::FromBase64String( $Script.ParamsDefinition ) ) )

    $Parameters.ScriptParameters.ChildNodes | ForEach-Object {
        if ( ( $_.IsRequired ) -and ( $_.IsHidden -ne $true ) -and ( $_.Name -notin $InputParameters.Keys ) ) {
            throw "Script '$( $ScriptName )' has required parameters '$( $_.Name )' but no parameters were passed."
        }
    }

    # create GUID used for parametergroup
    $ParameterGroupGUID = $(New-Guid)

    if ($InputParameters.Count -le 0) {
        # If no ScriptParameters: <ScriptParameters></ScriptParameters> and an empty hash
        $ParametersXML = "<ScriptParameters></ScriptParameters>"
        $ParametersHash = ""
    }
    else {
        $InnerParametersXML = ''
        foreach ( $ChildNode in $Parameters.ScriptParameters.ChildNodes ) {
            $ParamName = $ChildNode.Name
            if ( $ChildNode.IsHidden -eq 'true' ) {
                $Value = $ChildNode.DefaultValue
            }
            else {
                if ( $ParamName -in $InputParameters.Keys ) {
                    $Value = $InputParameters."$( $ParamName )"
                }
                else {
                    $Value = ''
                }
            }
            $InnerParametersXML = "$( $InnerParametersXML )<ScriptParameter ParameterGroupGuid=`"$( $ParameterGroupGUID )`" ParameterGroupName=`"PG_$( $ParameterGroupGUID )`" ParameterName=`"$( $ParamName )`" ParameterType=`"$( $ChildNode.Type )`" ParameterValue=`"$( $Value )`"/>"
        }
        $ParametersXML = "<ScriptParameters>$InnerParametersXML</ScriptParameters>"

        $SHA256 = [System.Security.Cryptography.SHA256Cng]::new()
        $Bytes = ($SHA256.ComputeHash(([System.Text.Encoding]::Unicode).GetBytes($ParametersXML)))
        $ParametersHash = ($Bytes | ForEach-Object ToString X2) -join ''
    }

    $RunScriptXMLDefinition = "<ScriptContent ScriptGuid='{0}'><ScriptVersion>{1}</ScriptVersion><ScriptType>{2}</ScriptType><ScriptHash ScriptHashAlg='SHA256'>{3}</ScriptHash>{4}<ParameterGroupHash ParameterHashAlg='SHA256'>{5}</ParameterGroupHash></ScriptContent>"
    $RunScriptXML = $RunScriptXMLDefinition -f $Script.ScriptGuid,$Script.ScriptVersion,$Script.ScriptType,$Script.ScriptHash,$ParametersXML,$ParametersHash

    # Get information about the class instead of fetching an instance
    # WMI holds the secret of what parameters that needs to be passed and the actual order in which they have to be passed
    $MC = [WmiClass]"\\$SiteServer\$($Namespace):SMS_ClientOperation"

    # Get the parameters of the WmiMethod
    $MethodName = 'InitiateClientOperationEx'
    $InParams = $MC.psbase.GetMethodParameters($MethodName)

    # Information about the script is passed as the parameter 'Param' as a BASE64 encoded string
    $InParams.Param = ([Convert]::ToBase64String(([System.Text.Encoding]::UTF8).GetBytes($RunScriptXML)))
    # ([System.Text.Encoding]::UTF8.GetString( [convert]::FromBase64String($InParams.Param  ) ) )

    # Hardcoded to 0 in certain DLLs
    $InParams.RandomizationWindow = "0"

    # If we are using a collection, set it. TargetCollectionID can be empty string: ""
    $InParams.TargetCollectionID = $TargetCollectionID

    # Run Script is type 135
    $InParams.Type = "135"

    # Everything should be ready for processing, invoke the method!
    try {
        $Result = $MC.InvokeMethod($MethodName, $InParams, $null)
    }
    catch {
        $Result = [PSCustomObject]@{

        }
    }
    # The result contains the client operation id of the execution
    $Result
}

function Invoke-ConfigZabbixAgent {
    Param(
        [Parameter(Mandatory=$true)]
        [Hashtable]
        $CollectionTags
    )

    # Parameters to pass to Invoke-SCCMSCript
    $Params = @{
        SiteServer = 'redacted'
        SiteCode = 'redacted'
        ScriptName = 'Config-ZabbixAgent'
    }

    foreach ($Entry in $CollectionTags.Keys) {
        # Parameters to pass to Config-ZabbixAgent
        $InputParameters = @{
            MetadataTags = $CollectionTags[$Entry]
        }    
        $Params['TargetCollectionID'] = "$($Entry)"
        $Params['InputParameters'] = $InputParameters
        
        Invoke-SCCMScript @Params
    }
}

Get-MySqlConnection
$CollectionTags = Get-MetadataTags
Invoke-ConfigZabbixAgent -CollectionTags $CollectionTags
