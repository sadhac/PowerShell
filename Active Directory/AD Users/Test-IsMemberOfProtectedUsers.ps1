function Test-IsMemberOfProtectedUsers {
    <#
        .SYNOPSIS
            Check to see if a user is a member of the Protected Users group.

        .DESCRIPTION
            This function checks to see if a specified user or the current user is a member of the Protected Users group in AD.
            It also checked the user's primary group ID in case that is set to 525 (Protected Users).

        .PARAMETER User
            The user that will be checked for membership in the Protected Users group. This parameter accepts input from the pipeline.

        .EXAMPLE
            This example will check if JaneDoe is a member of the Protected Users group.

            Test-IsMemberOfProtectedUsers -User JaneDoe

        .EXAMPLE
            This example will check if the current user is a member of the Protected Users group.

            Test-IsMemberOfProtectedUsers

        .INPUTS
            Active Directory user object, user SID, SamAccountName, etc

        .OUTPUTS
            True, False

        .NOTES
            Author:     Sam Erde (https://linktr.ee/SamErde)
            Modified:   2024-02-16
            Version:    0.1.0

            Membership in Active Directory's Protect Users group can have implications for anything that relies on NTLM authentication.

            To Do:
            - Make it work with multiple Active Directory domains in a forest.
    #>

    [CmdletBinding()]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [OutputType([System.Boolean])]
    param (
        # User parameter accepts any input that is valid for Get-ADUser
        [Parameter(
            ValueFromPipeline = $true
        )]
        $User
    )

    begin {
        Import-Module ActiveDirectory
    }

    process {
        # Use the currently logged in user if none is specified
        # Get the user from Active Directory
        if (-not($User)) {
            # These two are different types. Fixed by referencing $CheckUser.SID later, but should fix here by using one type.
            $CurrentUser = ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name).Split('\')[-1]
            $CheckUser = Get-ADUser $CurrentUser -Properties primaryGroupID
        } else {
            $CheckUser = Get-ADUser $User -Properties primaryGroupID
        }

        # Get the Protected Users group by SID instead of by its name to ensure compatibility with any locale or language.
        $DomainSID = (Get-ADDomain).DomainSID.Value
        $ProtectedUsersSID = "$DomainSID-525"

        # Get members of the Protected Users group for the current domain. Recuse in case groups are nested in it.
        $ProtectedUsers = Get-ADGroupMember -Identity $ProtectedUsersSID -Recursive | Select-Object -Unique

        # Check if the current user is in the 'Protected Users' group
        if ($ProtectedUsers.SID.Value -contains $CheckUser.SID) {
            Write-Verbose "$($CheckUser.Name) ($($CheckUser.DistinguishedName)) is a member of the Protected Users group."
            $true
        } else {
            # Check if the user's PGID (primary group ID) is set to the Protected Users group RID (525).
            if ( $CheckUser.primaryGroupID -eq '525' ) {
                $true
            } else {
                Write-Verbose "$($CheckUser.Name) ($($CheckUser.DistinguishedName)) is not a member of the Protected Users group."
                $false
            }
        }
    }

    end { }

}
