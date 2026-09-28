function Invoke-STweaksRecommendedUpdate {
    <# Applies only the Windows Update notify-before-download policy after a scan. #>
    param([Parameter(Mandatory = $true)]$ScanState)

    $current = Get-STweaksWindowsUpdateState
    if (-not $ScanState.Actionable -or -not $current.Actionable -or
        $ScanState.State -ne $current.State -or
        $ScanState.AUOptions -ne $current.AUOptions -or
        $ScanState.NoAutoUpdate -ne $current.NoAutoUpdate) {
        throw 'The scan result is no longer applicable. Run Scan again before applying Recommended.'
    }

    $journalDirectory = Join-Path $env:ProgramData 'STweaks'
    $journalPath = Join-Path $journalDirectory 'recommended-windows-update.json'
    if (Test-Path -LiteralPath $journalPath) {
        throw 'A previous Recommended change is recorded. Resolve or undo it before applying again.'
    }

    $restore = New-STweaksRestorePoint
    $continueChange = Show-STweaksRestorePointStatus -Result $restore
    if (-not $continueChange -and $restore.Succeeded) { throw 'Change cancelled after viewing System Protection.' }
    if (-not $restore.Succeeded) {
        throw "A fresh verified Restore Point is required: $($restore.Reason)"
    }

    # Save ownership before changing Windows. CreateNew refuses an existing journal.
    New-Item -ItemType Directory -Path $journalDirectory -Force -ErrorAction Stop | Out-Null
    $record = [pscustomobject]@{
        Version = 1
        Feature = 'STweaksRecommendedWindowsUpdate'
        PriorAUOptionsExists = $false
        WrittenAUOptions = 2
        RestorePointSequence = $restore.SequenceNumber
        StartedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    }
    $stream = [System.IO.File]::Open($journalPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    try {
        $writer = [System.IO.StreamWriter]::new($stream, [System.Text.UTF8Encoding]::new($false))
        try { $writer.Write(($record | ConvertTo-Json -Depth 3)); $writer.Flush() }
        finally { $writer.Dispose() }
    }
    finally { $stream.Dispose() }

    # Recheck after the restore point and journal write; a concurrent policy change
    # must not be overwritten. Keep the journal for investigation on failure.
    try {
        $current = Get-STweaksWindowsUpdateState
        if (-not $current.Actionable) {
            throw 'The Windows Update policy changed while preparing the action. No setting was written.'
        }

        New-Item -Path $current.Path -Force -ErrorAction Stop | Out-Null
        New-ItemProperty -Path $current.Path -Name 'AUOptions' -Value 2 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
        $verified = Get-STweaksWindowsUpdateState
        if ($verified.AUOptions -ne 2 -or $verified.State -ne 'Notify before download') {
            throw 'The policy value could not be verified; review the saved operation journal.'
        }
    }
    catch {
        # Remove a prepared journal only when a read proves the value was never
        # set. Otherwise keep the record so a partial change cannot be lost.
        $afterFailure = Get-STweaksWindowsUpdateState
        if ($afterFailure.Actionable -and $null -eq $afterFailure.AUOptions) {
            Remove-Item -LiteralPath $journalPath -Force -ErrorAction SilentlyContinue
        }
        throw
    }
    return [pscustomobject]@{ Succeeded = $true; RestorePointSequence = $restore.SequenceNumber }
}
