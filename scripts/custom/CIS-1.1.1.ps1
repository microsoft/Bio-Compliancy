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
    $_.DisplayName -like "*Administrator*" -or $_.DisplayName -eq "Global Reader"
}

# Get the members of these various roles
$RoleMembers = $PrivilegedRoles | ForEach-Object { Get-MgBetaDirectoryRoleMember -DirectoryRoleId $_.Id } | Where-Object { $_.AdditionalProperties."@odata.type" -ne "#microsoft.graph.servicePrincipal" } | Select-Object -Property Id -Unique

# Retrieve details about the members in these roles
$PrivilegedUsers = $RoleMembers | ForEach-Object {
    Get-MgUser -UserId $_.Id -Property UserPrincipalName, DisplayName, Id, OnPremisesSyncEnabled -ErrorAction SilentlyContinue
}

$NonCloudOnlyAdminAccounts = $PrivilegedUsers | Where-Object { $_.OnPremisesSyncEnabled -eq $true }

$nonCompliantAccounts = @()
if ($null -ne $NonCloudOnlyAdminAccounts)
{
    $nonCompliantAccounts = $PrivilegedUsers.UserPrincipalName
}

$script:exportResults += [PSCustomObject]@{
    ResourceName              = 'AADCustomCloudOnlyAdminAccounts'
    ResourceInstanceName      = 'CIS-1.1.1'
    Id                        = 'Non-Cloud Only Admin Accounts'
    NonCloudOnlyAdminAccounts = $nonCompliantAccounts
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
