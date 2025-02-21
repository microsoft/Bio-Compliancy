#Requires -RunAsAdministrator

<#
.SYNOPSIS
    This script installs all required components, so the environment is ready for the follow-up scripts.

.DESCRIPTION
    This script installs all required components, so the environment is ready for the follow-up scripts.
    The script is using Mirosoft365DSC and will install the latest version. When Microsoft365DSC is already present,
    it will ask the user to upgrade to the most recent version. If the script is running in an unattended session,
    it will use installed version.

.EXAMPLE
    .\PrepEnvironment.ps1

.NOTES
    More information about running this assessment can be found at:
    https://github.com/microsoft/Bio-Compliancy/blob/main/README.md

    For more information about "Baseline Informatiebeveiliging Overheid" (BIO), see:
    https://www.digitaleoverheid.nl/overzicht-van-alle-onderwerpen/cybersecurity/kaders-voor-cybersecurity/baseline-informatiebeveiliging-overheid/

    For more information about "Microsoft365DSC" (M365DSC), see:
    https://microsoft365dsc.com
#>
[CmdletBinding()]
param
()

begin
{
    $origProgressPreference = $ProgressPreference
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

    $minimumM365DSCVersion = [System.Version]'1.24.1030.1'

    Write-LogEntry -Message "Starting Preparation script"
    Show-CurrentVersion
}

process
{
    Write-LogEntry -Message "Checking presence of Microsoft365DSC"
    $m365dscModule = Get-Module Microsoft365DSC -ListAvailable
    if ($null -eq $m365dscModule)
    {
        Write-LogEntry -Message "Installing Microsoft365DSC"
        Install-Module Microsoft365DSC
    }
    else
    {
        Write-LogEntry -Message "Microsoft365DSC already installed: $($m365dscModule.Version)"

        $newestModule = Find-Module Microsoft365DSC
        if ($m365dscModule.Version -ge $minimumM365DSCVersion)
        {
            if ($newestModule.Version -gt $m365dscModule.Version)
            {
                if ((Assert-IsNonInteractiveShell) -eq $false)
                {
                    $top = new-Object System.Windows.Forms.Form -property @{Topmost=$true}
                    $result = [System.Windows.Forms.MessageBox]::Show($top,"Do you want to upgrade to the most recent version of Microsoft365DSC ($($newestModule.Version))","Do you want to upgrade?",'YesNo','Question')
                    if ($result -eq 'Yes')
                    {
                        Write-LogEntry -Message "Upgrading Microsoft365DSC to v$($newestModule.Version)"
                        Remove-Item -Path (Split-Path -Path $m365dscModule.Path -Parent) -Recurse -Force
                        Install-Module Microsoft365DSC
                    }
                    else
                    {
                        Write-LogEntry -Message "Keep using current version of Microsoft365DSC."
                    }
                }
            }
        }
        else
        {
            Write-LogEntry -Message "Upgrade of Microsoft365DSC required: Installing v$($newestModule.Version)"
            Write-LogEntry -Message "  Minimum version: v$($minimumM365DSCVersion)"
            Write-LogEntry -Message "  Installed version: v$($m365dscModule.Version)"
            Write-LogEntry -Message "Installing v$($newestModule.Version)"
            Remove-Item -Path (Split-Path -Path $m365dscModule.Path -Parent) -Recurse -Force
            Install-Module Microsoft365DSC
        }
    }

    $m365dscModule = Get-Module Microsoft365DSC -ListAvailable
    if ($null -eq $m365dscModule)
    {
        Write-LogEntry -Message "Microsoft365DSC not installed successfully. Exiting!" -Type Error
        return
    }

    Write-LogEntry -Message "Updating Microsoft365DSC dependencies"
    Update-M365DSCDependencies

    Write-LogEntry -Message "Removing duplicate versions of the dependencies (to prevent conflicts)"
    Uninstall-M365DSCOutdatedDependencies

    $result = Test-WSMan -ErrorAction SilentlyContinue
    if ($null -ne $result)
    {
        Write-LogEntry -Message 'Windows Remoting is configured correctly. Continuing.'

    }
    else
    {
        Write-LogEntry -Message 'Windows Remoting is NOT configured correctly. Configuring now!'
        Enable-PSRemoting -SkipNetworkProfileCheck -Force
        Write-LogEntry -Message 'Windows Remoting has been configured!'
    }
}

end
{
    $ProgressPreference = $origProgressPreference

    Write-LogEntry -Message "Completed Preparation script"
    Stop-Transcript
}
