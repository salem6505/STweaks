function Show-STweaksScanResults {
    <# Renders read-only observations and recommendations. Selection lives on Tweaks. #>
    param([Parameter(Mandatory = $true)]$Snapshot)

    $sync.WPFScanResults.Children.Clear()

    $heading = New-Object System.Windows.Controls.TextBlock
    $heading.Text = "Scan results — $(@($Snapshot.Results).Count) checks"
    $heading.SetResourceReference([System.Windows.Controls.TextBlock]::FontSizeProperty, 'HeaderFontSize')
    $heading.FontWeight = 'SemiBold'
    $heading.Foreground = [System.Windows.Media.Brushes]::White
    $sync.WPFScanResults.Children.Add($heading) | Out-Null

    $coverage = New-Object System.Windows.Controls.TextBlock
    $measured = @($Snapshot.Results | Where-Object { $_.State -ne 'Unknown' }).Count
    $coverage.Text = "$measured observed states. Unknown means a reliable detector is not yet available. Eligible recommendations are selected on Tweaks for your review."
    $coverage.Margin = '0,8,0,16'
    $coverage.TextWrapping = 'Wrap'
    $coverage.SetResourceReference([System.Windows.Controls.TextBlock]::FontSizeProperty, 'FontSize')
    $coverage.Foreground = [System.Windows.Media.Brushes]::LightGray
    $sync.WPFScanResults.Children.Add($coverage) | Out-Null

    $lastCategory = $null
    foreach ($result in @($Snapshot.Results | Sort-Object Category, Name)) {
        if ($result.Category -ne $lastCategory) {
            $lastCategory = $result.Category
            $categoryLabel = New-Object System.Windows.Controls.TextBlock
            $categoryLabel.Text = ($lastCategory -replace '^z__', '')
            $categoryLabel.SetResourceReference([System.Windows.Controls.TextBlock]::FontSizeProperty, 'HeaderFontSize')
            $categoryLabel.FontWeight = 'SemiBold'
            $categoryLabel.Margin = '0,15,0,8'
            $categoryLabel.Foreground = [System.Windows.Media.Brushes]::White
            $sync.WPFScanResults.Children.Add($categoryLabel) | Out-Null
        }

        $grid = New-Object System.Windows.Controls.Grid
        $grid.Margin = '0,0,0,10'
        foreach ($weight in @(2, 2, 2)) {
            $column = New-Object System.Windows.Controls.ColumnDefinition
            $column.Width = [System.Windows.GridLength]::new($weight, [System.Windows.GridUnitType]::Star)
            $grid.ColumnDefinitions.Add($column)
        }

        $namePanel = New-Object System.Windows.Controls.StackPanel
        $name = New-Object System.Windows.Controls.TextBlock
        $name.Text = [string]$result.Name
        $name.TextWrapping = 'Wrap'
        $name.SetResourceReference([System.Windows.Controls.TextBlock]::FontSizeProperty, 'FontSize')
        $name.Foreground = [System.Windows.Media.Brushes]::White
        $namePanel.Children.Add($name) | Out-Null
        if ($result.Reason) {
            $reason = New-Object System.Windows.Controls.TextBlock
            $reason.Text = [string]$result.Reason
            $reason.TextWrapping = 'Wrap'
            $reason.SetResourceReference([System.Windows.Controls.TextBlock]::FontSizeProperty, 'FontSize')
            $reason.Foreground = [System.Windows.Media.Brushes]::LightGray
            $namePanel.Children.Add($reason) | Out-Null
        }
        [System.Windows.Controls.Grid]::SetColumn($namePanel, 0)
        $grid.Children.Add($namePanel) | Out-Null

        $currentPanel = New-Object System.Windows.Controls.StackPanel
        $currentPanel.Margin = '10,0,10,0'
        $current = New-Object System.Windows.Controls.TextBlock
        $current.Text = "Current: $($result.State)"
        $current.TextWrapping = 'Wrap'
        $current.SetResourceReference([System.Windows.Controls.TextBlock]::FontSizeProperty, 'FontSize')
        $current.Foreground = [System.Windows.Media.Brushes]::White
        $currentPanel.Children.Add($current) | Out-Null
        if ($result.ActiveDownloadMode) {
            $activeMode = New-Object System.Windows.Controls.TextBlock
            $activeMode.Text = "Active download mode: $($result.ActiveDownloadMode)"
            $activeMode.TextWrapping = 'Wrap'
            $activeMode.SetResourceReference([System.Windows.Controls.TextBlock]::FontSizeProperty, 'FontSize')
            $activeMode.Foreground = [System.Windows.Media.Brushes]::LightGray
            $currentPanel.Children.Add($activeMode) | Out-Null
        }
        foreach ($entry in @($result.Observation.Observations | Where-Object { $null -ne $_ })) {
            $detail = New-Object System.Windows.Controls.TextBlock
            $actual = if ($entry.Status -eq 'Not set') { 'not set' } elseif ($entry.Status -eq 'Unreadable') { 'unreadable' } else { [string]$entry.Actual }
            $detail.Text = "$($entry.Name): $actual (expected: $($entry.Expected))"
            $detail.TextWrapping = 'Wrap'
            $detail.SetResourceReference([System.Windows.Controls.TextBlock]::FontSizeProperty, 'FontSize')
            $detail.Foreground = [System.Windows.Media.Brushes]::LightGray
            $currentPanel.Children.Add($detail) | Out-Null
        }
        [System.Windows.Controls.Grid]::SetColumn($currentPanel, 1)
        $grid.Children.Add($currentPanel) | Out-Null

        $recommended = New-Object System.Windows.Controls.TextBlock
        $recommended.Text = "Suggested: $($result.Recommendation)"
        $recommended.TextWrapping = 'Wrap'
        $recommended.SetResourceReference([System.Windows.Controls.TextBlock]::FontSizeProperty, 'FontSize')
        $recommended.Margin = '10,0,10,0'
        $recommended.Foreground = [System.Windows.Media.Brushes]::White
        [System.Windows.Controls.Grid]::SetColumn($recommended, 2)
        $grid.Children.Add($recommended) | Out-Null

        $sync.WPFScanResults.Children.Add($grid) | Out-Null
    }
    $sync.WPFScanResults.Visibility = 'Visible'
}
