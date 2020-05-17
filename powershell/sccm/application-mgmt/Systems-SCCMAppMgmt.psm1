. "$PSScriptRoot\Deploy-SCCMApplication.ps1"
. "$PSScriptRoot\Add-SCCMApplication\Add-SCCMApplication.ps1"

Export-ModuleMember -Function Deploy-SCCMApplication
Export-ModuleMember -Function Add-SCCMApplication
