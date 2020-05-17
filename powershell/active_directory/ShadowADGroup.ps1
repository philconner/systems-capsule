    Maintains a Security Group that shadows an OU.

.DESCRIPTION
    This script will recursively search within a specified OU for computer objects, and ensure that they are in the Security Group specified.

.PARAMETER OUDistinguishedName
    The Organizational Unit to shadow, in distinguished name format.

.PARAMETER GroupName
    The Security Group to use.

.EXAMPLE
    Maintain-ShadowGroup.ps1 -OUDistinguishedName "redacted" -GroupName "Desktop Machines"
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$OUDistinguishedName,
    
    [Parameter(Mandatory=$true)]
    [String]$GroupName
)

Import-Module ActiveDirectory

# Check if the group exists
$group = Get-ADGroup -Identity $GroupName -Properties members
if (-Not $group) {
    Throw "No AD group with the name '$($GroupName)' exists."
}
    
# Search for computer objects within the OU
$computers = Get-ADComputer -SearchBase $OUDistinguishedName -SearchScope Subtree -LDAPFilter "(objectClass=computer)" -Properties memberOf
    
# Add computers from OU to the group
ForEach ($computer in $computers) {
    if ($computer.memberOf -notcontains $group.distinguishedName) {
        Add-ADGroupMember -Identity $group -Members $computer
    }
}

# Remove computers from the group that are not in OU
ForEach ($member in $group.members) {
    if (-Not $member -match $OUDistinguishedName) {
        Remove-ADGroupMember -Identity $group -Members $member -Confirm:$false
        Write-Host "Removing member [$member] from group [$group] because [$OUDistinguishedName] is not a substring of [$member]"
    }
}
