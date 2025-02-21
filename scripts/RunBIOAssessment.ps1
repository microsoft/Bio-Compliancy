#Requires -RunAsAdministrator

<#
.SYNOPSIS
    This script compares the configuration of a Microsoft 365 tenant with the BIO baseline and reports on the compliance.

.DESCRIPTION
    This script compares the current configuration of a Microsoft 365 tenant with the BIO baseline. It is using a Microsoft365DSC
    export and compares the results with the BIO baseline.

    It generates three files:
        - Results_BIOControls.json: Overview of the BIO controls and what resources match and which don't.
        - Results_BIOControlsOverview.csv: Detailed overview of each measurement, their respective BIO Control and the current score.
        - Results_Comparison.json: Summary of the compliancy of each resource with the BIO baseline and what properties do not match.

.EXAMPLE
    .\RunBIOAssessment.ps1

.NOTES
    More information about running this assessment can be found at:
    https://github.com/microsoft/Bio-Compliancy/blob/main/README.md

    For more information about "Baseline Informatiebeveiliging Overheid" (BIO), see:
    https://www.digitaleoverheid.nl/overzicht-van-alle-onderwerpen/cybersecurity/kaders-voor-cybersecurity/baseline-informatiebeveiliging-overheid/
#>
[CmdletBinding()]
param
(
    [Parameter()]
    [System.String]
    $OutputPath
)

# ----------------- START SCRIPT -----------------
begin
{
    $currWarningPreference = $WarningPreference
    $WarningPreference = 'SilentlyContinue'

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

        $WarningPreference = $currWarningPreference
        $ProgressPreference = $currProgressPreference

        exit -1
    }

    Write-LogEntry -Message 'Starting BIO Comparison script'
    Show-CurrentVersion
}

