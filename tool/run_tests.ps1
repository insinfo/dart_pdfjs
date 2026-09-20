$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$dartToolRoot = Join-Path $projectRoot '.dart_tool'
$testCache = [System.IO.Path]::GetFullPath((Join-Path $dartToolRoot 'test'))
$tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$pathSeparators = [char[]]@(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
)
$normalizedTempRoot = $tempRoot.TrimEnd($pathSeparators)
$projectPrefix = $projectRoot.TrimEnd($pathSeparators) + [System.IO.Path]::DirectorySeparatorChar
$defaultTimeoutMinutes = 15

function Remove-ArtifactDirectory {
    param(
        [Parameter(Mandatory = $true)][string] $LiteralPath,
        [int] $MaxAttempts = 12
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        if (-not (Test-Path -LiteralPath $LiteralPath)) {
            return $true
        }
        try {
            Remove-Item -LiteralPath $LiteralPath -Recurse -Force -ErrorAction Stop
            return $true
        }
        catch [System.IO.IOException] {
            if ($attempt -lt $MaxAttempts) {
                Start-Sleep -Milliseconds ([math]::Min(100 * $attempt, 750))
                continue
            }
        }
        catch [System.UnauthorizedAccessException] {
            if ($attempt -lt $MaxAttempts) {
                Start-Sleep -Milliseconds ([math]::Min(100 * $attempt, 750))
                continue
            }
        }
    }

    Write-Warning "Deferred cleanup of locked Dart test artifact: $LiteralPath"
    return $false
}

function Remove-DartTestArtifacts {
    param([bool] $IncludeProjectCache = $false)

    $removedBytes = [long] 0

    if ($IncludeProjectCache -and (Test-Path -LiteralPath $testCache)) {
        if (-not $testCache.StartsWith($projectPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to clean unexpected test cache: $testCache"
        }
        Get-ChildItem -LiteralPath $testCache -Recurse -File -Force -ErrorAction SilentlyContinue |
            ForEach-Object { $removedBytes += $_.Length }
        [void](Remove-ArtifactDirectory -LiteralPath $testCache)
    }

    Get-ChildItem -LiteralPath $tempRoot -Directory -Filter 'dart_test.kernel.*' -Force -ErrorAction SilentlyContinue |
        ForEach-Object {
            $target = [System.IO.Path]::GetFullPath($_.FullName)
            $validParent = [System.IO.Path]::GetDirectoryName($target) -eq $normalizedTempRoot
            $validName = [System.IO.Path]::GetFileName($target).StartsWith('dart_test.kernel.')
            if (-not ($validParent -and $validName)) {
                throw "Refusing to clean unexpected temporary path: $target"
            }
            Get-ChildItem -LiteralPath $target -Recurse -File -Force -ErrorAction SilentlyContinue |
                ForEach-Object { $removedBytes += $_.Length }
            [void](Remove-ArtifactDirectory -LiteralPath $target)
        }

    if ($removedBytes -gt 0) {
        $removedMiB = [math]::Round($removedBytes / 1MB, 1)
        Write-Host "Cleaned $removedMiB MiB of Dart test artifacts."
    }
}

function Get-TestProcessTree {
    param(
        [Parameter(Mandatory = $true)][int] $RootProcessId,
        [Parameter(Mandatory = $true)][datetime] $StartedAt
    )

    if (-not $IsWindows) {
        # CI jobs run in disposable Linux processes; Win32_Process is used
        # only where local browser leaks are persistent across test runs.
        return @()
    }

    # Take one consistent process snapshot. Descendants retain their original
    # parent PID on Windows even when dart has already exited, which lets us
    # find browser/compiler processes orphaned during runner shutdown.
    $processes = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)
    if ($processes.Count -eq 0) {
        return @()
    }

    $minimumCreationTime = $StartedAt.AddSeconds(-2)
    $pending = [System.Collections.Generic.Queue[int]]::new()
    $seen = [System.Collections.Generic.HashSet[int]]::new()
    $result = [System.Collections.Generic.List[object]]::new()
    $pending.Enqueue($RootProcessId)

    while ($pending.Count -gt 0) {
        $parentId = $pending.Dequeue()
        if (-not $seen.Add($parentId)) {
            continue
        }

        foreach ($process in $processes) {
            if ([int]$process.ParentProcessId -ne $parentId) {
                continue
            }
            if ($process.CreationDate -lt $minimumCreationTime) {
                continue
            }
            $result.Add($process)
            $pending.Enqueue([int]$process.ProcessId)
        }
    }

    return @($result)
}

