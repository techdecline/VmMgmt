<#
    .SYNOPSIS
        Injects a given Unattend XML file into a virtual hard disk drive.
    .DESCRIPTION
        Injects a given Unattend XML file into a virtual hard disk drive by first mounting the VHD and copying over the selected
        Unattend File.
    .EXAMPLE
        PS> Add-UnattendFileInImage -UnattendFilePath "C:\Code\Workbench\Contoso_Win10.xml" -ImagePath "C:\VHD\Client1.vhdx"

        This command will inject the Contoso_Win10.xml into the VHD C:\VHD\Client1.vhdx
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