process
{
    # Create variables to store comparison results
    $comparisonResults = @()
    $bioControlsResults = @{}
    $detailedBIOControlsResults = @()

    $timestamp = Get-Date -f 'yyyyMMdd'
    if ($PSBoundParameters.ContainsKey('OutputPath'))
    {
        $outputFolder = $OutputPath
    }
    else
    {
        $outputFolder = Join-Path -Path $workingDirectory -ChildPath "Output\$timestamp"
    }

    $bioSettingsFileName = 'M365ReportBIO.JSON'
    $bioSettingsFullPath = Join-Path -Path $workingDirectory -ChildPath $bioSettingsFileName

    $currentSettingsFileName = 'M365Report.JSON'
    $currentSettingsFullPath = Join-Path -Path $outputFolder -ChildPath $currentSettingsFileName

    $bioControlsDetailsCSV = 'BIOControlsDetails.csv'

    $resultComparisonFileName = 'Results_Comparison.json'
    $resultComparisonFullPath = Join-Path -Path $outputFolder -ChildPath $resultComparisonFileName

    $resultBIOControlsFileName = 'Results_BIOControls.json'
    $resultBIOControlsFullPath = Join-Path -Path $outputFolder -ChildPath $resultBIOControlsFileName

    $resultRulesCSVFileName = 'Results_BIOControlsOverview.csv'
    $resultRulesCSVFullPath = Join-Path -Path $outputFolder -ChildPath $resultRulesCSVFileName

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

    if ((Test-Path -Path $outputFolder) -eq $false)
    {
        Write-LogEntry -Message "Could not find path '$outputFolder'. Please make sure folder exists." -Type Error
        Write-LogEntry -Message 'Or use the OutputPath parameter to specify a valid path to the created export.' -Type Error
        return
    }

    # By default, the script uses the supplied JSON file. If the -Debug switch is used, the script will try to convert the PS1
    # into a JSON file.
    if ($Debug)
    {
        Write-LogEntry -Message 'Convert M365DSC configuration to JSON'
        if (Test-Path -Path '.\BIOBlueprint.ps1')
        {
            New-M365DSCReportFromConfiguration -Type 'JSON' -ConfigurationPath '.\BIOBlueprint.ps1' -OutputPath $bioSettingsFullPath
        }
        else
        {
            Write-LogEntry -Message "Could not find BIOBlueprint.ps1. Using current $bioSettingsFullPath." -Type Error
        }
    }

    # Read the Source JSON files
    Write-LogEntry -Message "Read and parse BIO Baseline file: $bioSettingsFullPath"
    if (Test-Path -Path $bioSettingsFullPath)
    {
        try
        {
            $bioJson = Get-Content -Raw -Path $bioSettingsFullPath | ConvertFrom-Json -ErrorAction Stop
        }
        catch
        {
            Write-LogEntry -Message "Error while reading '$bioSettingsFullPath'." -Type Error
            Write-LogEntry -Message 'Check if the file is a correct JSON file. Exiting script.' -Type Error
            return
        }
    }
    else
    {
        Write-LogEntry -Message "Cannot find BIO Baseline file '$bioSettingsFullPath'. Exiting script." -Type Error
        return
    }

    Write-LogEntry -Message "Read and parse export configuration: $currentSettingsFullPath"
    if (Test-Path -Path $currentSettingsFullPath)
    {
        $currentJson = Get-Content -Raw -Path $currentSettingsFullPath | ConvertFrom-Json
    }
    else
    {
        Write-LogEntry -Message "Cannot find current settings file '$currentSettingsFullPath'. Exiting script." -Type Error
        return
    }

    Write-LogEntry -Message "Read BIO Controls details: $bioControlsDetailsCSV"
    if (Test-Path -Path ".\$bioControlsDetailsCSV")
    {
        $bioControlsDetails = Import-Csv -Path ".\$bioControlsDetailsCSV" -Delimiter ';' -Encoding UTF8
    }
    else
    {
        Write-LogEntry -Message "Cannot find current settings file '$bioControlsDetailsCSV'. Exiting script." -Type Error
        return
    }

    Write-LogEntry -Message 'Comparing current settings with BIO Baseline'

    $ProgressPreference = 'Continue'
    $totalCount = $bioJson.Count
    $currentCount = 1
    Write-LogEntry -Message "Total objects to be analyzed: $totalCount"

    foreach ($bioObject in $bioJson)
    {
        $percentage = ($currentCount / $totalCount) * 100
        Write-Progress -Activity 'Analyzing export' -Status "Resource $($bioObject.ResourceName) [$currentCount of $totalCount]" -PercentComplete $percentage

        $bioResourceName = $bioObject.ResourceName
        $currentObjects = $currentJson | Where-Object { $_.ResourceName -eq $bioResourceName }

        if ($currentObjects)
        {
            Write-LogEntry -Message "Processing resource $($bioResourceName)" -Type Verbose
            foreach ($currentObject in $currentObjects)
            {
                $propertyDifferences = @()
                $propertiesMatch = $true

                foreach ($property in $bioObject.PSObject.Properties)
                {
                    $propertyName = $property.Name
                    if ($propertyName -notin 'ResourceName', 'ResourceInstanceName', 'DisplayName', 'Id', 'Identity', 'BIOControls')
                    {
                        $bioValue = $property.Value
                        $currentValue = $currentObject.$propertyName

                        $testResult = Test-Value -Reference $bioValue -Difference $currentValue
                        Write-LogEntry -Message "Testing $($propertyName): BIO [$($bioValue -join ', ')], Current[$($currentValue -join ', ')], Result[$testResult]" -Type Verbose
                        if ($testResult -eq $false)
                        {
                            $propertiesMatch = $false

                            [String]$consolidatedBioValue = $bioValue
                            if ($bioValue -is [Array])
                            {
                                $consolidatedBioValue = ($bioValue | Sort-Object) -join ', '
                            }

                            [String]$consolidatedCurrentValue = $currentValue
                            if ($currentValue -is [Array])
                            {
                                $consolidatedCurrentValue = ($currentValue | Sort-Object) -join ', '
                            }

                            $propertyDifferences += [PSCustomObject]@{
                                PropertyName = $propertyName
                                BIO          = $consolidatedBioValue
                                Current      = $consolidatedCurrentValue
                            }
                        }
                    }
                }

                $comparisonResults += [PSCustomObject]@{
                    ReferenceResourceName         = $bioObject.ResourceName
                    ReferenceResourceInstanceName = $bioObject.ResourceInstanceName
                    TargetResourceName            = $currentObject.ResourceName
                    TargetResourceInstanceName    = $currentObject.ResourceInstanceName
                    PropertiesMatch               = $propertiesMatch
                    PropertyDifferences           = $propertyDifferences
                }

                $measureCount = 1
                if ($propertiesMatch -eq $false)
                {
                    $measureCount = 0
                }

                if ($bioObject.BIOControls)
                {
                    $sourceBIOControls = $bioObject.BIOControls
                    foreach ($control in $sourceBIOControls)
                    {
                        $bioControlsResult = $bioControlsResults[$control]

                        if ($null -eq $bioControlsResult)
                        {
                            $bioControlsResult = [PSCustomObject]@{
                                BIOControls   = $control
                                MeasuresCount = 0
                                CoveredBy     = @()
                                Matched       = 0
                                Unmatched     = 0
                                TotalMissing  = 0
                                Matches       = @()
                                Unmatches     = @()
                                Missing       = @()
                            }
                        }

                        if ($bioControlsResult.CoveredBy.ResourceName -notcontains $bioObject.ResourceName -or $bioControlsResult.CoveredBy.ResourceInstanceName -notcontains $bioObject.ResourceInstanceName)
                        {
                            $bioControlsResult.CoveredBy += $bioObject
                            $bioControlsResult.MeasuresCount++
                        }

                        if ($propertiesMatch)
                        {
                            $bioControlsResult.Matched++
                            $bioControlsResult.Matches += [PSCustomObject]@{
                                TargetResourceName         = $currentObject.ResourceName
                                TargetResourceInstanceName = $currentObject.ResourceInstanceName
                            }
                        }
                        else
                        {
                            $bioControlsResult.Unmatched++
                            $bioControlsResult.Unmatches += [PSCustomObject]@{
                                TargetResourceName         = $currentObject.ResourceName
                                TargetResourceInstanceName = $currentObject.ResourceInstanceName
                            }
                        }
                        $bioControlsResults[$control] = $bioControlsResult

                        $controlDetails = $bioControlsDetails | Where-Object -FilterScript { $_.ControlNr -eq $control }

                        $detailedBIOControlsResults += [PSCustomObject]@{
                            ControlNr            = $control
                            Category             = $controlDetails.Category
                            BBN                  = $controlDetails.BBN
                            Title                = $controlDetails.Title
                            Description          = $controlDetails.Description
                            ResourceName         = $currentObject.ResourceName
                            ResourceInstanceName = $currentObject.ResourceInstanceName
                            CISNumber            = $bioObject.ResourceInstanceName
                            MeasuresCount        = 1
                            Score                = $measureCount
                            Timestamp            = $timestamp
                            RequiredMeasure      = $controlDetails.'Government Measure'
                        }
                    }
                }
                else
                {
                    $detailedBIOControlsResults += [PSCustomObject]@{
                        ControlNr            = '0'
                        Category             = 'General Recommended Practice'
                        BBN                  = '0'
                        Title                = 'General Recommended Practice'
                        Description          = 'General Recommended Practice'
                        ResourceName         = $currentObject.ResourceName
                        ResourceInstanceName = $currentObject.ResourceInstanceName
                        CISNumber            = $bioObject.ResourceInstanceName
                        MeasuresCount        = 1
                        Score                = $measureCount
                        Timestamp            = $timestamp
                        RequiredMeasure      = 'N/A'
                    }
                }
            }
        }
        else
        {
            Write-LogEntry -Message "Processing resource $($bioResourceName): Resource not found in current configuration" -Type Verbose

            $comparisonResults += [PSCustomObject]@{
                ReferenceResourceName         = $bioObject.ResourceName
                ReferenceResourceInstanceName = $bioObject.ResourceInstanceName
                TargetResourceName            = 'Missing'
                TargetResourceInstanceName    = 'Missing'
                PropertiesMatch               = $false
                PropertyDifferences           = @(
                    @{
                        PropertyName = 'Resource missing in the current configuration'
                        BIO          = ''
                        Current      = ''
                    }
                )
            }

            if ($bioObject.BIOControls)
            {
                $sourceBIOControls = $bioObject.BIOControls
                foreach ($control in $sourceBIOControls)
                {
                    $bioControlsResult = $bioControlsResults[$control]

                    if ($null -eq $bioControlsResult)
                    {
                        $bioControlsResult = [PSCustomObject]@{
                            BIOControls   = $control
                            MeasuresCount = 0
                            CoveredBy     = @()
                            Matched       = 0
                            Unmatched     = 0
                            TotalMissing  = 0
                            Matches       = @()
                            Unmatches     = @()
                            Missing       = @()
                        }
                    }

                    if ($bioControlsResult.CoveredBy.ResourceName -notcontains $bioObject.ResourceName -or $bioControlsResult.CoveredBy.ResourceInstanceName -notcontains $bioObject.ResourceInstanceName)
                    {
                        $bioControlsResult.CoveredBy += $bioObject
                        $bioControlsResult.MeasuresCount++
                    }

                    $bioControlsResult.TotalMissing++
                    $bioControlsResult.Missing += [PSCustomObject]@{
                        TargetResourceName         = $bioObject.ResourceName
                        TargetResourceInstanceName = $bioObject.ResourceInstanceName
                    }

                    $bioControlsResults[$control] = $bioControlsResult

                    $controlDetails = $bioControlsDetails | Where-Object -FilterScript { $_.ControlNr -eq $control }

                    $detailedBIOControlsResults += [PSCustomObject]@{
                        ControlNr            = $control
                        Category             = $controlDetails.Category
                        BBN                  = $controlDetails.BBN
                        Title                = $controlDetails.Title
                        Description          = $controlDetails.Description
                        ResourceName         = $bioObject.ResourceName
                        ResourceInstanceName = 'MeasureMissingInExport'
                        CISNumber            = $bioObject.ResourceInstanceName
                        MeasuresCount        = 1
                        Score                = 0
                        Timestamp            = $timestamp
                        RequiredMeasure      = $controlDetails.'Government Measure'
                    }
                }
            }
            else
            {
                $detailedBIOControlsResults += [PSCustomObject]@{
                    ControlNr            = '0'
                    Category             = 'General Recommended Practice'
                    BBN                  = '0'
                    Title                = 'General Recommended Practice'
                    Description          = 'General Recommended Practice'
                    ResourceName         = $currentObject.ResourceName
                    ResourceInstanceName = 'MeasureMissingInExport'
                    CISNumber            = $bioObject.ResourceInstanceName
                    MeasuresCount        = 1
                    Score                = 0
                    Timestamp            = $timestamp
                    RequiredMeasure      = 'N/A'
                }
            }
        }
        $currentCount++
    }
    Write-Progress -Activity 'Analyzing export' -Completed
    $ProgressPreference = 'SilentlyContinue'

    <#
    # Disabled because the M365 BIO template doesn't cover all BIO Controls and therefore will always show missing controls.
    Write-LogEntry -Message 'Checking for BIO Controls that are not covered'
    $diff = Compare-Object -ReferenceObject ( $detailedBIOControlsResults.ControlNr | Sort-Object -Unique) -DifferenceObject ($bioControlsDetails.ControlNr)
    $unprocessedControls = $diff | Where-Object { $_.SideIndicator -eq '=>' }
    if ($unprocessedControls.Count -gt 0)
    {
        foreach ($control in $unprocessedControls.InputObject)
        {
            $controlDetails = $bioControlsDetails | Where-Object -FilterScript { $_.ControlNr -eq $control }

            $detailedBIOControlsResults += [PSCustomObject]@{
                ControlNr            = $control
                Category             = $controlDetails.Category
                BBN                  = $controlDetails.BBN
                Title                = $controlDetails.Title
                Description          = $controlDetails.Description
                ResourceName         = 'N/A'
                ResourceInstanceName = 'ControlMissingInExport'
                CISNumber            = 'N/A'
                MeasuresCount        = 0
                Score                = 0
                Timestamp            = $timestamp
                RequiredMeasure      = $controlDetails.'Government Measure'
            }
        }
    }
    #>

    Write-LogEntry -Message 'Completed comparing current settings with BIO Baseline'

    # Export comparison results to a JSON file
    Write-LogEntry -Message "Saving Comparison results to '$resultComparisonFullPath'"
    $comparisonResults | ConvertTo-Json -Depth 10 | Set-Content -Path $resultComparisonFullPath

    # Export BIOControls-related results to a JSON file
    Write-LogEntry -Message "Saving BIOControls-related results to '$resultBIOControlsFullPath'"
    $bioControlsResults.Values | ConvertTo-Json -Depth 10 | Set-Content -Path $resultBIOControlsFullPath

    # Export Detailed BIOControls-related results to a CSV file
    Write-LogEntry -Message "Saving Detailed BIOControls-related results to '$resultRulesCSVFullPath'"
    $detailedBIOControlsResults | Export-Csv -Path $resultRulesCSVFullPath -Delimiter ';' -Encoding UTF8 -NoTypeInformation

    # Display a message indicating the exports completed
    Write-LogEntry -Message "Comparison results exported to 'comparison_results.json'"
    Write-LogEntry -Message "BIOControls-related results exported to 'biocontrols_results.json'"
}

end
{
    $WarningPreference = $currWarningPreference
    $ProgressPreference = $currProgressPreference

    Write-LogEntry -Message 'Completed BIO Comparison script'
    Stop-Transcript
}
