<#
    .SYNOPSIS
    .DESCRIPTION
    .EXAMPLE
#>
function Add-UnattendFileInImage {
    [CmdletBinding()]
    param (
        # Unattend File Path
        [Parameter(Mandatory=$false)]
        [String]$UnattendFilePath = "C:\Code\VmMgmt\Unattend\Windows10_x64_GermanInput.xml" ,

        # Image Path
        [Parameter(Mandatory=$false)]
        [String]$ImagePath = 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\REF-W10.vhdx'
    )

    Import-Module Hyper-V
    Mount-VHD -Path $ImagePath

    $DriveLetter=(Get-DiskImage $ImagePath | get-disk | get-partition | Where-Object {$_.Size -GT 1GB}).DriveLetter
    $DestinationUnattend = $DriveLetter + ":\Windows\System32\Sysprep\unattend.xml"

    try
    {
        Copy-Item -Path $UnattendFilePath -Destination $DestinationUnattend -Force -ErrorAction Stop
        $success = $true
    }
    catch [System.Management.Automation.ActionPreferenceStopException]
    {
        $success = $false
        Write-Warning -Message "Could not copy unattend file to VHD $ImagePath"
    }
    finally
    {
        Dismount-DiskImage -ImagePath $ImagePath
    }
    return $success

}
