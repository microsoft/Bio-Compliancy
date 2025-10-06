$script:CurrentVersion = '2.2.0-R02'

function Write-LogEntry
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Message,

        [Parameter()]
        [Validateset('Info', 'Warning', 'Error', 'Verbose', 'Debug')]
        [System.String]
        $Type = 'Info'
    )

    $VerboseMode = $PSCmdlet.SessionState.PSVariable.Get('VerbosePreference').Value -ne 'SilentlyContinue'
    $DebugMode = $PSCmdlet.SessionState.PSVariable.Get('DebugPreference').Value -ne 'SilentlyContinue'

    if (($Type -eq 'Debug' -and $DebugMode -eq $false) -or ($Type -eq 'Verbose' -and $VerboseMode -eq $false))
    {
        return
    }

    $PSCallStack = Get-PSCallStack
    $Commands = @($PSCallStack.Command)
    $Me = $Commands[0]
    $Caller = if ($Commands -gt 1)
    {
        $Commands[1..($Commands.Length)].where({ $_ -ne $Me }, 'First')
    }
    if (!$Caller)
    {
        $Caller = ''
    } # Prevent that the array index evaluates to null.

    $outputText = [System.Collections.Generic.List[HashTable]]::new()
    $outputText.Add( @{ Object = Get-Date -Format 'yyyy-MM-dd HH:mm:ss ' } )

    switch ($Type)
    {
        'Info'
        {
            $outputText.Add(@{ BackgroundColor = 'Green'; ForegroundColor = 'Black'; Object = '[INFO]' })
        }
        'Warning'
        {
            $outputText.Add(@{ BackgroundColor = 'Yellow'; ForegroundColor = 'Black'; Object = '[WARNING]' })
        }
        'Error'
        {
            $outputText.Add(@{ BackgroundColor = 'Red'; ForegroundColor = 'Black'; Object = '[ERROR]' })
        }
        'Verbose'
        {
            $outputText.Add(@{ BackgroundColor = 'Cyan'; ForegroundColor = 'White'; Object = '[VERBOSE]' })
        }
        'Debug'
        {
            $outputText.Add(@{ BackgroundColor = 'Magenta'; ForegroundColor = 'Black'; Object = '[DEBUG]' })
        }
    }

    if ($Caller -and $Caller -ne '<ScriptBlock>')
    {
        $outputText.Add( @{ Object = " $($Caller):" } )
    }

    $outputText.Add( @{ Object = ' ' } )

    switch ($Type)
    {
        'Warning'
        {
            $outputText.Add(@{ ForegroundColor = 'Yellow'; Object = $Message; BackgroundColor = 'Black' })
        }
        'Error'
        {
            $outputText.Add(@{ ForegroundColor = 'Red'; Object = $Message; BackgroundColor = 'Black' })
        }
        'Verbose'
        {
            $outputText.Add(@{ ForegroundColor = 'Cyan'; Object = $Message })
        }
        'Debug'
        {
            $outputText.Add(@{ ForegroundColor = 'Magenta'; Object = $Message })
        }
        Default
        {
            $outputText.Add(@{ Object = $Message })
        }
    }

    foreach ($textLine in $outputText)
    {
        Write-Host -NoNewline @textLine
    }
    Write-Host # New line
}

function Test-IsWindowsTerminal
{
    [CmdletBinding()]
    param ()

    # Check if PowerShell version is 5.1 or below, or if running on Windows
    if ($PSVersionTable.PSVersion.Major -le 5 -or $IsWindows -eq $true)
    {
        $currentPid = $PID

        # Loop through parent processes to check if Windows Terminal is in the hierarchy
        while ($currentPid)
        {
            try
            {
                $process = Get-CimInstance Win32_Process -Filter "ProcessId = $currentPid" -ErrorAction Stop -Verbose:$false
            }
            catch
            {
                # Return false if unable to get process information
                return $false
            }

            Write-Verbose -Message "ProcessName: $($process.Name), Id: $($process.ProcessId), ParentId: $($process.ParentProcessId)"

            # Check if the current process is Windows Terminal
            if ($process.Name -eq 'WindowsTerminal.exe')
            {
                return $true
            }
            else
            {
                # Move to the parent process
                $currentPid = $process.ParentProcessId
            }
        }

        # Return false if Windows Terminal is not found in the hierarchy
        return $false
    }
    else
    {
        Write-Verbose -Message 'Exiting due to non-Windows environment'
        return $false
    }
}

