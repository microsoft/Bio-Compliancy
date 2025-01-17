Write-LogEntry -Message "Executing $($MyInvocation.MyCommand.Name)"

$null = New-M365DSCConnection -Workload 'MicrosoftGraph' `
    -InboundParameters @{
    ApplicationId         = $ApplicationId
    TenantId              = $TenantName
    CertificateThumbprint = $CertificateThumbprint
}

$gaRole = Get-MgBetaRoleManagementDirectoryRoleDefinition | Where-Object { $_.DisplayName -in 'Global Administrator' }
$Filter = "scopeId eq '/' and scopeType eq 'DirectoryRole' and RoleDefinitionId eq '$($gaRole.Id)'"
$Policy = Get-MgBetaPolicyRoleManagementPolicyAssignment -Filter $Filter
#get Policyrule
$roles = Get-MgBetaPolicyRoleManagementPolicyRule -UnifiedRoleManagementPolicyId $Policy.Policyid
$isApprovalRequired = $false
$activateApproversUPN = @()
foreach ($role in $roles)
{
    if ($role.Id -match 'Approval_EndUser_Assignment')
    {
        $isApprovalRequired = $role.AdditionalProperties.setting.isApprovalRequired

        [array]$ActivateApprovers = $role.AdditionalProperties.setting.approvalStages.primaryApprovers
        foreach ($Item in $ActivateApprovers.id)
        {
            $user = Get-MgUser -UserId $Item
            $activateApproversUPN += $user.UserPrincipalName
        }
    }
}

$script:exportResults += [PSCustomObject]@{
    ResourceName         = 'AADCustomApprovalRequiredForGAActivation'
    ResourceInstanceName = 'CIS-5.3.4'
    Id                   = 'Ensure approval is required for Global Administrator role activation'
    IsApprovalRequired   = $isApprovalRequired
    TwoOrMoreApprovers   = ($activateApproversUPN.Count -gt 2)
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
