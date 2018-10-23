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
        [switch]$DifferencingDisk,

        [Parameter(Mandatory=$false,HelpMessage="Specify to start VM immediatly after creation")]
        [Switch]$StartVM
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

        if ($StartVM) {
            Start-VM -Name $VMName
        }
        return (Get-VM -Name $VMName)
    }

    end {
    }

}
