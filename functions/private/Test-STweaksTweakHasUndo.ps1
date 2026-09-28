function Test-STweaksTweakHasUndo {
    param([Parameter(Mandatory = $true)][string]$TweakId)

    $definition = $sync.configs.tweaks.$TweakId
    if (-not $definition -or $definition.appx) { return $false }

    $registry = @($definition.registry | Where-Object { $null -ne $_ -and -not $_.Values })
    $services = @($definition.service | Where-Object { $null -ne $_ })
    if (@($registry | Where-Object { $null -eq $_.OriginalValue }).Count -gt 0 -or
        @($services | Where-Object { -not $_.OriginalType }).Count -gt 0 -or
        ($definition.InvokeScript -and -not $definition.UndoScript)) {
        return $false
    }

    return ($registry.Count -gt 0 -or $services.Count -gt 0 -or [bool]$definition.UndoScript)
}
