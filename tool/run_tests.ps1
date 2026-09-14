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

Push-Location $projectRoot
try {
    Remove-DartTestArtifacts -IncludeProjectCache $true
    & dart test @args
    $testExitCode = $LASTEXITCODE
}
finally {
    # Dart's test process can finish while a compiler worker is still closing
    # its incremental cache on Windows. Leave that small project-local cache
    # for the next pre-run cleanup and immediately remove the large temp data.
    Remove-DartTestArtifacts
    Pop-Location
}

exit $testExitCode
