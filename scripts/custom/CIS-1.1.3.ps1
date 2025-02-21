Write-LogEntry -Message "Executing $($MyInvocation.MyCommand.Name)"

$null = New-M365DSCConnection -Workload 'MicrosoftGraph' `
    -InboundParameters @{
        ApplicationId = $ApplicationId
        TenantId = $TenantId
        CertificateThumbprint = $CertificateThumbprint
    }

# Determine Id of role using the immutable RoleTemplateId value.
$globalAdminRole = Get-MgBetaDirectoryRole -Filter "RoleTemplateId eq '62e90394-69f5-4237-9190-012177145e10'"
$globalAdmins = Get-MgBetaDirectoryRoleMember -DirectoryRoleId $globalAdminRole.Id | Where-Object { $_.AdditionalProperties.'@odata.type' -eq '#microsoft.graph.user' }

$numberOfGlobalAdmins = $globalAdmins.Count
$globalAdminsBetween2and4 = 'Correct'

if ($numberOfGlobalAdmins -lt 2)
{
    $globalAdminsBetween2and4 = 'Lower'
}

if ($numberOfGlobalAdmins -gt 4)
{
    $globalAdminsBetween2and4 = 'Higher'
}

$script:exportResults += [PSCustomObject]@{
    ResourceName             = 'AADCustomRoleMembership'
    ResourceInstanceName     = 'CIS-1.1.3'
    Id                       = 'Between two and four Global Admins'
    GlobalAdminsBetween2and4 = $globalAdminsBetween2and4
    NumberOfGlobalAdmins     = $numberOfGlobalAdmins
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
