function Test-STweaksToggleRegistryState {
    <# Reads the actual Registry values after applying a Toggle; no inferred defaults. #>
    param(
        [Parameter(Mandatory = $true)][string]$ToggleId,
        [Parameter(Mandatory = $true)][bool]$Enabled
    )

    $entries = @($sync.configs.tweaks.$ToggleId.registry | Where-Object { $null -ne $_ })
    if ($entries.Count -eq 0) { return $false }

    if (@($entries | Where-Object { $_.Path -like 'HKU:\*' }).Count -gt 0 -and
        -not (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
        New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS -ErrorAction Stop | Out-Null
    }

    foreach ($entry in $entries) {
        $expected = if ($Enabled) { [string]$entry.Value } else { [string]$entry.OriginalValue }
        $pathExists = Test-Path -LiteralPath $entry.Path -ErrorAction Stop
        if (-not $pathExists) {
            if ($expected -eq '<RemoveEntry>') { continue }
            return $false
        }

        $key = Get-Item -LiteralPath $entry.Path -ErrorAction Stop
        $valueExists = $key.GetValueNames() -contains [string]$entry.Name
        if ($expected -eq '<RemoveEntry>') {
            if ($valueExists) { return $false }
            continue
        }
        if (-not $valueExists -or [string]$key.GetValueKind($entry.Name) -ne [string]$entry.Type -or
            [string]$key.GetValue($entry.Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) -cne $expected) {
            return $false
        }
    }

    return $true
}
