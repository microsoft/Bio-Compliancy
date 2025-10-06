Write-LogEntry -Message "Executing $($MyInvocation.MyCommand.Name)"

$null = New-M365DSCConnection -Workload 'MicrosoftGraph' `
    -InboundParameters @{
        ApplicationId = $ApplicationId
        TenantId = $TenantId
        CertificateThumbprint = $CertificateThumbprint
    }

# Corrected various role names
$includedRoles = @('Application Administrator', 'Authentication Administrator', 'Billing Administrator', 'Cloud Application Administrator', 'Cloud Device Administrator', 'Compliance Administrator', 'Customer LockBox Access Approver', 'Exchange Administrator', 'Global Administrator', 'HelpDesk Administrator', 'Azure Information Protection Administrator', 'Intune Administrator', 'Kaizala Administrator', 'License Administrator', 'Microsoft Entra Joined Device Local Administrator', 'Password Administrator', 'Fabric Administrator', 'Privileged Authentication Administrator', 'Privileged Role Administrator', 'Security Administrator', 'SharePoint Administrator', 'Skype for Business Administrator', 'Teams Administrator', 'User Administrator')

$allRoles = Get-MgBetaRoleManagementDirectoryRoleDefinition | Where-Object { $_.DisplayName -in $includedRoles }
$allPermanentAssignments = Get-MgBetaRoleManagementDirectoryRoleAssignmentSchedule | Where-Object { $_.AssignmentType -eq 'Assigned' }
$applicablePermanentAssignments = @{}
foreach ($permAssign in $allPermanentAssignments)
{
    $currentRole = $allRoles | Where-Object { $_.Id -eq $permAssign.RoleDefinitionId }
    Write-LogEntry -Message "Current Role: $($currentRole.DisplayName)" -Type Verbose
    if ($null -ne $currentRole)
    {
        $principal = Get-MgUser -UserId $permAssign.PrincipalId -ErrorAction SilentlyContinue
        $principalName = $null
        if ($null -eq $principal)
        {
            #Write-Host "Did not find User'$($permAssign.PrincipalId)'"
            $principal = Get-MgGroup -GroupId $permAssign.PrincipalId -ErrorAction SilentlyContinue
            if ($null -eq $principal)
            {
                Write-LogEntry -Message 'Found Service Principal -> Ignore!' -Type Verbose
                continue
            }
            else
            {
                $principalName = $principal.UserPrincipalName
                Write-LogEntry -Message "Found Group: $principalName" -Type Verbose
            }
        }
        else
        {
            $principalName = $principal.UserPrincipalName
            Write-LogEntry -Message "Found User: $principalName" -Type Verbose
        }

        if ($applicablePermanentAssignments.ContainsKey($currentRole.DisplayName))
        {
            $applicablePermanentAssignments.$($currentRole.DisplayName) += $principalName
        }
        else
        {
            $applicablePermanentAssignments.$($currentRole.DisplayName) += @($principalName)
        }
    }
}

$results = foreach ($applicableAssignment in $applicablePermanentAssignments.GetEnumerator())
{
    foreach ($role in $applicableAssignment.Value)
    {
        '{0}: {1}' -f $applicableAssignment.Key, $role
    }
}

$script:exportResults += [PSCustomObject]@{
    ResourceName         = 'AADCustomRoleAssignmentSchedule'
    ResourceInstanceName = 'CIS-5.3.1'
    Id                   = 'Permanent members of Administrative Roles'
    Members              = $results
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