function Test-IsWindowsTerminal
{
    [CmdletBinding()]
    param ()

    # Check if PowerShell version is 5.1 or below, or if running on Windows
    if ($PSVersionTable.PSVersion.Major -le 5 -or $IsWindows -eq $true)
    {
        $currentPid = $PID

        # Loop through parent processes to check if Windows Terminal is in the hierarchy
        while ($currentPid)
        {
            try
            {
                $process = Get-CimInstance Win32_Process -Filter "ProcessId = $currentPid" -ErrorAction Stop -Verbose:$false
            }
            catch
            {
                # Return false if unable to get process information
                return $false
            }

            Write-Verbose -Message "ProcessName: $($process.Name), Id: $($process.ProcessId), ParentId: $($process.ParentProcessId)"

            # Check if the current process is Windows Terminal
            if ($process.Name -eq 'WindowsTerminal.exe')
            {
                return $true
            }
            else
            {
                # Move to the parent process
                $currentPid = $process.ParentProcessId
            }
        }

        # Return false if Windows Terminal is not found in the hierarchy
        return $false
    }
    else
    {
        Write-Verbose -Message 'Exiting due to non-Windows environment'
        return $false
    }
}

function Assert-IsNonInteractiveShell
{
    # Test each Arg for match of abbreviated '-NonInteractive' command.
    $NonInteractive = [Environment]::GetCommandLineArgs() | Where-Object { $_ -like '-NonI*' }

    if ([Environment]::UserInteractive -and -not $NonInteractive -and -not (Test-IsWindowsTerminal))
    {
        # We are in an interactive shell, but not in Windows Terminal.
        return $false
    }

    return $true
}

function Show-CurrentVersion
{
    Write-LogEntry -Message ("Current version of the 'Microsoft 365 BIO Compliancy Template' is: [{0}]" -f $script:CurrentVersion)
}

function Test-Value
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [AllowNull()]
        [System.Object]
        $Reference,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [AllowNull()]
        [System.Object]
        $Difference,

        [Parameter()]
        [System.String]
        $Path = '$InputObject'
    )

    $testResult = $true

    $referenceType = 'Null'
    if ($null -ne $Reference)
    {
        $referenceType = $Reference.GetType().ToString()
    }

    $differenceType = 'Null'
    if ($null -ne $Difference)
    {
        $differenceType = $Difference.GetType().ToString()
    }

    if ($referenceType -ne $differenceType)
    {
        Write-LogEntry -Message "Types are not equal, returing False: Reference [$referenceType] - Difference [$differenceType]" -Type Verbose
        return $false
    }

    Write-LogEntry -Message "[Test-Value] Type: $referenceType" -Type Verbose
    switch ($referenceType)
    {
        'System.Object[]'
        {
            $subTestResult = Test-Array -Reference $Reference -Difference $Difference -Path $Path
            if ($subTestResult -eq $false)
            {
                $testResult = $false
            }
        }
        'System.Management.Automation.PSCustomObject'
        {
            $subTestResult = Test-PSCustomObject -Reference $Reference -Difference $Difference -Path $Path
            if ($subTestResult -eq $false)
            {
                $testResult = $false
            }
        }
        Default
        {
            if ($Reference -ne $Difference)
            {
                Write-LogEntry -Message "Item $Path is does not match: Reference [$($Reference)] - Difference [$($Difference)]" -Type Verbose
                $testResult = $false
            }
        }
    }

    return $testResult
}

