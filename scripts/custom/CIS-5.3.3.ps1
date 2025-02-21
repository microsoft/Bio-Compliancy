Write-LogEntry -Message "Executing $($MyInvocation.MyCommand.Name)"

$null = New-M365DSCConnection -Workload 'MicrosoftGraph' `
    -InboundParameters @{
        ApplicationId         = $ApplicationId
        TenantId              = $TenantId
        CertificateThumbprint = $CertificateThumbprint
    }

$reviews = Get-MgBetaIdentityGovernanceAccessReviewDefinition -All

$minimumAdminRoles = @('Global Administrator', 'Exchange Administrator', 'SharePoint Administrator', 'Teams Administrator', 'Security Administrator')

$allRequiredGroups = @{}

foreach ($minimumAdminRole in $minimumAdminRoles)
{
    $allRequiredGroups.$minimumAdminRole = $false
}

$incorrectReviewSettings = @()

foreach ($review in $reviews)
{
    if ($review.Scope.AdditionalProperties.'@odata.type' -eq '#microsoft.graph.principalResourceMembershipsScope')
    {
        $id = Split-Path $review.Scope.AdditionalProperties.resourceScopes.query -Leaf
        $role = Get-MgBetaRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $id

        $roleName = $role.DisplayName
        #Write-LogEntry -Message "  Processing Administrative Role: '$roleName'"

        if ($review.Status -ne 'InProgress')
        {
            $incorrectReviewSettings += "$roleName = Review is not Active"
        }

        # Scope = Everyone
        if ($null -eq ($review.Scope.AdditionalProperties.principalScopes | Where-Object { $_.query -eq '/v1.0/users' }) -or `
                $null -eq ($review.Scope.AdditionalProperties.principalScopes | Where-Object { $_.query -eq '/v1.0/groups' }))
        {
            $incorrectReviewSettings += "$roleName = Review is not scoped to Everyone"
        }

        if ($review.Settings.MailNotificationsEnabled -ne $true)
        {
            $incorrectReviewSettings += "$roleName = Mail Notifications are not Enabled"
        }

        if ($review.Settings.ReminderNotificationsEnabled -ne $true)
        {
            $incorrectReviewSettings += "$roleName = Reminder Notifications are not Enabled"
        }

        if ($review.Settings.JustificationRequiredOnApproval -ne $true)
        {
            $incorrectReviewSettings += "$roleName = Require Reason On Approval is not Enabled"
        }

        if ($review.Settings.InstanceDurationInDays -gt 4)
        {
            $incorrectReviewSettings += "$roleName = Duration In Days is larger than 4"
        }

        if ($review.Settings.AutoApplyDecisionsEnabled -ne $true)
        {
            $incorrectReviewSettings += "$roleName = Auto Apply Results To Resource is not Enabled"
        }

        if ($review.Settings.DefaultDecision -ne 'None')
        {
            $incorrectReviewSettings += "$roleName = If Reviewers Don't Respond is not set to No change"
        }

        if ($review.Settings.Recurrence.Pattern.Type -notin @('weekly', 'monthly'))
        {
            $incorrectReviewSettings += "$roleName = Recurrence is not Weekly or Monthly"
        }

        if ($roleName -in $minimumAdminRoles)
        {
            $allRequiredGroups.$roleName = $true
        }
    }
}

$incorrectReviewSettings += $allRequiredGroups.GetEnumerator() | Where-Object { $_.Value -eq $false } | ForEach-Object { "$($_.Key) = No review created for this Role" }

$script:exportResults += [PSCustomObject]@{
    ResourceName            = 'AADCustomPIMAccessReviews'
    ResourceInstanceName    = 'CIS-5.3.3'
    Id                      = 'Access reviews for high privileged Entra ID roles are configured'
    IncorrectReviewSettings = $incorrectReviewSettings
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
