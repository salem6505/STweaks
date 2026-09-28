function Invoke-WPFtweaksbutton {
  <#

    .SYNOPSIS
        Invokes the functions associated with each group of checkboxes

  #>

  if($sync.ProcessRunning) {
    $msg = "[Invoke-WPFtweaksbutton] Install process is currently running."
    [System.Windows.MessageBox]::Show($msg, "Winutil", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
    return
  }

  $Tweaks = $sync.selectedTweaks
  $dnsProvider = $sync["WPFchangedns"].text
  if (-not ($dnsProvider)) {
    $dnsProvider = "Default"
  }
  $restorePointTweak = "WPFTweaksRestorePoint"
  # Toggle controls reflect the current Windows state. Their current checked
  # position is not a request to apply the action again.
  $tweaksToRun = @($Tweaks | Where-Object {
    $_ -ne $restorePointTweak -and $sync.configs.tweaks.$_.Type -ne 'Toggle'
  })
  $toggleChanges = @($sync.PendingToggles.Keys | Sort-Object | ForEach-Object {
    [pscustomobject]@{ Id = $_; Enabled = [bool]$sync.PendingToggles[$_] }
  })
  $totalSteps = [Math]::Max(($tweaksToRun.Count + $toggleChanges.Count + [int]($dnsProvider -ne 'Default')), 1)
  $completedSteps = 0
  Write-WinUtilLog -Component "Tweaks" -Message "Tweaks requested: $(@($Tweaks).Count) selected tweak(s), DNS provider: $dnsProvider"

  if ($tweaksToRun.Count -eq 0 -and $toggleChanges.Count -eq 0 -and $dnsProvider -eq "Default") {
    $msg = "Please check the tweaks you wish to perform."
    [System.Windows.MessageBox]::Show($msg, "Winutil", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
    return
  }

  if (@($tweaksToRun | Where-Object { $_ -in $sync.RecommendedSelectionIds }).Count -gt 0) {
    $fresh = Get-STweaksScanResults -TweakDefinitions $sync.configs.tweaks
    $stale = @($tweaksToRun | Where-Object {
      $candidateId = $_
      $candidateId -in $sync.RecommendedSelectionIds -and
      -not @($fresh.Results | Where-Object { $_.Id -eq $candidateId -and $_.Actionable }).Count
    })
    if ($stale.Count -gt 0) {
      Show-WinUtilMessage -Title 'STweaks' -Icon 'Warning' -Message 'A recommended setting changed since Scan. No changes were applied. Run Scan again to refresh the selection.' | Out-Null
      return
    }
  }

  Set-WinUtilTweaksProgressIndicator -Visible $true -Label "Creating and verifying a Restore Point" -Percent 0
  $restore = New-STweaksRestorePoint
  $continueChange = Show-STweaksRestorePointStatus -Result $restore
  if (-not $continueChange) {
    Set-WinUtilTweaksProgressIndicator -Visible $false
    $reason = if ($restore.Succeeded) { 'Cancelled after viewing System Protection.' } else { "Restore Point unavailable: $($restore.Reason)" }
    Write-WinUtilLog -Level 'WARN' -Component 'Tweaks' -Message "No changes applied; $reason"
    return
  }
  Write-WinUtilLog -Component "Tweaks" -Message "Verified Restore Point sequence $($restore.SequenceNumber) before changes."
  if ($tweaksToRun.Count -eq 0 -and $toggleChanges.Count -eq 0 -and $dnsProvider -eq 'Default') {
    Set-WinUtilTweaksProgressIndicator -Visible $false
    return
  }

  # Mark the batch busy before queueing so another click cannot queue changes.
  $sync.ProcessRunning = $true
  try {
  Invoke-WPFRunspace -ParameterList @(("tweaks", $tweaksToRun), ("toggleChanges", $toggleChanges), ("dnsProvider", $dnsProvider), ("completedSteps", $completedSteps), ("totalSteps", $totalSteps)) -ErrorAction Stop -ScriptBlock {
    param($tweaks, $toggleChanges, $dnsProvider, $completedSteps, $totalSteps)

    $sync.ProcessRunning = $true
    try {
    $failures = [System.Collections.Generic.List[string]]::new()

    if ($completedSteps -eq 0) {
      if ($Tweaks.count -eq 1) {
        Invoke-WPFUIThread -ScriptBlock { Set-WinUtilTaskbaritem -state "Indeterminate" -value 0.01 -overlay "logo" }
      } else {
        Invoke-WPFUIThread -ScriptBlock{ Set-WinUtilTaskbaritem -state "Normal" -value 0.01 -overlay "logo" }
      }
    }

    if ($dnsProvider -ne "Default") {
      $dnsResult = @(Set-WinUtilDNS -DNSProvider $dnsProvider)
      if ($dnsResult[-1] -ne $true) {
        $failures.Add('DNS change failed.')
        Write-WinUtilLog -Level "ERROR" -Component "Tweaks" -Message "DNS change failed; processing independent selected tweaks."
      }
      $completedSteps++
    }

    for ($i = 0; $i -lt $tweaks.Count; $i++) {
      Set-WinUtilTweaksProgressIndicator -Visible $true -Label "Applying $($tweaks[$i]) ($($completedSteps + 1)/$totalSteps)" -Percent ($completedSteps / $totalSteps * 100)
      try {
        if ($tweaks[$i] -in $sync.RecommendedSelectionIds) {
          $candidateId = $tweaks[$i]
          $latest = Get-STweaksScanResults -TweakDefinitions $sync.configs.tweaks
          if (-not @($latest.Results | Where-Object { $_.Id -eq $candidateId -and $_.Actionable }).Count) {
            throw 'This recommendation changed before it could be applied. Run Scan again.'
          }
        }
        Invoke-WinUtilTweaks $tweaks[$i] -ErrorAction Stop
      }
      catch {
        $failures.Add("$($tweaks[$i]): $($_.Exception.Message)")
        Write-WinUtilLog -Level 'ERROR' -Component 'Tweaks' -Message "Tweak $($tweaks[$i]) failed: $($_.Exception.Message)"
      }
      $completedSteps++
      $progress = $completedSteps / $totalSteps
      Invoke-WPFUIThread -ScriptBlock { Set-WinUtilTaskbaritem -value $progress }
    }
    foreach ($change in $toggleChanges) {
      Set-WinUtilTweaksProgressIndicator -Visible $true -Label "Applying $($change.Id) ($($completedSteps + 1)/$totalSteps)" -Percent ($completedSteps / $totalSteps * 100)
      try {
        Invoke-WinUtilTweaks $change.Id -undo:(-not $change.Enabled) -ErrorAction Stop
        if ($sync.ToggleStatusCache) { $sync.ToggleStatusCache.Remove($change.Id) | Out-Null }
        if (-not (Test-STweaksToggleRegistryState -ToggleId $change.Id -Enabled $change.Enabled)) {
          throw 'The actual Registry values did not match the selected toggle position.'
        }
        Invoke-WPFUIThread -ScriptBlock {
          $sync[$change.Id].Tag.InitialIsChecked = [bool]$change.Enabled
          if ([bool]$sync[$change.Id].IsChecked -eq [bool]$change.Enabled) {
            $sync.PendingToggles.Remove($change.Id)
          }
          else { $sync.PendingToggles[$change.Id] = [bool]$sync[$change.Id].IsChecked }
        }
      }
      catch {
        $failures.Add("$($change.Id): $($_.Exception.Message)")
        Write-WinUtilLog -Level 'ERROR' -Component 'Tweaks' -Message "Toggle $($change.Id) failed: $($_.Exception.Message)"
      }
      $completedSteps++
      Invoke-WPFUIThread -ScriptBlock { Set-WinUtilTaskbaritem -value ($completedSteps / $totalSteps) }
    }
    Set-WinUtilTweaksProgressIndicator -Visible $true -Label "Commands processed; use Scan to verify states" -Percent 100
    Invoke-WPFUIThread -ScriptBlock {
      $sync.LastScanSnapshot = $null
      $sync.RecommendedSelectionIds = @()
      if ($sync.WPFScanResults.Children.Count -gt 0) {
        $sync.WPFScanResults.Children[0].Text = 'Previous scan (historical). Run Scan again to refresh.'
      }
    }
    $sync.ProcessRunning = $false
    if ($failures.Count -gt 0) {
      Invoke-WPFUIThread -ScriptBlock {
        Set-WinUtilTaskbaritem -state 'Error' -overlay 'warning'
        Show-WinUtilMessage -Message ("Some selected tasks failed:`n" + ($failures -join "`n") + "`nRun Scan to check the actual state of detectable settings.") -Title 'STweaks' -Button 'OK' -Icon 'Warning'
      }
    }
    else {
      Invoke-WPFUIThread -ScriptBlock { Set-WinUtilTaskbaritem -state 'None' }
    }
    Write-Host "================================="
    Write-Host "--   Tweak commands processed  ---"
    Write-Host "================================="
    Write-WinUtilLog -Component "Tweaks" -Message "Tweak commands processed. Scan verification may still be required."
    }
    finally { $sync.ProcessRunning = $false }
  } | Out-Null
  }
  catch {
    $sync.ProcessRunning = $false
    Set-WinUtilTweaksProgressIndicator -Visible $false
    Show-WinUtilMessage -Message "Could not start the selected tweaks: $($_.Exception.Message)" -Title 'STweaks' -Button 'OK' -Icon 'Warning'
  }
}