function Test-Array
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [System.Array]
        $Reference,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [System.Array]
        $Difference,

        [Parameter()]
        [System.String]
        $Path = ''
    )

    $testResult = $true

    # NOTE: If there are no nested array objects, we can use Compare-Object instead of the foreach loop.
    # Compare-Object has better performance.

    if (($Reference.Count -eq 0) -and ($Difference.Count -ne 0))
    {
        Write-LogEntry -Message '[Test-Array] Reference does not have any items, but Difference does.' -Type Verbose
        return $false
    }

    $counter = 0
    foreach ($item in $Reference)
    {
        $currentPath = "$Path[$counter]"
        $itemType = $item.GetType().FullName
        Write-LogEntry -Message "[Test-Array] Type: $itemType" -Type Verbose
        switch ($itemType)
        {
            'System.Collections.Hashtable'
            {
                Write-LogEntry -Message '[Test-Array] Not yet implemented' -Type Verbose
                # NOT YET IMPLEMENTED
                break
            }
            'System.Array'
            {
                Write-LogEntry -Message '[Test-Array] Not yet implemented' -Type Verbose
                # NOT YET IMPLEMENTED
                break
            }
            'System.Management.Automation.PSCustomObject'
            {
                # NOT YET IMPLEMENTED
                break

                # Test code
                $differenceItem = $Difference # Needs a method to retrieve the object from the collection
                if ($null -ne $differenceItem)
                {
                    $subTestResult = Test-PSCustomObject -Reference $item -Difference $differenceItem -Path $currentPath
                    if ($subTestResult -eq $false)
                    {
                        $testResult = $false
                    }
                }
                else
                {
                    Write-LogEntry -Message 'Item kan niet gevonden worden!'
                    $testResult = $false
                }
            }
            Default
            {
                if ($item -notin $Difference)
                {
                    Write-LogEntry -Message "Could not find [$Path.$item] in Difference" -Type Verbose
                    $testResult = $false
                    break
                }
            }
        }
        $counter++
    }

    return $testResult
}

function Test-PSCustomObject
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [PSCustomObject]
        $Reference,

        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [PSCustomObject]
        $Difference,

        [Parameter()]
        [System.String]
        $Path = ''
    )

    $testResult = $true

    foreach ($property in $Reference.PSObject.Properties)
    {
        $propertyName = $property.Name
        $propertyType = $Reference.$propertyName.GetType().ToString()

        $currentPath = "$Path.$propertyName"

        Write-LogEntry -Message "[Test-PSCustomObject] Type: $propertyType" -Type Verbose

        switch ($propertyType)
        {
            'System.Object[]'
            {
                $subTestResult = Test-Array -Reference $Reference.$propertyName -Difference $Difference.$propertyName -Path $currentPath
                if ($subTestResult -eq $false)
                {
                    $testResult = $false
                }
            }
            'System.Management.Automation.PSCustomObject'
            {
                $subTestResult = Test-PSCustomObject -Reference $Reference.$propertyName -Difference $Difference.$propertyName -Path $currentPath
                if ($subTestResult -eq $false)
                {
                    $testResult = $false
                }
            }
            Default
            {
                $subTestResult = Test-Value -Reference $Reference.$propertyName -Difference $Difference.$propertyName -Path $currentPath
                if ($subTestResult -eq $false)
                {
                    $testResult = $false
                }
            }
        }
    }

    return $testResult
}

function Remove-CIMInstance
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Object]
        $InputObject
    )

    switch ($InputObject.GetType().FullName)
    {
        'System.Object[]'
        {
            foreach ($item in $InputObject)
            {
                Remove-CimInstance -InputObject $item
            }
        }
        'System.Management.Automation.PSCustomObject'
        {
            foreach ($prop in $InputObject.PSObject.Properties)
            {
                if ($prop.Name -eq 'CIMInstance')
                {
                    $InputObject.PSObject.Properties.Remove('CIMInstance')
                }

                if ($prop.TypeNameOfValue -eq 'System.Object[]' -or $prop.TypeNameOfValue -eq 'System.Management.Automation.PSCustomObject')
                {
                    Remove-CimInstance -InputObject $prop.Value
                }
            }
        }
    }
}

Export-ModuleMember -Function Write-LogEntry, Assert-IsNonInteractiveShell, Show-CurrentVersion, Test-Value, Remove-CIMInstance
