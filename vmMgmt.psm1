# Implement your module commands in this script.

function Remove-VirtualMachine {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String]$VMName,

        [Parameter(Mandatory=$false)]
        [Switch]$WipeStorage
    )

    begin {
        Import-Module Hyper-V
    }

    process {
        Get-VM $VMName -OutVariable virtualMachine

        if ($virtualMachine.State -ne "Off")
        {
            Stop-VM $virtualMachine -Force
        }

        Get-VMSnapshot -VMName $virtualMachine.Name | Remove-VMSnapshot -IncludeAllChildSnapshots -Confirm:$false

        if ($WipeStorage)
        {
            $diskArr = Get-VMHardDiskDrive -VM $virtualMachine
            foreach ($disk in $diskArr)
            {
                $diskPath = $disk.Path
                Remove-VMHardDiskDrive $disk
                Remove-Item -Path $diskPath
            }
        }

        $vmPath = $virtualMachine.Path

        Remove-VM -VM $virtualMachine -Confirm:$false -Force
        Remove-Item $vmPath -Recurse -Force
    }

    end {
    }
}

function Add-VMDisk {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,HelpMessage="Please enter a Virtual Machine Name")]
        [ValidateScript({ Get-VM -VMName $_})]
        [String]$VMName,

        [Parameter(Mandatory=$false,HelpMessage="Please enter a directory for new disks")]
        [String]$VHDLocation,

        [Parameter(Mandatory=$true,HelpMessage="Please select a name for new VHD.")]
        [ValidatePattern("^.*`.vhd[x]{0,1}$")]
        [String]$DiskName,

        [Parameter(Mandatory=$false,HelpMessage="Please enter the VHD Size")]
        [Int64]$SizeBytes = 128GB,

        [Parameter(Mandatory=$true,HelpMessage="Please provide a PSCredential Object")]
        [PSCredential]$GuestCredential,

        [Parameter(Mandatory=$false,HelpMessage="Please provide a Drive Letter for the new disk")]
        [Char]$DriveLetter
    )

    begin {
        Import-Module Hyper-V
    }

    process {
        # Create VHD Location Dir if not existing
        if (!($VHDLocation)) {
            $VHDLocation = Get-VMHost -ComputerName localhost | Select-Object -ExpandProperty VirtualhardDiskPath
        }

        if (!(Test-Path $VHDLocation)) {
            New-Item $VHDLocation -ItemType Directory -Force
        }
        # Generate VM Disk Full Name
        $vhdPath = Join-Path -Path $VHDLocation -ChildPath $DiskName
        Write-Verbose "Virtual Hard Disk Path will be $vhdpath"

        # Create Virtual Hard Disk
        $vhd = New-VHD -Path $vhdPath -SizeBytes $SizeBytes -Dynamic

        # Connect VHD to Virtual Machine
        $vhd = Add-VMHardDiskDrive -VMName $VMName -Path $vhdPath -Passthru

        # Format and Partition drive inside VM
        if ((get-vm -VMName $VMName).State -eq "Running") {
            # Enter Virtual Machine Session to format and partition drive
            $GuestDiskName = ($DiskName.Split("`."))[0]
            Invoke-Command -VMName $VMName -Credential $GuestCredential -ArgumentList $DriveLetter,$GuestDiskName -ScriptBlock {
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
        return $vhd
    }

    end {
    }
}

function Add-Vm {
    [CmdletBinding()]
    param (
        # New VM Name
        [Parameter(Mandatory=$true)]
        [String]$VMName,

        # Base Path
        [Parameter(Mandatory=$false)]
        [ValidateScript({Test-Path $_})]
        [String]$BasePath = "D:\VM",

        # Switch Name
        [Parameter(Mandatory=$false)]
        [string]$SwitchName = "Lab1",

        # Virtual Disk Size
        [Parameter(Mandatory=$false)]
        [int64]$NewVHDSizeBytes = 32GB,

        # Memory Startup Bytes
        [Parameter(Mandatory=$false)]
        [Int64]$MemoryStartupBytes = 2048MB,

        # Master Image Path
        [Parameter(Mandatory=$false)]
        [ValidateScript({Test-Path $_})]
        [string]$MasterImagePath
    )

    begin {
        Import-Module Hyper-V
    }

    process {
        $param = @{
            Name = $VMName;
            SwitchName = $SwitchName;
            Generation = "2";
            Path = $BasePath;
            MemoryStartupBytes = $MemoryStartupBytes
        }

        if ($MasterImagePath) {
            $newVhd = (Copy-Item $MasterImagePath -Destination (Join-Path $basePath -ChildPath "$VMName.vhdx") -PassThru).FullName
            $param += @{"VHDPath" = $newVhd}
        }
        else {
            $newVhd = (Join-Path $basePath -ChildPath "$VMName.vhdx")
            $param += @{"NewVHDPath" = $newVhd}
            $param += @{"NewVHDSizeBytes" = $NewVHDSizeBytes}
        }
        New-VM @param
        Set-VMFirmware -VMName $VMName -EnableSecureBoot On -FirstBootDevice (Get-VMNetworkAdapter -VMName $VMName)
        Set-VMProcessor -VMName $VMName -Count 2
        Set-VMKeyProtector -VMName $VMName -NewLocalKeyProtector
        Enable-VMTPM -VMName $VMName
        Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $false
        set-vm -Name $VMName -AutomaticCheckpointsEnabled $false
    }

    end {
    }
}
# Export only the functions using PowerShell standard verb-noun naming.
# Be sure to list each exported functions in the FunctionsToExport field of the module manifest file.
# This improves performance of command discovery in PowerShell.
Export-ModuleMember -Function Remove-VirtualMachine,Add-VMDisk,Add-Vm