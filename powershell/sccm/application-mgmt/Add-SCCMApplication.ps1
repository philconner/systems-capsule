<#
.SYNOPSIS
    Adds an application to SCCM.

.DESCRIPTION
    This script will create an application in SCCM by reading an input JSON file.
    The installation media needs to be either a NuGet package, or an MSI.
    
    For MSIs, the dictionary "msiInstallInfo" must be filled out in addition to the meta information.
    Detection rules for MSIs will be the default, i.e. using the product code of the MSI.
    Content for MSIs will also be automatically distributed by this script after the application is created.

    For NuGet packages, the dictionary "nugetDetectionRules" must be filled out in addition to the meta information.
    Detection rules for NuGet packages will be the files and folders specified in the input file, connected by "OR" operators.
    Chocolatey will be automatically added as a dependency for NuGet package applications.
    Applications installed via a NuGet package have no content to distribute.

    The application created will be placed at the destination specified in the input file.

.PARAMETER CreateInputFile
    Specifies the short name of the application to create a template input file for.

.PARAMETER InputFile
    Specifies the filename, or list of filenames, to read from and create applications for.

.INPUTS
    Currently, nothing can be piped to this script.
    TODO: Allow filenames to be piped as input.

.OUTPUTS
    Simple progress messages to stdout.

.EXAMPLE
    To create an input file and then use it as input:
        .\Add-SCCMApplication -CreateInputFile application.json
        .\Add-SCCMApplication -InputFile application.json
    Of course, the input file needs to be filled in before using it.

.EXAMPLE
    To create multiple applications, pass in the filenames as a comma-separated list with quotes:
        .\Add-SCCMApplication -InputFile "capicola.json","gabagool.json"
#>

function Create-InputFile {
    
    $inputString ='{
    "type" : "",
    "shortName" : "applicationShortName",
    "longName" : "",
    "version" : "",
    "publisher" : "",
    "iconLocation" : "\\\\redacted\\redacted",
    "nugetDetectionRules" : {
    "note" : "This section is for adding Nuget-based applications to SCCM.",
    "files" : [],
    "folders" : []
    },
    "msiInstallInfo" : {
    "note" : "This section is for adding MSI-based applications to SCCM.",
    "fileName" : "\\\\redacted\\redacted",
    "silentArgs" : "/quiet /norestart",
    "estimatedRunTime" : ""
    },
    "destination" : "redacted:\\redacted\\"
}' # can't use `n in single quotes
    $outputString = $inputString -replace 'applicationShortName',$CreateInputFile
    
    Out-File -InputObject $outputString -FilePath "$PWD\$CreateInputFile.json"
    Write-Host "Created input file $CreateInputFile.json"
}

function Add-MSIApplication {
    
    # Create application
    New-CMApplication `
        -Name $jsonInput.longName `
        -SoftwareVersion $jsonInput.version `
        -Publisher $jsonInput.publisher `
        -LocalizedName $jsonInput.longName `
        -LocalizedDescription "Contact redacted@redacted to have your request approved." `
        -IconLocationFile $jsonInput.iconLocation `
    | Out-Null

    Write-Host "`nCreated application [$($jsonInput.longName)]."
        
    # Create deployment type and add to application
    Get-CMApplication -Name $jsonInput.longName | `
        Add-CMMsiDeploymentType `
            -DeploymentTypeName "$($jsonInput.longName) MSI Installer (.msi)" `
            -ContentLocation $jsonInput.msiInstallInfo.fileName `
            -AddLanguage "en-US" `
            -EstimatedRuntimeMins $jsonInput.msiInstallInfo.estimatedRunTime `
            -InstallCommand "msiexec /i $(Split-Path $jsonInput.msiInstallInfo.fileName -Leaf) $($jsonInput.msiInstallInfo.silentArgs)" `
            -InstallationBehaviorType InstallForSystem `
            -LogonRequirementType WhetherOrNotUserLoggedOn `
            -Force `
        | Out-Null

    Write-Host "Added deployment type [$($jsonInput.longName) MSI Installer (.msi)] to application [$($jsonInput.longName)]."

    # Move application to its proper location
    Get-CMApplication -Name $jsonInput.longName | Move-CMObject -FolderPath $jsonInput.destination | Out-Null
    Write-Host "Moved application [$($jsonInput.longName)] to destination [Applications\$(Split-Path -Leaf $jsonInput.destination)]."

    # Distribute content to distribution point
    Get-CMApplication -Name $jsonInput.longName | Start-CMContentDistribution -DistributionPointName "\\redacted" -DistributionPointGroupName "redacted" | Out-Null
    Write-Host "Distributed content for application [$($jsonInput.longName)] to the distribution point."
}

