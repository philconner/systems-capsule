<#
.SYNOPSIS
    Deploys applications to collections in SCCM.

.DESCRIPTION
    This is an interactive script that will deploy one or more applications to one or more collections in SCCM.

.PARAMETER applicationNames
    Comma-separated list of application names to make deployments for.

.INPUTS
    Currently, nothing can be piped to this script.
    TODO: Allow application names to be piped as input

.OUTPUTS
    Simple progress messages to stdout.

.EXAMPLE
    To run the script in full interactive mode:
        .\Deploy-SCCMApplication.ps1
    Using this method, enter application names without quotes.

.EXAMPLE
    To supply the application names beforehand:
        .\Deploy-SCCMApplication.ps1 -applicationNames "Windows Admin Center","Visual Studio Professional 2013"
    Using this method, enter the application names with quotes.
#>

Function Process-UserDeployments {
    param(
        [Parameter(Mandatory=$true)]
        [String[]]$applicationNames
    )

    Set-Location redacted:
    
    # Get user collections as a list of hashtables
    $userCollections = New-Object System.Collections.Generic.List[Hashtable]
    $i = 1
    Get-CMUserCollection | ForEach-Object {$userCollections.Add(@{Index=$i;Name=$_.Name}); $i++}
    Remove-Variable i
    
    # Display collections and read list of choices
    Write-Host "`nCollection(s)"
    Foreach ($collection in $userCollections) {
        Write-Host "[$($collection.Index)] $($collection.Name)"
    }
    [Int32[]]$collectionChoices = (Read-Host " ").Split(",")

    # Should requesting an installation need approval?
    $approvalChoices = @{
        1 = $true
        2 = $false
    }
    [Int32]$approvalChoiceIndex = Read-Host "`nRequire approval for installation?
    [1] True
    [2] False"

    # Deploy the specified applications to the user collections chosen
    Foreach ($applicationName in $applicationNames) {
        Foreach ($collectionChoice in $collectionChoices) {
            Get-CMApplication -Name $applicationName | New-CMApplicationDeployment `
                                                        -CollectionName $userCollections[$collectionChoice - 1].Name `
                                                        -DeployAction Install `
                                                        -DeployPurpose Available `
                                                        -UserNotification DisplaySoftwareCenterOnly `
                                                        -ApprovalRequired $approvalChoices[$approvalChoiceIndex] `
                                                     | Out-Null

            if (Get-CMApplicationDeployment -Name $applicationName -CollectionName $userCollections[$collectionChoice - 1].Name) {
                Write-Host "`nCreated deployment for application [$($applicationName)] to collection [$($userCollections[$collectionChoice - 1].Name)]."
            }
        }
    }
}

