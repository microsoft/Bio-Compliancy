Write-LogEntry -Message "Executing $($MyInvocation.MyCommand.Name)"

function Get-AllUsersWithLicenseType
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet("E3","E5")]
        [System.String]
        $Type
    )

    process
    {
        $users = Get-MgUser -All -Property AssignedLicenses, UserPrincipalName | Select-Object -Property UserPrincipalName,AssignedLicenses
        if ($null -eq $users)
        {
            Write-Verbose "No users found!"
            return $null
        }

        $skus = Get-MgBetaSubscribedSku -All
        $typeSKUs = $skus | Where-Object { $_.SkuPartNumber -like "*$type*" }

        if ($null -eq $typeSKUs)
        {
            Write-Verbose "No license SKU found!"
            return $null
        }

        Write-Verbose "Found these $type licenses:"
        foreach ($sku in $typeSKUs)
        {
            Write-Verbose "- $($sku.SkuPartNumber) ($($sku.SkuId))"
        }

        return ($users | Where-Object { $_.AssignedLicenses.SkuId -eq $typeSKUs.SkuId })
    }
}

function Get-AllMailboxesWithLicenseType
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet("E3","E5")]
        [System.String]
        $Type
    )

    process
    {
        $usersWithLicense = Get-AllUsersWithLicenseType -Type $Type

        if ($null -ne $usersWithLicense)
        {
            $mailboxes = Get-EXOMailbox -PropertySets Audit, Minimum -ResultSize Unlimited -Verbose:$false | Where-Object { $_.RecipientTypeDetails -eq "UserMailbox" }

            $includedMailboxes = foreach ($mailbox in $mailboxes)
            {
                if ($mailbox.UserPrincipalName -in $usersWithLicense.UserPrincipalName)
                {
                    $mailbox
                }
            }

            return $includedMailboxes
        }
        else
        {
            Write-Verbose -Message "No users found with $Type license"
            return $null
        }
    }
}

function Confirm-Actions
{
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet("E3","E5")]
        [System.String]
        $Type,

        [Parameter()]
        [System.Object]
        $CurrentUser
    )

    $AdminActions = @{
        E3 = @("ApplyRecord", "Copy", "Create", "FolderBind", "HardDelete", "Move", "MoveToDeletedItems", "SendAs", "SendOnBehalf", "SoftDelete", "Update", "UpdateCalendarDelegation", "UpdateFolderPermissions", "UpdateInboxRules")
        E5 = @("ApplyRecord", "Copy", "Create", "FolderBind", "HardDelete", "MailItemsAccessed", "Move", "MoveToDeletedItems", "SendAs", "SendOnBehalf", "Send", "SoftDelete", "Update", "UpdateCalendarDelegation", "UpdateFolderPermissions", "UpdateInboxRules")
    }

    $DelegateActions = @{
        E3 = @("ApplyRecord", "Create", "FolderBind", "HardDelete", "Move", "MoveToDeletedItems", "SendAs", "SendOnBehalf", "SoftDelete", "Update", "UpdateFolderPermissions", "UpdateInboxRules")
        E5 = @("ApplyRecord", "Create", "FolderBind", "HardDelete", "Move", "MailItemsAccessed", "MoveToDeletedItems", "SendAs", "SendOnBehalf", "SoftDelete", "Update", "UpdateFolderPermissions", "UpdateInboxRules")
    }

    $OwnerActions = @{
        E3 = @("ApplyRecord", "Create", "HardDelete", "MailboxLogin", "Move", "MoveToDeletedItems", "SoftDelete", "Update", "UpdateCalendarDelegation", "UpdateFolderPermissions", "UpdateInboxRules")
        E5 = @("ApplyRecord", "Create", "HardDelete", "MailboxLogin", "Move", "MailItemsAccessed", "MoveToDeletedItems", "Send", "SoftDelete", "Update", "UpdateCalendarDelegation", "UpdateFolderPermissions", "UpdateInboxRules")
    }

    $missingActions = @()
    $actions = "AuditAdmin", "AuditDelegate", "AuditOwner"

    foreach ($action in $actions)
    {
        switch ($action)
        {
            "AuditAdmin" {
                $desiredActions = $AdminActions.$Type
            }
            "AuditDelegate" {
                $desiredActions = $DelegateActions.$Type
            }
            "AuditOwner" {
                $desiredActions = $OwnerActions.$Type
            }
        }

        foreach ($desiredAction in $desiredActions)
        {
            if ($CurrentUser.$action -notcontains $desiredAction)
            {
                $missingActions += "[$($CurrentUser.UserPrincipalName)] $action \ $desiredAction"
            }
        }
    }

    return $missingActions
}

$type = "E5"
$users = Get-AllMailboxesWithLicenseType -Type $type
$missingActions = @()
foreach ($user in $users)
{
    $missingActions += Confirm-Actions -Type $type -CurrentUser $user
}

$script:exportResults += [PSCustomObject]@{
    ResourceName         = 'EXOCustomAuditingEnabledForE5'
    ResourceInstanceName = 'CIS-6.1.3'
    Id                   = 'Ensure mailbox auditing for E5 users is Enabled'
    MissingActions       = $missingActions
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
