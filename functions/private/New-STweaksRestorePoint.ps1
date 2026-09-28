function New-STweaksRestorePoint {
    <#
    .SYNOPSIS
        Creates and verifies a fresh restore point before a batch of changes.
    .DESCRIPTION
        Returns a result object. Never enables System Protection, changes its
        quota, suppresses the Windows creation limit, or accepts an older point.
    #>
    $result = [ordered]@{
        Succeeded      = $false
        Description    = $null
        SequenceNumber = $null
        CreatedAt      = $null
        Reason         = $null
    }

    try {
        if (-not (Get-Command Checkpoint-Computer -ErrorAction SilentlyContinue) -or
            -not (Get-Command Get-ComputerRestorePoint -ErrorAction SilentlyContinue)) {
            throw 'Windows System Restore commands are unavailable.'
        }

        $identifier = [guid]::NewGuid().ToString('N')
        $description = "STweaks before changes $identifier"
        $startedAt = Get-Date
        Checkpoint-Computer -Description $description -RestorePointType MODIFY_SETTINGS -ErrorAction Stop

        # Checkpoint-Computer has no success object. Confirm the unique point was
        # actually registered, instead of treating command completion as proof.
        $point = @(Get-ComputerRestorePoint -ErrorAction Stop | Where-Object {
            $_.Description -eq $description -and $_.SequenceNumber -ne $null
        } | Sort-Object SequenceNumber -Descending | Select-Object -First 1)
        if ($point.Count -ne 1) {
            throw 'Windows did not report the newly requested restore point.'
        }

        $result.Succeeded = $true
        $result.Description = $point[0].Description
        $result.SequenceNumber = [long]$point[0].SequenceNumber
        $result.CreatedAt = $startedAt
    }
    catch {
        $result.Reason = $_.Exception.Message
    }

    return [pscustomobject]$result
}
