# Implement your module commands in this script.

function Add-UnattendFileInImage  {
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

function Remove-VirtualMachine {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,HelpMessage="Please enter an existing Virtual Machine",ParameterSetName="ByVmObject")]
        [Microsoft.HyperV.PowerShell.VirtualMachine]$VM,

        [Parameter(Mandatory,HelpMessage="Please enter an existing Virtual Machine name",ParameterSetName="ByVmName",ValueFromPipelineByPropertyName)]
        [Alias("Name")]
        [Microsoft.HyperV.PowerShell.VirtualMachine]$VMName,

        [Parameter(Mandatory=$false,HelpMessage="Select WipeStorage switch to remove all attached disks")]
        [Switch]$WipeStorage
    )

    process {
        if ($VM.State -ne "Off")
        {
            Stop-VM $VM -Force
        }

        Get-VMSnapshot -VMName $VM.Name | Remove-VMSnapshot -IncludeAllChildSnapshots -Confirm:$false

        if ($WipeStorage)
        {
            $diskArr = Get-VMHardDiskDrive -VM $VM
            foreach ($disk in $diskArr)
            {
                $diskPath = $disk.Path
                Remove-VMHardDiskDrive $disk
                Remove-Item -Path $diskPath
            }
        }

        $vmPath = $VM.Path

        Remove-VM -VM $VM -Confirm:$false -Force
        Remove-Item $vmPath -Recurse -Force
    }

    end {
    }
}

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

