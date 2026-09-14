$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$testCache = [System.IO.Path]::GetFullPath((Join-Path $projectRoot '.dart_tool\test'))
$tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())

function Remove-DartTestArtifacts {
    $removedBytes = [long] 0

    if (Test-Path -LiteralPath $testCache) {
        if (-not $testCache.StartsWith($projectRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to clean unexpected test cache: $testCache"
        }
        Get-ChildItem -LiteralPath $testCache -Recurse -File -Force -ErrorAction SilentlyContinue |
            ForEach-Object { $removedBytes += $_.Length }
        Remove-Item -LiteralPath $testCache -Recurse -Force
    }

    Get-ChildItem -LiteralPath $tempRoot -Directory -Filter 'dart_test.kernel.*' -Force -ErrorAction SilentlyContinue |
        ForEach-Object {
            $target = [System.IO.Path]::GetFullPath($_.FullName)
            $validParent = [System.IO.Path]::GetDirectoryName($target) -eq $tempRoot.TrimEnd('\')
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
    Remove-DartTestArtifacts
    & dart test @args
    $testExitCode = $LASTEXITCODE
}
finally {
    Remove-DartTestArtifacts
    Pop-Location
}

exit $testExitCode