function Add-NugetApplication {
    
    # Create application
    New-CMApplication `
        -Name $jsonInput.longName `
        -SoftwareVersion $jsonInput.version `
        -Publisher $jsonInput.publisher `
        -LocalizedName $jsonInput.longName `
        -LocalizedDescription "Contact redacted@redacted to have your request approved." `
        -IconLocationFile $jsonInput.iconLocation `
    | Out-Null

    Write-Host "`nCreated application [$($jsonInput.longName)]."

    # Define detection clauses. Number of clauses may vary, so a list is needed
    $detectionClauseList = New-Object System.Collections.Generic.List[System.Object]
    # File detection clauses
    foreach ($file in $jsonInput.nugetDetectionRules.files) {
        $clause = New-CMDetectionClauseFile -Path (Split-Path -Parent $file) -FileName (Split-Path -Leaf $file) -Existence
        $detectionClauseList.Add($clause)
    }
    # Folder detection clauses
    foreach ($folder in $jsonInput.nugetDetectionRules.folders) {
        $clause = New-CMDetectionClauseDirectory -Path (Split-Path -Parent $folder) -DirectoryName (Split-Path -Leaf $folder) -Existence
        $detectionClauseList.Add($clause)
    }
    # Need to cast this to an array to be able to use it as an argument
    [System.Object[]]$detectionClauseArray = $detectionClauseList

    # Define detection clause connectors
    if ($detectionClauseArray.Count -gt 1) {
                
        # Number of connectors may vary, so a list is needed
        $detectionClauseConnectorList = New-Object System.Collections.Generic.List[Hashtable]
                
        # Loop through detection clauses and create connectors for each one, adding each to the list
        foreach ($clause in $detectionClauseArray) {
            $connector = @{LogicalName = $clause.Setting.LogicalName; Connector = "OR"}
            $detectionClauseConnectorList.Add($connector)
        }

        # Need to cast this to an array to be able to use it as an argument
        [Hashtable[]]$detectionClauseConnectorArray = $detectionClauseConnectorList
    } else {
        # If there is only one detection clause, no connectors are needed. However, creating this connector eliminates the need for an if statement when making the deployment type
        $detectionClauseConnectorArray = @(@{LogicalName = $detectionClauseArray[0].Setting.LogicalName; Connector = "OR"})
    }

    # Create deployment type and add to application
    Get-CMApplication -Name $jsonInput.longName | ` 
        Add-CMScriptDeploymentType `
            -DeploymentTypeName "$($jsonInput.longName) NuGet Package (.nupkg)" `
            -InstallCommand "choco install $($jsonInput.shortName) -y" `
            -UninstallCommand "choco uninstall $($jsonInput.shortName) -y --skip-autouninstaller" `
            -EstimatedRuntimeMins 5 `
            -LogonRequirementType WhetherOrNotUserLoggedOn `
            -UserInteractionMode Hidden `
            -RebootBehavior NoAction `
            -InstallationBehaviorType InstallForSystem `
            -AddDetectionClause $detectionClauseArray `
            -DetectionClauseConnector $detectionClauseConnectorArray `
        | Out-Null

    Write-Host "Added deployment type [$($jsonInput.longName) NuGet Package (.nupkg)] to application [$($jsonInput.longName)]."

    # Add chocolatey as a dependency to the deployment type
    Get-CMDeploymentType -ApplicationName $jsonInput.longName | New-CMDeploymentTypeDependencyGroup -GroupName "Chocolatey" | Add-CMDeploymentTypeDependency -DeploymentTypeDependency (Get-CMDeploymentType -ApplicationName "Chocolatey") -IsAutoInstall $true | Out-Null
    Write-Host "Added 'Chocolatey' as a dependency to deployment type [$($jsonInput.longName) NuGet Package (.nupkg)]."

    # Move application to its proper location
    Get-CMApplication -Name $jsonInput.longName | Move-CMObject -FolderPath $jsonInput.destination | Out-Null
    Write-Host "Moved application [$($jsonInput.longName)] to destination [Applications\$(Split-Path -Leaf $jsonInput.destination)]."
}

Function Add-SCCMApplication {

    param (
        [Parameter(ParameterSetName="CreateInputFile")]
        [string]$CreateInputFile,
    
        [Parameter(ParameterSetName="AddApplicationFromInputFile")]
        [String[]]$InputFile
    )

    if ($CreateInputFile) {
        Create-InputFile
        Remove-Variable CreateInputFile
    }

    if ($InputFile) {
        Import-Module -Name "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager"
        $startingDir = $PWD

        foreach ($file in $InputFile) {
            $jsonInput = Get-Content -Path $InputFile -Raw | ConvertFrom-Json
            Set-Location redacted:
        
            switch ($jsonInput.type) {
                "msi"   {
                    Add-MSIApplication
                }
                "nuget" {
                    Add-NugetApplication
                }
                Default {
                    Write-Error "An invalid or empty type has been specified in the input file. Valid types are 'msi' or 'nuget'."
                }
            }
            Set-Location $startingDir
        }
        Remove-Variable InputFile
    }
}

<#Function Add-SCCMApplication {
    

}#>
