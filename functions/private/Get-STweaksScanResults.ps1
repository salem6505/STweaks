function Get-STweaksScanResults {
    <#
    .SYNOPSIS
        Reads factual states for Essential Tweaks only. This function never changes Windows.
    #>
    param([Parameter(Mandatory = $true)]$TweakDefinitions)

    $started = (Get-Date).ToUniversalTime().ToString('o')
    $rows = [System.Collections.Generic.List[object]]::new()

    foreach ($definition in $TweakDefinitions.PSObject.Properties) {
        $tweak = $definition.Value
        if ([string]$tweak.category -cne 'Essential Tweaks') { continue }
        $row = [ordered]@{
            Id             = $definition.Name
            Category       = [string]$tweak.category
            Name           = [string]$tweak.Content
            State          = 'Unknown'
            Recommendation = 'No verified recommendation'
            Reason         = 'A reliable read-only detector has not been implemented for this option.'
            Actionable     = $false
            ActionId       = $null
            Detector       = 'none'
            ActiveDownloadMode = $null
        }

        # Registry values are observable even when the source also invokes
        # scripts or changes services. Mixed operations remain Unknown overall.
        $registry = @($tweak.registry | Where-Object { $null -ne $_ })
        if ($registry.Count -gt 0) {
            $observation = Get-STweaksRegistryObservation -Entries $registry
            if ($observation.Observations.Count -gt 0) {
                $row.Observation = $observation
                if ($tweak.InvokeScript -or $tweak.service -or $tweak.appx) {
                    $row.Reason = 'Registry values are shown below. Other changes made by this option are not verified; overall state is Unknown.'
                    $row.Detector = 'partial-registry-values-v2'
                }
                else {
                    $row.State = $observation.State
                    $row.Reason = $observation.Reason
                    $row.Detector = 'registry-values-v2'
                }
            }
        }

        if ($definition.Name -eq 'WPFTweaksDeliveryOptimization') {
            try {
                $activeMode = [string](Get-DODownloadMode -ErrorAction Stop)
                if (-not [string]::IsNullOrWhiteSpace($activeMode)) {
                    $row.ActiveDownloadMode = $activeMode
                    $row.Reason = 'Windows reported the active download mode; the Registry policy value is shown below. Peer-capable mode does not prove current uploads.'
                    if ($activeMode -in @('Lan', 'Group', 'Internet')) {
                        $row.State = "Peer sharing allowed ($activeMode)"
                    }
                    elseif ($activeMode -eq 'CdnOnly') {
                        $row.State = 'Peer sharing off (HTTP only)'
                    }
                }
                # Recommend only when the effective mode allows peers and the
                # source policy is absent. Never overwrite existing policy.
                if ($activeMode -in @('Lan', 'Group', 'Internet') -and
                    $observation.Observations.Count -eq 1 -and
                    $observation.Observations[0].Name -eq 'DODownloadMode' -and
                    $observation.Observations[0].Expected -eq '0' -and
                    $observation.Observations[0].Status -eq 'Not set') {
                    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
                    $machine = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
                    $mdmPath = 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\DeliveryOptimization'
                    $mdmConfigured = Test-Path -LiteralPath $mdmPath -ErrorAction Stop
                    if ([int]$os.ProductType -eq 1 -and [int]$os.BuildNumber -ge 10240 -and
                        $machine.PartOfDomain -eq $false -and -not $mdmConfigured) {
                        $row.Actionable = $true
                        $row.ActionId = $definition.Name
                        $row.Recommendation = 'Disable peer sharing; HTTP downloads remain available.'
                        $row.Reason += ' No existing download-mode policy was found to overwrite.'
                    }
                }
            }
            catch {
                # Unavailable cmdlets or uncertain OS/management state leave the
                # Registry observation intact without recommending a change.
            }
        }

        $rows.Add([pscustomobject]$row)
    }

    return [pscustomobject]@{
        Version        = 2
        ScanId         = [guid]::NewGuid().ToString('N')
        StartedAtUtc   = $started
        CompletedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        Results        = @($rows.ToArray())
    }
}
