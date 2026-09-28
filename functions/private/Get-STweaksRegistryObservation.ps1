function Get-STweaksRegistryObservation {
    <# Reads simple Registry values for a single Essential definition. No mutations. #>
    param([Parameter(Mandatory = $true)]$Entries)

    $observations = [System.Collections.Generic.List[object]]::new()
    foreach ($entry in @($Entries)) {
        if (-not $entry.Name -or [string]$entry.Path -notmatch '^HK(LM|CU):\\' -or
            [string]$entry.Type -ne 'DWord' -or [string]$entry.Value -notmatch '^[0-9]+$' -or
            $entry.Values) {
            return [pscustomobject]@{ State = 'Unknown'; Reason = 'The setting uses a Registry value this detector cannot safely interpret.'; Observations = @() }
        }

        $observed = [ordered]@{
            Path = [string]$entry.Path
            Name = [string]$entry.Name
            Expected = [string]$entry.Value
            Actual = $null
            Status = 'Not set'
        }
        try {
            if (Test-Path -LiteralPath $entry.Path -ErrorAction Stop) {
                $key = Get-Item -LiteralPath $entry.Path -ErrorAction Stop
                if ($key.GetValueNames() -contains $entry.Name) {
                    if ($key.GetValueKind($entry.Name) -ne [Microsoft.Win32.RegistryValueKind]::DWord) {
                        $observed.Actual = '[not a DWORD]'
                        $observed.Status = 'Differs from definition'
                    }
                    else {
                        $value = $key.GetValue($entry.Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                        $observed.Actual = [string]$value
                        $observed.Status = if ($observed.Actual -eq $observed.Expected) { 'Matches definition' } else { 'Differs from definition' }
                    }
                }
            }
        }
        catch {
            $observed.Status = 'Unreadable'
        }
        $observations.Add([pscustomobject]$observed)
    }

    $values = @($observations.ToArray())
    $matched = @($values | Where-Object { $_.Status -eq 'Matches definition' }).Count
    $missing = @($values | Where-Object { $_.Status -eq 'Not set' }).Count
    $unreadable = @($values | Where-Object { $_.Status -eq 'Unreadable' }).Count
    $state = if ($unreadable -gt 0) {
        'Unknown'
    }
    else {
        "Registry values matching definition: $matched/$($values.Count); not set: $missing"
    }
    return [pscustomobject]@{
        State = $state
        Reason = 'Registry observation only; Windows applicability and effective behavior have not been verified.'
        Observations = $values
    }
}
