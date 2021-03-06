<#
    .SYNOPSIS
        Removes a local Hyper-V Virtual Machine.

    .DESCRIPTION
        Removes a local Hyper-V Virtual Machine and removes all attached disks optionally.

    .EXAMPLE
        PS> Remove-VirtualMachine -Name Client2 -WipeStorage

        Removes Client2 and deletes all hard disk drives that were attached in the moment of execution.

    .EXAMPLE
        PS> Remove-VirtualMachine -VM (Get-VM Client2)

        Removes Client2 and deletes all hard disk drives that were attached in the moment of execution.
#>
function Remove-VirtualMachine {

    [CmdletBinding(DefaultParameterSetName="ByVmName")]
    param (
        [Parameter(Mandatory,HelpMessage="Please enter an existing Virtual Machine",ParameterSetName="ByVmObject",ValueFromPipeline)]
        [Microsoft.HyperV.PowerShell.VirtualMachine]$VM,

        [Parameter(Mandatory,HelpMessage="Please enter an existing Virtual Machine name",ValueFromPipelineByPropertyName,Position=0)]
        [Alias("VMName")]
        [string]$Name,

        [Parameter(Mandatory=$false,HelpMessage="Select WipeStorage switch to remove all attached disks")]
        [Switch]$WipeStorage
    )

    begin {
        Write-Verbose "Selected Parameter Set is: $($PSCmdlet.ParameterSetName)"
        switch ($PSCmdlet.ParameterSetName) {
            "ByVmName" {
                $VM = get-vm $Name
            }
            "ByVmObject" {

            }
        }
    }
    process {
        if ($VM.State -ne "Off") {
            Write-Verbose "Stopping VM: $($VM.Name)"

            Stop-VM $VM -Force -TurnOff
        }

        Write-Verbose "Removing all existing VM snapshots"
        Get-VMSnapshot -VMName $VM.Name | Sort-Object -Property CreationTime -Descending | Remove-VMSnapshot -Confirm:$false

        if ($WipeStorage)
        {
            Write-Verbose "Wipe Storage selected: True"

            $diskArr = Get-VMHardDiskDrive -VM $VM
            foreach ($disk in $diskArr)
            {
                $diskPath = $disk.Path
                Remove-VMHardDiskDrive $disk
                Remove-Item -Path $diskPath
            }
        }
        else {
            Write-Verbose "Wipe Storage selected: False"
        }

        $vmPath = $VM.Path

        Remove-VM -VM $VM -Confirm:$false -Force

        if (-not (Get-ChildItem -Path $vmPath -Recurse -File)) {
            Write-Verbose "Removing virtual machine path: $vmPath"
            Remove-Item $vmPath -Recurse -Force
        }
    }

    end {
    }

}
