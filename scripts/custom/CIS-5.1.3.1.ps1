Write-LogEntry -Message "Executing $($MyInvocation.MyCommand.Name)"

$null = New-M365DSCConnection -Workload 'MicrosoftGraph' `
    -InboundParameters @{
        ApplicationId = $ApplicationId
        TenantId = $TenantId
        CertificateThumbprint = $CertificateThumbprint
    }

$groups = Get-MgGroup -Filter "GroupTypes/any(x:x eq 'DynamicMembership')"
$guestGroups = foreach ($group in $groups)
{
    if ($group.MembershipRule -eq '(user.userType -eq "Guest")')
    {
        $group.DisplayName
    }
}

if ($null -eq $guestGroups)
{
    $script:exportResults += [PSCustomObject]@{
        ResourceName         = 'AADCustomAllGuestsGroup'
        ResourceInstanceName = "CIS-5.1.3.1"
        Id                   = "GroupName: Not Found"
        Exists               = $false
    }
}
else
{
    foreach ($guestGroup in $guestGroups)
    {
        $script:exportResults += [PSCustomObject]@{
            ResourceName         = 'AADCustomAllGuestsGroup'
            ResourceInstanceName = "CIS-5.1.3.1-{0}" -f $guestGroup
            Id                   = "GroupName: {0}" -f $guestGroup
            Exists               = $true
        }
    }
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
