function Get-STweaksWindowsUpdateState {
    <#
    .SYNOPSIS
        Reads Windows Update policy values without changing the system.
    #>
    $path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
    $result = [ordered]@{
        Path          = $path
        NoAutoUpdate  = $null
        AUOptions     = $null
        State         = 'Unknown'
        Reason        = $null
        Actionable    = $false
    }

    try {
        $product = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        if ([int]$product.ProductType -ne 1 -or [int]$product.BuildNumber -lt 10240) {
            $result.State = 'Unavailable'
            $result.Reason = 'This option requires a supported Windows 10 or Windows 11 client.'
            return [pscustomobject]$result
        }

        $edition = [string](Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name EditionID -ErrorAction Stop).EditionID
        if ($edition -notmatch '^(Professional|Enterprise|Education|IoTEnterprise)') {
            $result.State = 'Unavailable'
            $result.Reason = 'The behavior of this policy is not verified for this Windows edition.'
            return [pscustomobject]$result
        }

        # Domain/managed devices may reapply their own policy. Never overwrite it.
        $computer = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        if ($computer.PartOfDomain) {
            $result.State = 'Managed'
            $result.Reason = 'This device is domain managed; its update policy may be enforced centrally.'
            return [pscustomobject]$result
        }

        # MDM and update deadlines can supersede Configure Automatic Updates.
        $mdmPath = 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Update'
        if (Test-Path -LiteralPath $mdmPath -ErrorAction Stop) {
            $mdm = Get-Item -LiteralPath $mdmPath -ErrorAction Stop
            if (@('AllowAutoUpdate', 'ConfigureDeadlineForQualityUpdates', 'ConfigureDeadlineForFeatureUpdates') |
                Where-Object { $mdm.GetValueNames() -contains $_ }) {
                $result.State = 'Managed'
                $result.Reason = 'An update management policy may override this setting.'
                return [pscustomobject]$result
            }
        }

        $wuPolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
        if (Test-Path -LiteralPath $wuPolicyPath -ErrorAction Stop) {
            $wuPolicies = Get-Item -LiteralPath $wuPolicyPath -ErrorAction Stop
            if (@('WUServer', 'WUStatusServer', 'ComplianceDeadline', 'ComplianceDeadlineForFU') |
                Where-Object { $wuPolicies.GetValueNames() -contains $_ }) {
                $result.State = 'Managed'
                $result.Reason = 'An existing Windows Update server or deadline policy may override this setting.'
                return [pscustomobject]$result
            }
        }

        if (Test-Path -LiteralPath $path) {
            $key = Get-Item -LiteralPath $path -ErrorAction Stop
            if ($key.GetValueNames() -contains 'NoAutoUpdate') {
                $result.NoAutoUpdate = [int]$key.GetValue('NoAutoUpdate')
            }
            if ($key.GetValueNames() -contains 'AUOptions') {
                $result.AUOptions = [int]$key.GetValue('AUOptions')
            }
        }

        if ($result.NoAutoUpdate -eq 1) {
            $result.State = 'Automatic updates disabled by policy'
            $result.Reason = 'A separate policy disables automatic updates; STweaks will not override it.'
        }
        elseif ($result.AUOptions -eq 2) {
            $result.State = 'Notify before download'
        }
        elseif ($null -ne $result.AUOptions -or $null -ne $result.NoAutoUpdate) {
            $result.State = 'Managed or custom update policy'
            $result.Reason = 'An existing Windows Update policy is set; STweaks will not replace it.'
        }
        else {
            $result.State = 'No explicit automatic update policy'
            $result.Actionable = $true
        }
    }
    catch {
        $result.State = 'Unknown'
        $result.Reason = $_.Exception.Message
    }

    return [pscustomobject]$result
}
