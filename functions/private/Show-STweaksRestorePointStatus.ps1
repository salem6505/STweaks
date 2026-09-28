function Show-STweaksRestorePointStatus {
    param([Parameter(Mandatory = $true)]$Result)

    # The UI is informational only: a user's response never counts as proof.
    if ($null -eq $sync.Form) { return [bool]$Result.Succeeded }

    if ($Result.Succeeded) {
        $details = "Verified Windows Restore Point: $($Result.Description) (No. $($Result.SequenceNumber))."
        if ($sync.WPFRestorePointStatus) {
            $sync.WPFRestorePointStatus.Text = $details
        }
        $choice = Show-WinUtilMessage -Title 'STweaks' -Message "$details`nOpen Windows System Protection before continuing? Select No to continue now." -Button 'YesNo' -Icon 'Information'
    }
    else {
        if ($sync.WPFRestorePointStatus) {
            $sync.WPFRestorePointStatus.Text = 'Restore Point could not be verified. Changes are blocked.'
        }
        $choice = Show-WinUtilMessage -Title 'STweaks' -Message "No changes were applied. A new Windows Restore Point could not be verified: $($Result.Reason)`nOpen Windows System Protection to check its settings?" -Button 'YesNo' -Icon 'Warning'
    }

    if ($choice -eq [System.Windows.MessageBoxResult]::Yes) {
        $opened = Show-STweaksSystemProtection
        if (-not $opened) { return $false }
        if ($Result.Succeeded) {
            $confirmation = Show-WinUtilMessage -Title 'STweaks' -Message 'After reviewing Windows System Protection, select OK to continue this change, or Cancel to stop.' -Button 'OKCancel' -Icon 'Information'
            return ($confirmation -eq [System.Windows.MessageBoxResult]::OK)
        }
    }
    return [bool]$Result.Succeeded
}
