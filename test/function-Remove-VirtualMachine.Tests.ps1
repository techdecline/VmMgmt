$moduleName = "vmMgmt"
Remove-Module $moduleName -Force -ErrorAction SilentlyContinue

Import-Module "$PSScriptRoot\..\$moduleName.psd1"

Describe "Remove-VirtualMachine Tests" {

}