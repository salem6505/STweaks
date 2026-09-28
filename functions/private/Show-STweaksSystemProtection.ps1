function Show-STweaksSystemProtection {
    # Opens Windows' native System Protection tab; it does not create a point.
    try {
        Start-Process -FilePath 'SystemPropertiesProtection.exe' -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        Show-WinUtilMessage -Title 'STweaks' -Message "Could not open Windows System Protection: $($_.Exception.Message)" -Icon 'Warning' | Out-Null
        return $false
    }
}
