Write-LogEntry -Message "Executing $($MyInvocation.MyCommand.Name)"

$null = New-M365DSCConnection -Workload 'MicrosoftGraph' `
    -InboundParameters @{
    ApplicationId         = $ApplicationId
    TenantId              = $TenantName
    CertificateThumbprint = $CertificateThumbprint
}

$pol = Get-MgBetaPolicyAuthorizationPolicy

# 10dae51f-b6af-4016-8d66-8c2a99b929b3 = Guest
# 2af84b1e-32c8-42b7-82bc-daa82404023b = Restricted Guest
$result = $true
if ($pol.GuestUserRoleId -notin @('10dae51f-b6af-4016-8d66-8c2a99b929b3', '2af84b1e-32c8-42b7-82bc-daa82404023b'))
{
    $result = $false
}

$script:exportResults += [PSCustomObject]@{
    ResourceName            = 'AADCustomGuestUserAccessRestricted'
    ResourceInstanceName    = 'CIS-5.1.6.2'
    Id                      = 'Ensure that guest user access is restricted'
    GuestAccessIsRestricted = $result
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
