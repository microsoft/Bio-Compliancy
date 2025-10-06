Write-LogEntry -Message "Executing $($MyInvocation.MyCommand.Name)"

$null = New-M365DSCConnection -Workload 'MicrosoftGraph' `
    -InboundParameters @{
        ApplicationId         = $ApplicationId
        TenantId              = $TenantId
        CertificateThumbprint = $CertificateThumbprint
    }

$DirectoryRoles = Get-MgBetaDirectoryRole

# Get privileged role IDs
$PrivilegedRoles = $DirectoryRoles | Where-Object {
    $_.DisplayName -like '*Administrator*' -or $_.DisplayName -eq 'Global
Reader'
}

# Get the members of these various roles
$RoleMembers = $PrivilegedRoles | ForEach-Object { Get-MgBetaDirectoryRoleMember -DirectoryRoleId $_.Id } | Where-Object { $_.AdditionalProperties.'@odata.type' -ne '#microsoft.graph.servicePrincipal' } | Select-Object Id -Unique

# Retrieve details about the members in these roles
$PrivilegedUsers = $RoleMembers | ForEach-Object {
    Get-MgUser -UserId $_.Id -Property UserPrincipalName, DisplayName, Id -ErrorAction SilentlyContinue
}

$usersWithLicense = [System.Collections.Generic.List[Object]]::new()

foreach ($Admin in $PrivilegedUsers)
{
    $license = $null
    $license = (Get-MgUserLicenseDetail -UserId $Admin.id).SkuPartNumber -join ', '
    if ([String]::IsNullOrEmpty($license) -eq $false)
    {
        $usersWithLicense.Add("$($Admin.UserPrincipalName) ($license)")
    }
}

$script:exportResults += [PSCustomObject]@{
    ResourceName             = 'AADCustomAdminAccountsWithoutLicense'
    ResourceInstanceName     = 'CIS-1.1.4'
    Id                       = 'Admin Accounts without License'
    AdminAccountsWithLicense = $usersWithLicense.ToArray()
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