function Set-VMUnattendFileForSpecialize {
    [CmdletBinding()]
    param (
        # Unattend File Path for Modification
        [Parameter(Mandatory,ValueFromPipeline)]
        [ValidateScript({Test-Path $_})]
        [string]$UnattendFilePath,

        # Hostname for virtual machine
        [Parameter(Mandatory=$true)]
        [string]$VMName,

        # Organization for virtual machine
        [Parameter(Mandatory=$false)]
        [string]$Organization = "Unknown Organization",

        # Owner for virtual machine
        [Parameter(Mandatory=$false)]
        [string]$Owner = "Unknown Owner",

        # Owner for virtual machine
        [Parameter(Mandatory=$false)]
        [ValidateSet("W. Europe Standard Time")]
        [string]$TimeZone = "W. Europe Standard Time",

        # Switch to enable domain join (unsecure)
        [Parameter(Mandatory=$false,ParameterSetName="WithDomainJoin")]
        [Switch]$JoinDomain,

        # Domain Name for Join
        [Parameter(Mandatory,ParameterSetName="WithDomainJoin")]
        [string]$DomainName
    )

    begin {
    }

    process {
        $input
        <#
        # Edit unattend.xml Template
        $Unattendfile=New-Object XML
        $Unattendfile.Load($scriptPath+"\"+$UnattendTemplate)
        $Unattendfile.unattend.settings.component[0].ComputerName=$VMName
        #$Unattendfile.unattend.settings.component[0].ProductKey=$ProductKey
        $Unattendfile.unattend.settings.component[0].RegisteredOrganization=$Organization
        $Unattendfile.unattend.settings.component[0].RegisteredOwner=$Owner
        $Unattendfile.unattend.settings.component[0].TimeZone=$TimeZone
        if ($JoinDomain)
        {
            $Unattendfile.unattend.settings.component[1].Identification.Credentials.Domain=$DomainName
            $Unattendfile.unattend.settings.component[1].Identification.Credentials.Password=$DomainJoinPassword
            $Unattendfile.unattend.settings.component[1].Identification.Credentials.Username=$DomainJoinAccount
            $Unattendfile.unattend.settings.component[1].Identification.JoinDomain = $DomainName

            $Unattendfile.unattend.settings.Component[2].RegisteredOrganization=$Organization
            $Unattendfile.unattend.settings.Component[2].RegisteredOwner=$Owner
            $UnattendFile.unattend.settings.component[2].UserAccounts.AdministratorPassword.Value=$AdminPassword
            $UnattendFile.unattend.settings.component[2].autologon.password.value=$AdminPassword
        }
        else
        {
            $xmlElement = ($UnattendFile.unattend.settings[0].component | Where-Object {$_.name -match "Join"})
            $UnattendFile.unattend.settings[0].RemoveChild($xmlElement)

            $Unattendfile.unattend.settings.Component[1].RegisteredOrganization=$Organization
            $Unattendfile.unattend.settings.Component[1].RegisteredOwner=$Owner
            $UnattendFile.unattend.settings.component[1].UserAccounts.AdministratorPassword.Value=$AdminPassword
            $UnattendFile.unattend.settings.component[1].autologon.password.value=$AdminPassword
        }
        $UnattendXML=$scriptPath+"\"+$VMName+".xml"
        $Unattendfile.save($UnattendXML)
        #>
    }

    end {
    }
}
function Add-Vm {
    [CmdletBinding()]
    [outputtype([Microsoft.HyperV.PowerShell.VirtualMachine])]
    param (
        # New VM Name
        [Parameter(Mandatory,HelpMessage="Please enter a name for the new Virtual Machine")]
        [String]$VMName,

        # Base Path
        [Parameter(Mandatory,HelpMessage="The Base Path serves as directory for newly created disks and Virtual Machine files")]
        [ValidateScript({Test-Path -Path $_ -PathType Container})]
        [String]$BasePath = "D:\VM",

        # Switch Name
        [Parameter(Mandatory=$false,HelpMessage="Please select an existing network switch for your Virtual Machine")]
        [ValidateScript({Get-VMSwitch -Name $_})]
        [string]$SwitchName = "Lab1",

        # Virtual Disk Size
        [Parameter(Mandatory,HelpMessage="Select a size for your new Virtual Machine Hard Disk [Minimum 32GB]",ParameterSetName="ByNewDisk")]
        [ValidateScript({$_ -ge 32GB})]
        [int64]$NewVHDSizeBytes = 32GB,

        # Memory Startup Bytes
        [Parameter(Mandatory=$false,HelpMessage="Select how much memory the new Virtual Machine should be allocating")]
        [ValidateRange(512MB,8GB)]
        [Int64]$MemoryStartupBytes = 2048MB,

        # Master Image Path
        [Parameter(Mandatory,HelpMessage="Select an existing disk image to be used as template [sysprepped; vhd/vhdx format] ",ParameterSetName="ByMasterImage")]
        [ValidateScript({Test-Path -Path $_ -PathType Leaf})]
        [ValidatePattern("^.*`.vhd[x]{0,1}$")]
        [string]$MasterImagePath,

        # Unattend File
        [Parameter(Mandatory=$false,HelpMessage="Select an Unattend File to be included in new VM",ParameterSetName="ByMasterImage")]
        [ValidateScript({Test-Path -Path $_ -PathType Leaf})]
        [string]$UnattendFilePath,

        # Select to create differencing disk
        [Parameter(Mandatory=$false,ParameterSetName="ByMasterImage")]
        [switch]$DifferencingDisk
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
            if ($DifferencingDisk) {
                $newVhd = (New-VHD -ParentPath $MasterImagePath -Path (Join-Path $basePath -ChildPath "$VMName.vhdx") -Differencing).Path
            }
            else {
                $newVhd = (Copy-Item $MasterImagePath -Destination (Join-Path $basePath -ChildPath "$VMName.vhdx") -PassThru).FullName
            }
            $param += @{"VHDPath" = $newVhd}
            if ($UnattendFilePath) {
                Add-UnattendFileInImage -UnattendFilePath $UnattendFilePath -ImagePath $newVhd
            }
        }
        else {
            $newVhd = (Join-Path $basePath -ChildPath "$VMName.vhdx")
            $param += @{"NewVHDPath" = $newVhd}
            $param += @{"NewVHDSizeBytes" = $NewVHDSizeBytes}
        }
        New-VM @param | Out-Null

        if (-not ($MasterImagePath)) {
            Set-VMFirmware -VMName $VMName -EnableSecureBoot On -FirstBootDevice (Get-VMNetworkAdapter -VMName $VMName)
        }
        Set-VMProcessor -VMName $VMName -Count 2
        Set-VMKeyProtector -VMName $VMName -NewLocalKeyProtector
        Enable-VMTPM -VMName $VMName
        Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $false
        set-vm -Name $VMName -AutomaticCheckpointsEnabled $false

        return (Get-VM -Name $VMName)
    }

    end {
    }
}
# Export only the functions using PowerShell standard verb-noun naming.
# Be sure to list each exported functions in the FunctionsToExport field of the module manifest file.
# This improves performance of command discovery in PowerShell.
Export-ModuleMember -Function Remove-VirtualMachine,Add-VMDisk,Add-Vm