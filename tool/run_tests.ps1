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

function Remove-DartTestArtifacts {
    param([bool] $IncludeProjectCache = $false)

    $removedBytes = [long] 0

    if ($IncludeProjectCache -and (Test-Path -LiteralPath $testCache)) {
        if (-not $testCache.StartsWith($projectPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to clean unexpected test cache: $testCache"
        }
        Get-ChildItem -LiteralPath $testCache -Recurse -File -Force -ErrorAction SilentlyContinue |
            ForEach-Object { $removedBytes += $_.Length }
        Remove-Item -LiteralPath $testCache -Recurse -Force
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
            Remove-Item -LiteralPath $target -Recurse -Force
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
