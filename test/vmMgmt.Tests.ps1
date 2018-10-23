$ModuleManifestName = 'vmMgmt.psd1'
$ModuleName = ($ModuleManifestName -split "\.")[0]
$ModuleManifestPath = "$PSScriptRoot\..\$ModuleManifestName"

Describe "$ModuleName Manifest Tests" {
    Context "Module Setup" {
        It 'Passes Test-ModuleManifest' {
            Test-ModuleManifest -Path $ModuleManifestPath
            $? | Should Be $true
        }

        It  "Has Root Module $ModuleName.psm1" {
            "$PSScriptRoot\..\$ModuleName.psm1" | Should exist
        }

        It "$moduleName is valid PowerShell code" {
            $psFile = Get-Content -Path "$PSScriptRoot\..\$moduleName.psm1" `
                                  -ErrorAction Stop
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($psFile, [ref]$errors)
            $errors.Count | Should Be 0
        }
    } # Context Module Setup

    Context "Unattend Files" {
        It 'Has required Unattend File "Windows10_x64_GermanInput"' {
            "$PSScriptRoot\..\Unattend\Windows10_x64_GermanInput.xml" | Should exist
        }
    <#
        It 'Has required Unattend File "Windows10_x64_EnglishInput"' {
            "$PSScriptRoot\..\Unattend\Windows10_x64_EnglishInput.xml" | Should exist
        }#>
    } # Context Unattend Files
}