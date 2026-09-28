# Running STweaks from PowerShell

STweaks is distributed as a single PowerShell script. Opening it from an elevated
Windows PowerShell session starts its WPF interface; there is no desktop installer.
The script still creates its normal diagnostic logs in the user's local app data.

## Publish a preview

1. Push this repository's **STweaks branch**, including
   `.github/workflows/stweaks-preview.yaml`, to the default branch of a public
   GitHub repository that you control. Do not use the upstream WinUtil release.
2. In that repository's **Actions** tab, run **STweaks PowerShell preview**.
   GitHub Actions must have permission to write repository contents so it can
   create the preview release.
3. Check that the workflow succeeded. Copy the `PowerShell URL:` shown in the
   **Publish a versioned preview script** step. This URL points to the compiled
   `winutil.ps1` release asset, not to the upstream project.

Run this in **Windows PowerShell as Administrator**, substituting the URL from
your successful build:

```powershell
$url = 'PASTE_THE_POWERSHELL_URL_HERE'
$bytes = (New-Object Net.WebClient).DownloadData($url)
& ([scriptblock]::Create([Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF)))
```

`DownloadData` holds the script in memory and does not install it or save it
to the desktop. The WPF interface opens in its own window. This is a preview:
the workflow checks compilation and PowerShell syntax, while visual behavior
still requires testing on Windows 10 and Windows 11.
