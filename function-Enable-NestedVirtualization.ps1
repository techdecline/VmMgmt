<#
    .SYNOPSIS
        Enabled Nested Virtualization for a given Hyper-V Virtual Machine.
    .DESCRIPTION
        Enabled Nested Virtualization for a given Hyper-V Virtual Machine.

        It will set minumum static memory of 4096MB, expose virtulization capabilities
        to the virtual CPU and enable MAC Address Spoofing on the VM virtual network adapter.

        In order to do so, the virtual machine will be restarted if required.
    .EXAMPLE
        PS> Enable-NestedVirtualization -VMName Client1

        Enables Nested Virtualization on Client "Client1"

    .EXAMPLE
        PS> Add-Vm -VMName Client1 -Restart

        Enables Nested Virtualization on Client "Client1" and restarts the machine if required.
#>
function Enable-NestedVirtualization {
    [cmdletbinding()]
    param (
        # Select VM Name
        [Parameter(Mandatory,ValueFromPipeline)]
        [ValidateScript({Get-VM -VMName $_})]
        [String]
        $VMName,

        # Select to restart VM if required
        [Parameter(Mandatory=$false)]
        [Switch]
        $Restart,

        # Select optional network adapter name
        [Parameter(Mandatory=$false)]
        [String]
        $VMNetworkAdapterSwitchName
    )

    process {
        Write-Verbose "Selected machine name is: $VMName"
        $machineState = (Get-VM $VMName).State
        Write-Verbose "Current status is: $machineState"

        # Machine Power State
        switch ($machineState) {
            "Running" {
                if (-not ($Restart)) {
                    Write-Warning "Machine is currently running and restart option is missing. Will not continue"
                    return $false
                }
                else {
                    Write-Verbose "Will stop machine to configure Nested Virtualization."
                    Stop-VM -Name $VMName
                }
            }
            "Off" {
                Write-Verbose "Machine is not running. Will continue."
            }
        }

        # Memory setup
        $vmmObj = Get-VMMemory -VMName $VMName
        switch ($vmmObj.DynamicMemoryEnabled) {
            "true" {
                Write-Verbose "Dynamic memory needs to be disabled on VM: $VMName"
                Set-VMMemory -DynamicMemoryEnabled $false
            }
            "false" {
                Write-Verbose "Dynamic memory is configured correctly (is Disabled) on VM: $VMName"
            }
        }

        if ($vmmObj.Startup -ge 4096MB) {
            Write-Verbose "Memory Startup Bytes are sufficiently configured (greater equal 4096MB) on VM: $VMName"
        }
        else {
            Write-Verbose "Increasing Memory Startup Bytes to 4096MB on VM: $VMName"
            Set-VMMemory -StartupBytes 4096MB
        }
        # CPU Setup
        $vmpObj = Get-VMProcessor -VMName $VMName
        if ($vmpObj.Count -lt 2) {
            Write-Verbose "Will increase processor count to 2 on VM: $VMName"
            Set-VMProcessor -count 2 -VMName $VMName
        }
        if ($vmpObj.ExposeVirtualizationExtensions -eq $false) {
            Write-Verbose "Will enable processor vm extensions on VM: $VMName"
            try {
                Set-VMProcessor -VMName $VMName -ExposeVirtualizationExtensions $true -ErrorAction stop
            }
            catch [System.Management.Automation.ActionPreferenceStopException] {
                Write-Warning "Could not enable vCPU Virtualization extensions"
                return $false
            }
        }

        # MAC Address Spoofing
        if ($VMNetworkAdapterSwitchName) {
            Write-Verbose "Searching for VM Network Adapter on $VMName where switch is: $VMNetworkAdapterSwitchName"
            $vmNetworkAdapter = Get-VMNetworkAdapter -VMName $VMName | Where-Object {$_.SwitchName -eq $VMNetworkAdapterSwitchName}

            if ($vmNetworkAdapter) {
                Write-Verbose "Detected matching adapter with MAC Address: $($vmNetworkAdapter.MacAddress)"
            }
        }
        else {
            Write-Verbose "No Switch Name specified. Will query all adapters on VM: $VMName"
            $vmNetworkAdapter = Get-VMNetworkAdapter -VMName $VMName
        }

        foreach ($adapter in $vmNetworkAdapter) {
            if ($adapter.MacAddressSpoofing -eq "Off") {
                Write-Verbose "Will enable MAC Address spoofing on adapter with physical address: $($adapter.MacAddress)"
                try {
                    $adapter | Set-VMNetworkAdapter -MacAddressSpoofing On -ErrorAction Stop
                }
                catch [System.Management.Automation.ActionPreferenceStopException] {
                    Write-Warning "Could not enable vCPU Virtualization extensions"
                    return $false
                }
            }
            else {
                Write-Verbose "MAC Address spoofing already enabled on adapter with physical address: $($adapter.MacAddress)"
            }
        }
        return $true
    }
}