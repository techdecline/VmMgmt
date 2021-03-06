<#
    .SYNOPSIS
    .DESCRIPTION
    .EXAMPLE
#>
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
