$Computer = Read-Host "`nComputer Name"

function Get-CMCollectionOfDevice
{
    [CmdletBinding()]
    [OutputType([int])]
    Param
    (
        # Computername
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   Position=0)]
        [String]$Computer,
 
        # ConfigMgr SiteCode
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [String]$SiteCode = "redacted",
 
        # ConfigMgr SiteServer
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=2)]
        [String]$SiteServer = "redacted"
    )
Begin
{
    [string] $Namespace = "root\SMS\site_$SiteCode"
}
 
Process
{
    $si=1
    Write-Progress -Activity "Retrieving ResourceID for computer $computer" -Status "Retrieving data" 
    $ResIDQuery = Get-WmiObject -ComputerName $SiteServer -Namespace $Namespace -Class "SMS_R_SYSTEM" -Filter "Name='$Computer'"
    
    If ([string]::IsNullOrEmpty($ResIDQuery))
    {
        Write-Output "System $Computer does not exist in Site $SiteCode"
    }
    Else
    {
    $Collections = (Get-WmiObject -ComputerName $SiteServer -Class sms_fullcollectionmembership -Namespace $Namespace -Filter "ResourceID = '$($ResIDQuery.ResourceId)'")
    $colcount = $Collections.Count
    
    $devicecollections = @()
    ForEach ($res in $collections)
    {
        $colid = $res.CollectionID
        Write-Progress -Activity "Processing  $si / $colcount" -Status "Retrieving Collection data" -PercentComplete (($si / $colcount) * 100)
 
        $collectioninfo = Get-WmiObject -ComputerName $SiteServer -Namespace $Namespace -Class "SMS_Collection" -Filter "CollectionID='$colid'"
        $object = New-Object -TypeName PSObject
        $object | Add-Member -MemberType NoteProperty -Name "CollectionID" -Value $collectioninfo.CollectionID
        $object | Add-Member -MemberType NoteProperty -Name "Name" -Value $collectioninfo.Name
        $object | Add-Member -MemberType NoteProperty -Name "Comment" -Value $collectioninfo.Comment
        $object | Add-Member -MemberType NoteProperty -Name "LastRefreshTime" -Value ([Management.ManagementDateTimeConverter]::ToDateTime($collectioninfo.LastRefreshTime))
        $devicecollections += $object
        $si++
    }
} # end check system exists
}
 
End
{
    $devicecollections
}
}

$Computer | Get-CMCollectionOfDevice