Function Process-DeviceDeployments {
    param(
        [Parameter(Mandatory=$true)]
        [String[]]$applicationNames
    )

    Set-Location redacted:

    # Get device collections as a list of hashtables
    $deviceCollections = New-Object System.Collections.Generic.List[Hashtable]
    $i = 1
    Get-CMDeviceCollection | ForEach-Object {$deviceCollections.Add(@{Index=$i;Name=$_.Name}); $i++}
    Remove-Variable i

    # Display collections and read list of choices
    Write-Host "`nCollection(s)"
    Foreach ($collection in $deviceCollections) {
        Write-Host "[$($collection.Index)] $($collection.Name)"
    }
    [Int32[]]$collectionChoices = (Read-Host " ").Split(",")

    # What should the action be?
    $actionChoices = @{
        1 = "Install"
        2 = "Uninstall"
    }
    [Int32]$actionChoiceIndex = Read-Host "`nAction?
    [1] Install
    [2] Uninstall"
    
    # Should the deployment be available or required?
    $purposeChoices = @{
        1 = "Available"
        2 = "Required"
    }
    [Int32]$purposeChoiceIndex = Read-Host "`nDeployment purpose?
    [1] Available
    [2] Required"

    # Should requesting an installation need approval? (Only matters if purpose is "Available")
    if($purposeChoiceIndex -eq 1) {
        $approvalChoices = @{
            1 = $true
            2 = $false
        }
        [Int32]$approvalChoiceIndex = Read-Host "`nRequire approval for installation?
        [1] True
        [2] False"
    }

    # Deploy the specified applications to the device collections chosen
    Foreach ($applicationName in $applicationNames) {
        Foreach ($collectionChoice in $collectionChoices) {
            switch ($purposeChoiceIndex) {
                1 {
                    Get-CMApplication -Name $applicationName | New-CMApplicationDeployment `
                                                                -CollectionName $deviceCollections[$collectionChoice - 1].Name `
                                                                -DeployAction $actionChoices[$actionChoiceIndex] `
                                                                -DeployPurpose $purposeChoices[$purposeChoiceIndex] `
                                                                -UserNotification DisplaySoftwareCenterOnly `
                                                                -ApprovalRequired $approvalChoices[$approvalChoiceIndex] `
                                                             | Out-Null
                }
                2 {
                    Get-CMApplication -Name $applicationName | New-CMApplicationDeployment `
                                                                -CollectionName $deviceCollections[$collectionChoice - 1].Name `
                                                                -DeployAction $actionChoices[$actionChoiceIndex] `
                                                                -DeployPurpose $purposeChoices[$purposeChoiceIndex] `
                                                                -UserNotification DisplaySoftwareCenterOnly `
                                                                -OverrideServiceWindow $true `
                                                                -SendWakeupPacket $true `
                                                             | Out-Null
                }
            }
            if (Get-CMApplicationDeployment -Name $applicationName -CollectionName $deviceCollections[$collectionChoice - 1].Name) {
                Write-Host "`nCreated deployment for application [$($applicationName)] to collection [$($deviceCollections[$collectionChoice - 1].Name)]."
            }
        }
    }
}

Function Start-StandardSoftwareCenterDeployment {
    param(
        [Parameter(Mandatory=$true)]
        [String[]]$applicationNames
    )
    
    # "All Users" and "Systems Group Homies"
    Set-Location redacted:
    Foreach ($applicationName in $applicationNames) {
        Get-CMApplication -Name $applicationName | New-CMApplicationDeployment `
                                                    -CollectionName "All Users" `
                                                    -DeployAction Install `
                                                    -DeployPurpose Available `
                                                    -UserNotification DisplaySoftwareCenterOnly `
                                                    -ApprovalRequired $true `
                                                 | Out-Null
    

        Get-CMApplication -Name $applicationName | New-CMApplicationDeployment `
                                                    -CollectionName "Systems Group Homies" `
                                                    -DeployAction Install `
                                                    -DeployPurpose Available `
                                                    -UserNotification DisplayAll `
                                                    -ApprovalRequired $false `
                                                 | Out-Null

        if ((Get-CMApplicationDeployment -Name $applicationName -CollectionName "All Users") -and (Get-CMApplicationDeployment -Name $applicationName -CollectionName "redacted")) {
            Write-Host "`nAdded application [$($applicationName)] to Software Center."
        }
    }
}

Function Deploy-SCCMApplication {
    param(
        [String[]]$applicationNames
    )
    
    Import-Module -Name "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager"
    
    $startingDir = $PWD

    # If application(s) to deploy weren't given with input parameter, get them now
    if (!$applicationNames) {
        [String[]]$applicationNames = (Read-Host "`nApplication(s) to deploy").Split(",")
    }

    [Int32]$deploymentTarget = Read-Host "`nDeployment target
    [1] User collection
    [2] Device collection
    [3] Add to Software Center"

    switch ($deploymentTarget) {
    
        1 {
            Process-UserDeployments -applicationNames $applicationNames
        }
        2 {
            Process-DeviceDeployments -applicationNames $applicationNames
        }
        3 {
            Start-StandardSoftwareCenterDeployment -applicationNames $applicationNames
        }
        Default {
            Write-Host "`nSelect an option"
            Deploy-SCCMApplication
        }
    }
    Set-Location $startingDir
    Remove-Variable applicationNames
}

<#Function Deploy-SCCMApplication {
    param(
        [String[]]$applicationNames
    )

    if($applicationNames) {
        Controller -applicationNames $applicationNames 
    } else {
        Controller
    }
}#>
