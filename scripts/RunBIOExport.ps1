#Requires -RunAsAdministrator

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
    .\RunBIOExport.ps1 -ApplicationId 2618bced-38c7-4366-be7c-c5ab4d695fee -TenantId mytenant.onmicrosoft.com -CertificateThumbprint 188B0BE5D3FEFC254C5EE1BA6F99780AC33198DC

.EXAMPLE
    Run the export using Credentials
    .\RunBIOExport.ps1 -Credential (Get-Credential)

.NOTES
    More information about running this assessment can be found at:
    https://github.com/microsoft/Bio-Compliancy/blob/main/README.md

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

    # Set variable to supress PnP PowerShell update messages
    $env:PNPPOWERSHELL_UPDATECHECK="false"

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

    Write-LogEntry -Message "Starting BIO Export script"
    Show-CurrentVersion
    Set-Location -Path $workingDirectory
}

process
{
    switch ($PSCmdlet.ParameterSetName)
    {
        'Credential' {
            Write-LogEntry -Message 'Script will use Credential for authentication'
            Write-LogEntry -Message "- UserName: $($Credential.UserName)"
            Write-LogEntry -Message ' '
            Write-LogEntry -Message 'NOTE: When using MFA, it is possible that you are prompted for credentials and MFA approval several times again.' -Type Warning
            Write-LogEntry -Message ' '
        }
        'ServicePrincipal' {
            Write-LogEntry -Message 'Script will use Service Principal for authentication'
            Write-LogEntry -Message "- ApplicationId        : $($ApplicationId)"
            Write-LogEntry -Message "- TenantId             : $($TenantId)"
            Write-LogEntry -Message "- CertificateThumbprint: $($CertificateThumbprint)"
            Write-LogEntry -Message ' '
        }
    }

    $timestamp = Get-Date -f 'yyyyMMdd'
    $outputPath = Join-Path -Path $workingDirectory -ChildPath "Output\$timestamp"
#<#
    if ((Test-Path -Path $outputPath) -eq $false)
    {
        $null = New-Item -Name "Output\$timestamp" -ItemType Directory
    }
    else
    {
        Write-LogEntry -Message "Output folder '$outputPath' already exists. Recreating folder."
        Remove-Item -Path $outputPath -Force -Recurse
        $null = New-Item -Name "Output\$timestamp" -ItemType Directory
    }
#>
    $customScriptsPath = Join-Path -Path $workingDirectory -ChildPath "custom"
    if ((Test-Path -Path $customScriptsPath) -eq $false)
    {
        Write-LogEntry -Message "Cannot find custom scripts folder '$customScriptsPath'. Make sure this folder exists, including all available scripts!" -Type Error
        Write-LogEntry -Message "Exiting script." -Type Error
        return
    }

#<#
    $fullBIOPath = Join-Path -Path $workingDirectory -ChildPath $BIOTemplateFileName
    if (Test-Path -Path $fullBIOPath)
    {
        $bioJson = Get-Content -Raw -Path $fullBIOPath | ConvertFrom-Json
        $Components = $bioJson.resourceName | Sort-Object | Get-Unique
    }
    else
    {
        Write-LogEntry -Message "Cannot find BIO Baseline file '$fullBIOPath'. Exiting script." -Type Error
        return
    }


    Write-LogEntry -Message "Granting permissions to Graph and PnP apps"

    Write-LogEntry -Message "Register Graph Access"
    if ($PSCmdlet.ParameterSetName -eq 'Credential')
    {
        Update-M365DSCAllowedGraphScopes -ResourceNameList $Components -Type Read

        # Temporary because of issue in v1.24.313.1
        Connect-MgGraph -Scopes Application.ReadWrite.All -NoWelcome

        try
        {
            $null = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/servicePrincipals(appId=%2731359c7f-bd7e-475c-86db-fdb8c937548e%27)" -Method Get
            Write-LogEntry -Message "PnP SP Management Shell Access already registered!"
        }
        catch
        {
            Write-LogEntry -Message "Registering PnP SP Management Shell Access"
            Register-PnPManagementShellAccess
        }
    }

    Write-LogEntry -Message "Exporting settings"
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

    Write-LogEntry -Message "Convert export into JSON format"
    $fullReportPath = Join-Path -Path $outputPath -ChildPath $ExportFileName
    $exportFilePath = Join-Path -Path $outputPath -ChildPath 'M365TenantConfig.ps1'
    if (Test-Path -Path $fullReportPath)
    {
        Write-LogEntry -Message "File '$fullReportPath' already exists. Removing file."
        Remove-Item -Path $fullReportPath -Confirm:$false
    }
    New-M365DSCReportFromConfiguration -Type 'JSON' -ConfigurationPath $exportFilePath -OutputPath $fullReportPath
    if (Test-Path -Path $fullReportPath)
    {
        $item = Get-Item -Path $fullReportPath
        if ($item.Length -lt 50KB)
        {
            Write-LogEntry -Message "Possible error while creating export file '$fullReportPath'" -Type Error
            Write-LogEntry -Message "File is less than 50KB. Current size: $([Math]::Round($item.Length / 1KB,1))KB" -Type Error
            Write-LogEntry -Message "Please check if all prequisites are met!" -Type Error
            return
        }
        else
        {
            Write-LogEntry -Message "Successfully created the export file '$fullReportPath'"
            Write-LogEntry -Message "Current file size: $([Math]::Round($item.Length / 1MB,2))MB"
        }
    }
    else
    {
        Write-LogEntry -Message "Cannot find the JSON version of the export '$fullReportPath'." -Type Error
        Write-LogEntry -Message "Please check if all prequisites are met!" -Type Error
        return
    }
#>

### TEMP
$fullReportPath = Join-Path -Path $outputPath -ChildPath $ExportFileName


    Write-LogEntry -Message "Running additional custom exports"
    $script:exportResults = Get-Content -Path $fullReportPath -Raw | ConvertFrom-Json

    $customScripts = Get-ChildItem -Path $customScriptsPath -Filter '*.ps1'
    Write-LogEntry -Message "  Found $($customScripts.Count) custom scripts in $customScriptsPath"
    foreach ($script in $customScripts)
    {
        . $script.FullName
    }
    $script:exportResults | ConvertTo-Json -Depth 20 | Set-Content -Path $fullReportPath -Encoding utf8BOM
}

end
{
    $ProgressPreference = $origProgressPreference

    Write-LogEntry -Message "Completed BIO Export script"
}
