<#
.SYNOPSIS
    This script runs an export of all settings that will be compared and converts the export into JSON format.

.DESCRIPTION
    This script runs an export of all settings that will be compared and converts the export into JSON format.
    The script is using Mirosoft365DSC.

    All exports are created in a folder called 'Output\yyyyMMdd' in the current directory. When that folder
    already exists, it will be emptied and repopulated.

.PARAMETER Credential
    Credential required to connect to the Microsoft Graph to create the service principal

.PARAMETER ApplicationId
    The GUID of the Service Principal which should be used for authentication

.PARAMETER TenantId
    The name of the tenant in which the Service Principal has been created, for example 'tenant.onmicrosoft.com'

.PARAMETER CertificateThumbprint
    Thumbprint of the certificate to be used for authentication. This certificate needs to exist in the local certificate store of the computer.

.PARAMETER ExportFileName
    Specifies the file name of the export file.

.PARAMETER BIOTemplateFileName
    The BIO template which will be used to determine which components need to get exported.

.EXAMPLE
    Run the export using Service Principals
    .\RunBIOExport.ps1 -ApplicationId 2618bced-38c7-4366-be7c-c5ab4d695fee -TenantId bb14feb2-c123-4587-a213-be90ad56869c -CertificateThumbprint 188B0BE5D3FEFC254C5EE1BA6F99780AC33198DC

.EXAMPLE
    Run the export using Credentials
    .\RunBIOExport.ps1 -Credential (Get-Credential)

.NOTES
    For more information about "Baseline Informatiebeveiliging Overheid" (BIO), see:
    https://www.digitaleoverheid.nl/overzicht-van-alle-onderwerpen/cybersecurity/kaders-voor-cybersecurity/baseline-informatiebeveiliging-overheid/

    For more information about "Microsoft365DSC" (M365DSC), see:
    https://microsoft365dsc.com
#>
[CmdletBinding(DefaultParameterSetName = 'Credential')]
param
(
    [Parameter(Mandatory = $true, ParameterSetName = 'Credential')]
    [PSCredential]
    $Credential,

    [Parameter(Mandatory = $true, ParameterSetName = 'ServicePrincipal')]
    [System.String]
    $ApplicationId,

    [Parameter(Mandatory = $true, ParameterSetName = 'ServicePrincipal')]
    [System.String]
    $TenantId,

    [Parameter(Mandatory = $true, ParameterSetName = 'ServicePrincipal')]
    [System.String]
    $CertificateThumbprint,

    [Parameter()]
    [System.String]
    $ExportFileName = 'M365Report.JSON',

    [Parameter()]
    [System.String]
    $BIOTemplateFileName = 'M365ReportBIO.JSON'
)

begin
{
    $origProgressPreference = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'

    $workingDirectory = $PSScriptRoot
    try
    {
        Import-Module -Name (Join-Path -Path $workingDirectory -ChildPath 'SupportFunctions.psm1') -ErrorAction Stop
    }
    catch
    {
        Write-Host "ERROR: Could not load library 'SupportFunctions.psm1'. $($_.Exception.Message.Trim('.')). Exiting." -ForegroundColor Red
        exit -1
    }

    Write-LogEntry -Object "Starting BIO Export script"
    Set-Location -Path $workingDirectory
}

process
{
    switch ($PSCmdlet.ParameterSetName)
    {
        'Credential' {
            Write-LogEntry -Object 'Script will use Credential for authentication'
            Write-LogEntry -Object "- UserName: $($Credential.UserName)"
            Write-LogEntry -Object ' '
            Write-LogEntry -Object 'NOTE: When using MFA, it is possible that you are prompted for credentials and MFA approval several times again.' -Warning
            Write-LogEntry -Object ' '
        }
        'ServicePrincipal' {
            Write-LogEntry -Object 'Script will use Service Principal for authentication'
            Write-LogEntry -Object "- ApplicationId        : $($ApplicationId)"
            Write-LogEntry -Object "- TenantId             : $($TenantId)"
            Write-LogEntry -Object "- CertificateThumbprint: $($CertificateThumbprint)"
            Write-LogEntry -Object ' '
        }
    }

    $timestamp = Get-Date -f 'yyyyMMdd'
    $outputPath = Join-Path -Path $workingDirectory -ChildPath "Output\$timestamp"
    if ((Test-Path -Path $outputPath) -eq $false)
    {
        $null = New-Item -Name "Output\$timestamp" -ItemType Directory
    }
    else
    {
        Write-LogEntry -Object "Output folder '$outputPath' already exists. Recreating folder."
        Remove-Item -Path $outputPath -Force -Recurse
        $null = New-Item -Name "Output\$timestamp" -ItemType Directory
    }

    $fullBIOPath = Join-Path -Path $workingDirectory -ChildPath $BIOTemplateFileName
    if (Test-Path -Path $fullBIOPath)
    {
        $bioJson = Get-Content -Raw -Path $fullBIOPath | ConvertFrom-Json
        $Components = $bioJson.resourceName | Sort-Object | Get-Unique
    }
    else
    {
        Write-LogEntry -Object "Cannot find BIO Baseline file '$fullBIOPath'. Exiting script." -Failure
        return
    }

    Write-LogEntry -Object "Granting permissions to Graph and PnP apps"

    Write-LogEntry -Object "Register Graph Access"
    if ($PSCmdlet.ParameterSetName -eq 'Credential')
    {
        Update-M365DSCAllowedGraphScopes -ResourceNameList $Components -Type Read

        # Temporary because of issue in v1.24.313.1
        Connect-MgGraph -Scopes Application.ReadWrite.All -NoWelcome

        try
        {
            $null = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/servicePrincipals(appId=%2731359c7f-bd7e-475c-86db-fdb8c937548e%27)" -Method Get
            Write-LogEntry -Object "PnP SP Management Shell Access already registered!"
        }
        catch
        {
            Write-LogEntry -Object "Registering PnP SP Management Shell Access"
            Register-PnPManagementShellAccess
        }
    }

    Write-LogEntry -Object "Exporting settings"
    $params = @{
        Components = $Components
        Path       = $outputPath
    }

    switch ($PSCmdlet.ParameterSetName)
    {
        'Credential' {
            $params.Credential = $Credential
        }
        'ServicePrincipal' {
            $params.ApplicationId = $ApplicationId
            $params.TenantId = $TenantId
            $params.CertificateThumbprint = $CertificateThumbprint
        }
    }

    Export-M365DSCConfiguration @params

    Write-LogEntry -Object "Convert export into JSON format"
    $fullReportPath = Join-Path -Path $outputPath -ChildPath $ExportFileName
    $exportFilePath = Join-Path -Path $outputPath -ChildPath 'M365TenantConfig.ps1'
    if (Test-Path -Path $fullReportPath)
    {
        Write-LogEntry -Object "File '$fullReportPath' already exists. Removing file."
        Remove-Item -Path $fullReportPath -Confirm:$false
    }
    New-M365DSCReportFromConfiguration -Type 'JSON' -ConfigurationPath $exportFilePath -OutputPath $fullReportPath
    Write-LogEntry -Object "Created export file $fullReportPath"
}

end
{
    $ProgressPreference = $origProgressPreference

    Write-LogEntry -Object "Completed BIO Export script"
}
