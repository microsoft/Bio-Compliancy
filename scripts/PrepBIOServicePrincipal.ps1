#Requires -RunAsAdministrator

<#
.SYNOPSIS
    This script creates and configures a Service Principal in Azure Active Directory/Entra ID.

.DESCRIPTION
    This script creates and configures a Service Principal in Azure Active Directory/Entra ID. It uses the file
    'M365ReportBIO.JSON' to determine which permissions are required and makes sure the service principal is added
    to the correct role groups.

    Depending on the license it is either using Privileged Identity Management (PIM, when AAD Premium P2 license
    is present) or directly assigns the service principal to the required roles.

.PARAMETER Credential
    Credential required to connect to the Microsoft Graph to create the service principal

.PARAMETER ServicePrincipalName
    Optional parameter that specifies the name of the service principal. When not specified, 'BIOAssessment' will be used

.PARAMETER CertificatePath
    Optional parameter that specifies the path to the Certificate. When this parameter is omitted, it
    will be generated on the script path and the ServicePrincipalName.

.EXAMPLE
    .\PrepBIOServicePrincipal.ps1 -Credential (Get-Credential)

.NOTES
    More information about running this assessment can be found at:
    https://github.com/microsoft/Bio-Compliancy/blob/main/README.md

    For more information about "Baseline Informatiebeveiliging Overheid" (BIO), see:
    https://www.digitaleoverheid.nl/overzicht-van-alle-onderwerpen/cybersecurity/kaders-voor-cybersecurity/baseline-informatiebeveiliging-overheid/
#>
[CmdletBinding()]
param
(
    [Parameter(Mandatory = $true)]
    [PSCredential]
    $Credential,

    [Parameter()]
    [System.String]
    $ServicePrincipalName = 'BIOAssessment',

    [Parameter()]
    [System.String]
    $CertificatePath
)

begin
{
    $currProgressPreference = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'

    $workingDirectory = $PSScriptRoot
    Set-Location -Path $workingDirectory

    $logPath = Join-Path -Path $workingDirectory -ChildPath "Logs"
    if ((Test-Path -Path $logPath) -eq $false)
    {
        $null = New-Item -Name "Logs" -ItemType Directory
    }

    $timestamp = Get-Date -F "yyyyMMdd_HHmmss"
    $scriptName = $MyInvocation.MyCommand.Name
    $scriptName = ($scriptName -split "\.")[0]
    $transcriptLogName = "{0}-{1}.log" -f $scriptName, $timestamp
    $transcriptLogFullName = Join-Path -Path $logPath -ChildPath $transcriptLogName
    Start-Transcript -Path $transcriptLogFullName

    try
    {
        Import-Module -Name (Join-Path -Path $workingDirectory -ChildPath 'SupportFunctions.psm1') -ErrorAction Stop
    }
    catch
    {
        Write-Host "ERROR: Could not load library 'SupportFunctions.psm1'. $($_.Exception.Message.Trim('.')). Exiting." -ForegroundColor Red
        $ProgressPreference = $origProgressPreference
        exit -1
    }

    $bioSettingsFileName = 'M365ReportBIO.JSON'
    $fullBIOPath = Join-Path -Path $workingDirectory -ChildPath $bioSettingsFileName

    Write-LogEntry -Message "Starting Service Principal Creation script"
    Show-CurrentVersion
}

