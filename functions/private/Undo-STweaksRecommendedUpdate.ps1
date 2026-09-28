function Undo-STweaksRecommendedUpdate {
    <# Removes only the AUOptions value written by this feature, when unchanged. #>
    $journalPath = Join-Path (Join-Path $env:ProgramData 'STweaks') 'recommended-windows-update.json'
    if (-not (Test-Path -LiteralPath $journalPath)) {
        throw 'There is no recorded Recommended change to undo.'
    }
    $record = Get-Content -LiteralPath $journalPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if ($record.Version -ne 1 -or $record.Feature -ne 'STweaksRecommendedWindowsUpdate' -or
        $record.PriorAUOptionsExists -ne $false -or $record.WrittenAUOptions -ne 2) {
        throw 'The Recommended operation journal is invalid; automatic undo was blocked.'
    }
    $current = Get-STweaksWindowsUpdateState
    if ($current.AUOptions -ne 2 -or $current.NoAutoUpdate -ne $null -or $current.State -ne 'Notify before download') {
        throw 'The update policy changed since STweaks applied it; automatic undo was blocked.'
    }
    $restore = New-STweaksRestorePoint
    $continueChange = Show-STweaksRestorePointStatus -Result $restore
    if (-not $continueChange -and $restore.Succeeded) { throw 'Undo cancelled after viewing System Protection.' }
    if (-not $restore.Succeeded) {
        throw "A fresh verified Restore Point is required: $($restore.Reason)"
    }
    $current = Get-STweaksWindowsUpdateState
    if ($current.AUOptions -ne 2 -or $current.NoAutoUpdate -ne $null -or $current.State -ne 'Notify before download') {
        throw 'The policy changed during undo; no setting was changed.'
    }
    Remove-ItemProperty -LiteralPath $current.Path -Name 'AUOptions' -ErrorAction Stop
    $verified = Get-STweaksWindowsUpdateState
    if ($null -ne $verified.AUOptions) {
        throw 'Undo could not be verified; the operation journal has been kept.'
    }
    Remove-Item -LiteralPath $journalPath -ErrorAction Stop
    return [pscustomobject]@{ Succeeded = $true; RestorePointSequence = $restore.SequenceNumber }
}