function Stop-TestProcessTree {
    param(
        [Parameter(Mandatory = $true)][int] $RootProcessId,
        [Parameter(Mandatory = $true)][datetime] $StartedAt,
        [switch] $IncludeRoot
    )

    $descendants = @(Get-TestProcessTree -RootProcessId $RootProcessId -StartedAt $StartedAt)
    # Stop leaves before their parents so browser crash handlers and compiler
    # workers cannot recreate children while cleanup is in progress.
    [array]::Reverse($descendants)
    foreach ($process in $descendants) {
        Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
    }

    if ($IncludeRoot) {
        $root = Get-Process -Id $RootProcessId -ErrorAction SilentlyContinue
        if ($null -ne $root -and $root.StartTime -ge $StartedAt.AddSeconds(-2)) {
            Stop-Process -Id $RootProcessId -Force -ErrorAction SilentlyContinue
        }
    }

    if ($descendants.Count -gt 0) {
        Write-Host "Stopped $($descendants.Count) leftover test process(es)."
    }
}

function Invoke-DartTests {
    param([Parameter(Mandatory = $true)][object[]] $TestArguments)

    $timeoutMinutes = $defaultTimeoutMinutes
    if (-not [string]::IsNullOrWhiteSpace($env:PDFJS_TEST_TIMEOUT_MINUTES)) {
        $parsedTimeout = 0
        if (
            -not [int]::TryParse($env:PDFJS_TEST_TIMEOUT_MINUTES, [ref]$parsedTimeout) -or
            $parsedTimeout -le 0 -or
            $parsedTimeout -gt 1440
        ) {
            throw 'PDFJS_TEST_TIMEOUT_MINUTES must be an integer from 1 to 1440.'
        }
        $timeoutMinutes = $parsedTimeout
    }

    $dartCommand = Get-Command dart -ErrorAction Stop
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $dartCommand.Source
    $startInfo.WorkingDirectory = $projectRoot
    $startInfo.UseShellExecute = $false
    foreach ($argument in @('test') + $TestArguments) {
        [void]$startInfo.ArgumentList.Add([string]$argument)
    }

    $runner = [System.Diagnostics.Process]::new()
    $runner.StartInfo = $startInfo
    $startedAt = Get-Date
    if (-not $runner.Start()) {
        throw 'Failed to start the Dart test runner.'
    }

    try {
        $timeoutMilliseconds = [int64]$timeoutMinutes * 60 * 1000
        if (-not $runner.WaitForExit($timeoutMilliseconds)) {
            Write-Warning "Dart tests exceeded the $timeoutMinutes minute limit."
            Stop-TestProcessTree -RootProcessId $runner.Id -StartedAt $startedAt -IncludeRoot
            return 124
        }
        return $runner.ExitCode
    }
    finally {
        Stop-TestProcessTree -RootProcessId $runner.Id -StartedAt $startedAt
        $runner.Dispose()
    }
}

Push-Location $projectRoot
try {
    Remove-DartTestArtifacts -IncludeProjectCache $true
    $testExitCode = Invoke-DartTests -TestArguments $args
}
finally {
    # Dart's test process can finish while a compiler worker is still closing
    # its incremental cache on Windows. Leave that small project-local cache
    # for the next pre-run cleanup and immediately remove the large temp data.
    Remove-DartTestArtifacts
    Pop-Location
}

exit $testExitCode
