param(
    [string]$PackageName = "com.example.smf_app",
    [string]$OutputPath = "lib/db/sleep_data_dev.db",
    [int]$IntervalSeconds = 3,
    [switch]$Watch
)

$ErrorActionPreference = "Stop"

function Get-ProjectRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Get-AndroidSdkPath {
    $localPropertiesPath = Join-Path (Get-ProjectRoot) "android/local.properties"
    if (Test-Path $localPropertiesPath) {
        $sdkLine = Get-Content $localPropertiesPath |
            Where-Object { $_ -match "^sdk\.dir=" } |
            Select-Object -First 1

        if ($sdkLine) {
            return ($sdkLine -replace "^sdk\.dir=", "").Replace("\\", "\")
        }
    }

    if ($env:ANDROID_HOME) { return $env:ANDROID_HOME }
    if ($env:ANDROID_SDK_ROOT) { return $env:ANDROID_SDK_ROOT }

    throw "Android SDK path was not found. Check android/local.properties or ANDROID_HOME."
}

function Get-AdbPath {
    $adbPath = Join-Path (Get-AndroidSdkPath) "platform-tools/adb.exe"
    if (!(Test-Path $adbPath)) {
        throw "adb.exe was not found at $adbPath"
    }
    return $adbPath
}

function Sync-SleepDatabase {
    $projectRoot = Get-ProjectRoot
    $resolvedOutputPath = Join-Path $projectRoot $OutputPath
    $outputDirectory = Split-Path $resolvedOutputPath -Parent

    if (!(Test-Path $outputDirectory)) {
        New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
    }

    $adbPath = Get-AdbPath
    $adbArgs = @(
        "exec-out",
        "run-as",
        $PackageName,
        "cat",
        "databases/sleep_data.db"
    )

    $process = Start-Process `
        -FilePath $adbPath `
        -ArgumentList $adbArgs `
        -RedirectStandardOutput $resolvedOutputPath `
        -NoNewWindow `
        -PassThru `
        -Wait

    if ($process.ExitCode -ne 0) {
        throw "Failed to export sleep_data.db. adb exit code: $($process.ExitCode)"
    }

    $file = Get-Item $resolvedOutputPath
    Write-Host ("[{0}] Synced {1} bytes -> {2}" -f (Get-Date -Format "HH:mm:ss"), $file.Length, $file.FullName)
}

if ($Watch) {
    Write-Host "Watching emulator sleep DB. Press Ctrl+C to stop."
    while ($true) {
        try {
            Sync-SleepDatabase
        } catch {
            Write-Warning $_
        }
        Start-Sleep -Seconds $IntervalSeconds
    }
}

Sync-SleepDatabase
