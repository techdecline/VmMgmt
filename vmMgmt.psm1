# Implement your module commands in this script.

. "$PSScriptRoot\function-Set-VMUnattendFileForSpecialize.ps1"
. "$PSScriptRoot\function-Add-UnattendFileInImage.ps1"
. "$PSScriptRoot\function-Add-Vm.ps1"
. "$PSScriptRoot\function-Add-VMDisk.ps1"
. "$PSScriptRoot\function-Remove-VirtualMachine.ps1"
. "$PSScriptRoot\function-Enable-NestedVirtualization.ps1"

# Export only the functions using PowerShell standard verb-noun naming.
# Be sure to list each exported functions in the FunctionsToExport field of the module manifest file.
# This improves performance of command discovery in PowerShell.
#Export-ModuleMember -Function Remove-VirtualMachine,Add-VMDisk,Add-Vm
Export-ModuleMember -Function *-*