process
{
    if ($PSBoundParameters.ContainsKey('CertificatePath') -eq $true)
    {
        if ((Test-Path -Path $CertificatePath) -eq $false)
        {
            Write-LogEntry -Message "Cannot find file '$CertificatePath' specified in the parameter CertificatePath. Please make sure the file exists!" -Type Error
            return
        }

        try
        {
            $certObj = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
            $certObj.Import($CertificatePath)
        }
        catch
        {
            Write-LogEntry -Message "Error reading '$CertificatePath'. Please make sure the file is a valid CER file!" -Type Error
            return
        }
    }

    Connect-MgGraph -Scopes 'Application.ReadWrite.All','Organization.Read.All','Directory.Read.All','RoleManagement.ReadWrite.Directory' -NoWelcome

    Write-LogEntry -Message "Checking for presence of AAD / Entra ID Premium P2 license"
    $aadPremiumP2Found = $false
    $skus = Get-MgBetaSubscribedSku
    foreach ($sku in $skus)
    {
        if ($sku.ServicePlans.ServicePlanName -contains "AAD_PREMIUM_P2")
        {
            $aadPremiumP2Found = $true
            break
        }
    }

    $tenantid = (Get-MgContext).TenantId

    if ((Test-Path -Path $fullBIOPath) -eq $false)
    {
        Write-LogEntry -Message "Cannot find file '$fullBIOPath'. Please make sure that file exists!" -Type Error
        return
    }

    $bioJson = Get-Content -Raw -Path $fullBIOPath | ConvertFrom-Json
    $Components = $bioJson.resourceName | Sort-Object | Get-Unique

    Write-LogEntry -Message 'Filtering custom components'
    $Components = $Components | Where-Object -FilterScript { $_ -notlike '*Custom*' }

    Write-LogEntry -Message 'Retrieving required permissions'
    $permissionsList = Get-M365DSCCompiledPermissionList -ResourceNameList $Components -PermissionType 'Application' -AccessType 'Read'
    $permissions = $permissionsList.Permissions

    Write-LogEntry -Message 'Checking additionally required SharePoint permissions'
    $spPerms = @("Sites.FullControl.All","AllSites.FullControl","User.ReadWrite.All")
    foreach ($spPerm in $spPerms)
    {
        if ($null -eq ($permissions | Where-Object { $_.API -eq 'SharePoint' -and $_.PermissionName -eq $spPerm}))
        {
            $permissions += @{
                API = 'SharePoint'
                PermissionName = $spPerm
            }
        }
    }

    Write-LogEntry -Message 'Checking additionally required Graph permissions'
    $graphPerms = @("Group.ReadWrite.All","User.ReadWrite.All","AuditLog.Read.All")
    foreach ($graphPerm in $graphPerms)
    {
        if ($null -eq ($permissions | Where-Object { $_.API -eq 'Graph' -and $_.PermissionName -eq $graphPerm}))
        {
            $permissions += @{
                API = 'Graph'
                PermissionName = $graphPerm
            }
        }
    }

    Write-LogEntry -Message "All required permissions: $($permissions.PermissionName -join " / " )" -Type Verbose

    $azureADApp = Get-MgApplication -Filter "DisplayName eq '$($ServicePrincipalName)'"

    $perms = @{}
    $perms.Permissions = $permissions

    $params = @{
        ApplicationName = $ServicePrincipalName
        Permissions     = $perms
        AdminConsent    = $true
        Credential      = $Credential
        Type            = 'Certificate'
        CertificatePath = $CertificatePath
    }

    if ($null -eq $azureADApp)
    {
        Write-LogEntry -Message "Service Principal '$ServicePrincipalName' does NOT exist. Creating service principal."
        if ($PSBoundParameters.ContainsKey('CertificatePath') -eq $false)
        {
            $params.CreateSelfSignedCertificate = $true
            $certPath = Join-Path -Path $workingDirectory -ChildPath ('{0}.cer' -f $ServicePrincipalName)
            if ((Test-Path -Path $certPath) -eq $true)
            {
                Write-LogEntry -Message "Generated CertificatePath '$certPath' already exists. Please delete the file or specify a custom CertificatePath." -Type Error
                return
            }
            $params.CertificatePath = $certPath
        }
    }
    else
    {
        Write-LogEntry -Message "Service Principal '$ServicePrincipalName' exists. Updating service principal."
        if ($PSBoundParameters.ContainsKey('CertificatePath') -eq $false)
        {
            $certPath = Join-Path -Path $workingDirectory -ChildPath ('{0}.cer' -f $ServicePrincipalName)
            if ((Test-Path -Path $certPath) -eq $false)
            {
                Write-LogEntry -Message "Generated CertificatePath '$certPath' does NOT exists. Please make sure the file exists or specify a custom CertificatePath." -Type Error
                return
            }
            $params.CertificatePath = $certPath
        }
        else
        {
            if ((Test-Path -Path $CertificatePath) -eq $false)
            {
                Write-LogEntry -Message "Specified CertificatePath '$CertificatePath' does NOT exists. Please make sure the file exists." -Type Error
                return
            }
        }
    }

    Update-M365DSCAzureAdApplication @params

    # Refresh app details
    $found = $false
    Write-LogEntry -Message "Retrieving app details"
    do
    {
        $app = Get-MgServicePrincipal -Filter "DisplayName eq '$($ServicePrincipalName)'"

        if ($null -eq $app)
        {
            Write-LogEntry -Message "App not yet found, waiting for 5 seconds"
            Start-Sleep -Seconds 5
        }
        else
        {
            $found = $true
        }
    } until ($found -eq $true)

    Write-LogEntry -Message "Updating 'Allow Public Client Flows' setting (IsFallbackPublicClient)"
    $azureADApp = Get-MgApplication -Filter "DisplayName eq '$($ServicePrincipalName)'"
    Update-MgApplication -ApplicationId $azureADApp.Id -IsFallbackPublicClient

    $applicationId = $app.AppId

    if ($PSBoundParameters.ContainsKey('CertificatePath') -eq $true)
    {
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
        $cert.Import($CertificatePath)
    }
    else
    {
        $today = (Get-Date).Date
        $cert = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Subject -eq "CN=$ServicePrincipalName" -and $_.NotBefore.Date -eq $today }
        if ($null -eq $cert)
        {
            $cert = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Subject -eq "CN=$ServicePrincipalName" -and $_.NotBefore.Date -le $today }
            if ($cert.Count -gt 1)
            {
                Write-LogEntry -Message "Multiple certificates found for Service Principal '$ServicePrincipalName'. Please specify a custom CertificatePath." -Type Error
                return
            }
        }
    }

    $certThumbprint = $cert.Thumbprint

    $domain = (Get-MgBetaOrganization).VerifiedDomains | Where-Object { $_.IsInitial -eq $true }
    $domainName = $domain.Name

    Write-LogEntry -Message ' '
    Write-LogEntry -Message 'Details of Service Principal:'
    Write-LogEntry -Message "ApplicationId        : $applicationId"
    Write-LogEntry -Message "TenantId             : $tenantid"
    Write-LogEntry -Message "TenantName           : $domainName"
    Write-LogEntry -Message "CertificateThumbprint: $certThumbprint"
    Write-LogEntry -Message 'NOTE: Make sure you copy these details for the next steps!'
    Write-LogEntry -Message ' '
    Write-LogEntry -Message 'Run the following command to execute the BIO Data Export:'
    Write-LogEntry -Message ".\RunBIOExport.ps1 -ApplicationId $applicationId -TenantId $domainName -CertificateThumbprint $certThumbprint"

    if ($aadPremiumP2Found -eq $true)
    {
        Write-LogEntry -Message "AAD Premium P2 detected, using PIM to assign service principal to role"
    }
    else
    {
        Write-LogEntry -Message "AAD Premium P2 NOT detected, using direct assignments of service principal to role"
    }

    $roles = @('Exchange Administrator','Compliance Administrator')

    foreach ($role in $roles)
    {
        $roleId = Get-MgBetaDirectoryRoleTemplate | Where-Object {$_.displayName -eq $role} | Select-Object -ExpandProperty Id

        $roleDefinition = Get-MgBetaRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $roleId
        $roleAssignments = Get-MgBetaRoleManagementDirectoryRoleAssignment -Filter "roleDefinitionId eq '$($roleDefinition.Id)' and principalId eq '$($app.Id)'"
        if ($null -ne $roleAssignments)
        {
            Write-LogEntry -Message "Service principal is already assigned to role $role."
        }
        else
        {
            Write-LogEntry -Message "Service principal is NOT assigned to role $role. Adding to role."
            $null = New-MgBetaRoleManagementDirectoryRoleAssignment -PrincipalId $app.Id -RoleDefinitionId $roleDefinition.Id -DirectoryScopeId "/"
        }
    }
}

end
{
    $ProgressPreference = $currProgressPreference

    Write-LogEntry -Message "Completed Service Principal Creation script"
    Stop-Transcript
}
