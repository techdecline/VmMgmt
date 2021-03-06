<#
    .SYNOPSIS
        Adds a hard disk to a local Hyper-V virtual machine.

    .DESCRIPTION
        Adds a hard disk to a local Hyper-V virtual machine and either adds it to the primordial pool for storage space usage
        or formats the disk within the target VM.

    .EXAMPLE
        PS> Add-VMDisk -Name Client1 -VHDLocation C:\VM -DiskName Client1-Data.vhdx -GuestCredential contoso\administrator -SizeBytes 16GB -DiskLetter F

    .EXAMPLE
        PS> Add-VMDisk -Name Client1 -VHDLocation C:\VM -DiskName Client1-Data.vhdx -AddToPrimordialPool -SizeBytes 16GB
#>
function Add-VMDisk {

    [CmdletBinding()]
    [outputtype([Microsoft.Vhd.PowerShell.VirtualHardDisk])]
    param (
        [Parameter(Mandatory,HelpMessage="Please enter an existing Virtual Machine name",ValueFromPipelineByPropertyName)]
        [ValidateScript({ Get-VM -VMName $_})]
        [Alias("VMName")]
        [String]$Name,

        [Parameter(Mandatory=$false,HelpMessage="Please enter a directory for new disks")]
        [String]$VHDLocation,

        [Parameter(Mandatory,HelpMessage="Please select a name for new VHD.",ValueFromPipelineByPropertyName)]
        [ValidatePattern("^.*`.vhd[x]{0,1}$")]
        [String]$DiskName,

        [Parameter(Mandatory=$false,HelpMessage="Please enter the VHD Size")]
        [Int64]$SizeBytes = 128GB,

        [Parameter(Mandatory=$false,ParameterSetName="ByStorageSpace")]
        [switch]$AddToPrimordialPool,

        [Parameter(Mandatory,HelpMessage="Please provide a PSCredential Object",ParameterSetName="ByVolume")]
        [PSCredential]$GuestCredential,

        [Parameter(Mandatory=$false,HelpMessage="Please provide a Drive Letter for the new disk",ParameterSetName="ByVolume")]
        [Char]$DriveLetter
    )

    begin {
        # Create VHD Location Dir if not existing
        if (!($VHDLocation)) {
            $VHDLocation = Get-VMHost -ComputerName localhost | Select-Object -ExpandProperty VirtualhardDiskPath
        }

        if (!(Test-Path $VHDLocation)) {
            New-Item $VHDLocation -ItemType Directory -Force
        }
    }
    process {
        # Generate VM Disk Full Name
        $vhdPath = Join-Path -Path $VHDLocation -ChildPath $DiskName
        Write-Verbose "Virtual Hard Disk Path will be $vhdpath"

        # Create Virtual Hard Disk
        try {
            $vhd = New-VHD -Path $vhdPath -SizeBytes $SizeBytes -Dynamic -ErrorAction Stop
        }
        catch [System.Management.Automation.ActionPreferenceStopException] {
            Write-Error -Message "Disk $vhdPath is already present or cannot be created"
            return $null
        }
        # Connect VHD to Virtual Machine
        $vhd = Add-VMHardDiskDrive -VMName $Name -Path $vhdPath -Passthru

        if ($GuestCredential) {
            # Format and Partition drive inside VM
            if ((get-vm -VMName $Name).State -eq "Running") {
                # Enter Virtual Machine Session to format and partition drive
                $GuestDiskName = ($DiskName.Split("`."))[0]
                Invoke-Command -VMName $Name -Credential $GuestCredential -ArgumentList $DriveLetter,$GuestDiskName -ScriptBlock {
                    param (
                        [String]$DriveLetter,
                        [String]$DiskName
                    )

                    $newDisk = Get-PhysicalDisk | Where-Object {$_.CanPool -eq $true}
                    $newDisk | Get-Disk | Set-Disk -IsOffline:$false
                    $newDisk | Get-Disk | Initialize-Disk -PartitionStyle GPT

                    # Check Drive Letter
                    if (!($DriveLetter)) {
                        $newDisk | Get-Disk | New-Partition -UseMaximumSize -AssignDriveLetter | Format-Volume `
                            -FileSystem NTFS -NewFileSystemLabel $DiskName
                    }
                    else {
                        $newDisk | Get-Disk | New-Partition -UseMaximumSize -DriveLetter $DriveLetter | Format-Volume `
                            -FileSystem NTFS -NewFileSystemLabel $DiskName
                    }
                } | Out-Null
            }
        }
        $vhd
    }

    end {
    }

}
