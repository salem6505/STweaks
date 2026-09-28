function Select-STweaksRecommendedTweaks {
    <# Only selects reviewed Essential results; never changes Windows. #>
    param([Parameter(Mandatory = $true)]$Snapshot)

    $ids = @($Snapshot.Results | Where-Object {
        $_.Actionable -and $_.ActionId -eq $_.Id -and
        $sync.configs.tweaks.$($_.Id).category -eq 'Essential Tweaks' -and
        $sync.configs.tweaks.$($_.Id).Type -ne 'Toggle'
    } | ForEach-Object { $_.Id })

    Invoke-WPFTab 'WPFTab2BT'
    Invoke-WPFPresets -preset $ids -imported $true -checkboxfilterpattern 'WPFTweak*'
    $sync.RecommendedSelectionIds = @($ids)
    $sync.WPFScanReviewNotice.Text = if ($ids.Count -gt 0) {
        $lines = @($Snapshot.Results | Where-Object { $_.Id -in $ids } | ForEach-Object {
            $current = if ($_.ActiveDownloadMode) { $_.ActiveDownloadMode } else { $_.State }
            "$($_.Name): $current → $($_.Recommendation)"
        })
        "Scan replaced the previous tweak selection with $($ids.Count) recommendation(s):`n$($lines -join "`n")`nReview checked tweaks and any pending toggles or DNS change before Run Tweaks. Return to Scan for all current states."
    }
    else {
        'Scan found no eligible recommendation and cleared previous tweak selections. Review any pending toggles or DNS change before Run Tweaks. Return to Scan for all results.'
    }
    return $ids
}
