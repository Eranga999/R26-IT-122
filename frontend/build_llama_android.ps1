# Build llama.cpp native libraries for Android (ARM64)
# Run this from the frontend/ directory

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Building llama.cpp for Android" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# --- Configuration ---
$repoUrl = "https://github.com/ggml-org/llama.cpp.git"
$repoDir = "$PSScriptRoot/llama.cpp"
$jniLibsDir = "$PSScriptRoot/android/app/src/main/jniLibs/arm64-v8a"

# Find NDK path (adjust if needed)
$ndkPath = $env:ANDROID_NDK
if (-not $ndkPath) {
    # Try common locations
    $ndkCandidates = @(
        "$env:LOCALAPPDATA\Android\Sdk\ndk\28.2.13676358",
        "$env:LOCALAPPDATA\Android\Sdk\ndk\29.0.13113456",
        "$env:LOCALAPPDATA\Android\Sdk\ndk\27.2.12479018",
        "$env:LOCALAPPDATA\Android\Sdk\ndk\26.3.11579264",
        "C:\Program Files\Android\Sdk\ndk\28.2.13676358",
        "C:\Android\Sdk\ndk\28.2.13676358"
    )
    foreach ($candidate in $ndkCandidates) {
        if (Test-Path $candidate) {
            $ndkPath = $candidate
            break
        }
    }
}

if (-not $ndkPath -or -not (Test-Path $ndkPath)) {
    Write-Host "ERROR: Android NDK not found!" -ForegroundColor Red
    Write-Host "Please set ANDROID_NDK environment variable, or update this script."
    Write-Host "Expected at: $env:LOCALAPPDATA\Android\Sdk\ndk\<version>"
    exit 1
}

Write-Host "NDK found: $ndkPath" -ForegroundColor Green

# Check CMake (in PATH, Android SDK, or NDK bundled)
$cmake = Get-Command cmake -ErrorAction SilentlyContinue
if (-not $cmake) {
    # Search in Android SDK cmake directories
    $cmakeCandidates = @(
        "$env:LOCALAPPDATA\Android\Sdk\cmake\3.22.1\bin\cmake.exe",
        "$env:LOCALAPPDATA\Android\Sdk\cmake\3.18.1\bin\cmake.exe",
        "$env:LOCALAPPDATA\Android\Sdk\cmake\3.16.9\bin\cmake.exe",
        "$env:LOCALAPPDATA\Android\Sdk\cmake\3.10.2\bin\cmake.exe",
        "$ndkPath\prebuilt\windows-x86_64\bin\cmake.exe",
        "C:\Program Files\CMake\bin\cmake.exe",
        "C:\CMake\bin\cmake.exe"
    )
    foreach ($candidate in $cmakeCandidates) {
        if (Test-Path $candidate) {
            $cmake = Get-Command $candidate
            break
        }
    }
}

if (-not $cmake) {
    Write-Host "ERROR: CMake not found!" -ForegroundColor Red
    Write-Host "CMake is installed but not in your system PATH." -ForegroundColor Yellow
    Write-Host "Add this to your PATH environment variable:" -ForegroundColor Yellow
    Write-Host "  $env:LOCALAPPDATA\Android\Sdk\cmake\3.22.1\bin" -ForegroundColor White
    Write-Host "`nOr run this command to temporarily add it:" -ForegroundColor Yellow
    Write-Host "  `$env:PATH += `";$env:LOCALAPPDATA\Android\Sdk\cmake\3.22.1\bin`"" -ForegroundColor White
    exit 1
}

Write-Host "CMake found: $($cmake.Source)" -ForegroundColor Green

# Look for Ninja (preferred generator for Android builds)
$ninja = Get-Command ninja -ErrorAction SilentlyContinue
if (-not $ninja) {
    $ninjaCandidates = @(
        "$env:LOCALAPPDATA\Android\Sdk\cmake\3.22.1\bin\ninja.exe",
        "$env:LOCALAPPDATA\Android\Sdk\cmake\3.18.1\bin\ninja.exe",
        "$ndkPath\prebuilt\windows-x86_64\bin\ninja.exe"
    )
    foreach ($candidate in $ninjaCandidates) {
        if (Test-Path $candidate) {
            $ninja = Get-Command $candidate
            break
        }
    }
}

if ($ninja) {
    Write-Host "Ninja found: $($ninja.Source)" -ForegroundColor Green
    $cmakeGenerator = 'Ninja'
} else {
    Write-Host "Ninja not found, using Unix Makefiles" -ForegroundColor Yellow
    $cmakeGenerator = 'Unix Makefiles'
}

# --- Clone llama.cpp ---
if (-not (Test-Path "$repoDir/.git")) {
    Write-Host "`nCloning llama.cpp repository..." -ForegroundColor Yellow
    git clone --depth 1 $repoUrl $repoDir
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to clone repository" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "`nllama.cpp already cloned. Pulling latest changes..." -ForegroundColor Yellow
    Push-Location $repoDir
    git pull
    Pop-Location
}

# --- Create output directory ---
New-Item -ItemType Directory -Force -Path $jniLibsDir | Out-Null

# --- Build with CMake ---
$buildDir = "$repoDir/build-android"
# Remove old build directory to avoid cached generator issues
if (Test-Path $buildDir) {
    Write-Host "Removing old build directory..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $buildDir
}
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

Write-Host "`nConfiguring CMake for Android ARM64 (generator: $cmakeGenerator)..." -ForegroundColor Yellow
Push-Location $buildDir

try {
    # Run CMake configuration
    # Key flags:
    # - BUILD_SHARED_LIBS=ON: Build as shared libraries (.so)
    # - LLAMA_BUILD_TESTS=OFF: Skip tests
    # - LLAMA_BUILD_EXAMPLES=OFF: Skip examples
    # - GGML_NATIVE=OFF: Don't optimize for host CPU (we're cross-compiling)
    $cmakeArgs = @(
        "-G", "$cmakeGenerator"
        "-DCMAKE_TOOLCHAIN_FILE=$ndkPath/build/cmake/android.toolchain.cmake"
        "-DANDROID_ABI=arm64-v8a"
        "-DANDROID_PLATFORM=android-26"
        "-DCMAKE_BUILD_TYPE=Release"
        "-DBUILD_SHARED_LIBS=ON"
        "-DLLAMA_BUILD_TESTS=OFF"
        "-DLLAMA_BUILD_EXAMPLES=OFF"
        "-DLLAMA_BUILD_SERVER=OFF"
        "-DLLAMA_BUILD_WEBUI=OFF"
        "-DGGML_NATIVE=OFF"
        "-DGGML_AVX=OFF"
        "-DGGML_AVX2=OFF"
        "-DGGML_FMA=OFF"
        "-DGGML_F16C=OFF"
        "-DGGML_OPENMP=OFF"
    )

    # If using Ninja, explicitly tell CMake where ninja.exe is
    if ($ninja) {
        $cmakeArgs += "-DCMAKE_MAKE_PROGRAM=$($ninja.Source)"
    }

    $cmakeArgs += ".."

    & $cmake.Source @cmakeArgs

    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: CMake configuration failed" -ForegroundColor Red
        exit 1
    }

    Write-Host "`nBuilding libraries (this may take 10-30 minutes)..." -ForegroundColor Yellow
    $cores = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
    & $cmake.Source --build . --config Release --parallel $cores

    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Build failed" -ForegroundColor Red
        exit 1
    }

    # --- Copy libraries ---
    Write-Host "`nCopying libraries to jniLibs..." -ForegroundColor Yellow

    $libsToCopy = @(
        "libllama.so",
        "libmtmd.so",
        "libggml.so",
        "libggml-base.so",
        "libggml-cpu.so"
    )

    $copiedCount = 0
    foreach ($lib in $libsToCopy) {
        # Search in common output locations
        $foundPaths = @(
            "$buildDir/bin/$lib",
            "$buildDir/$lib",
            "$buildDir/ggml/src/$lib",
            "$buildDir/src/$lib",
            "$buildDir/ggml/src/ggml-cpu/$lib"
        )
        
        $found = $false
        foreach ($path in $foundPaths) {
            if (Test-Path $path) {
                Copy-Item $path "$jniLibsDir/$lib" -Force
                Write-Host "  Copied: $lib" -ForegroundColor Green
                $found = $true
                $copiedCount++
                break
            }
        }
        
        if (-not $found) {
            Write-Host "  Not found: $lib (may not be built for this config)" -ForegroundColor Yellow
        }
    }

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  Build Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Copied $copiedCount libraries to:" -ForegroundColor Green
    Write-Host "  $jniLibsDir" -ForegroundColor White
    Write-Host "`nNext steps:" -ForegroundColor Yellow
    Write-Host "  1. Run: flutter clean" -ForegroundColor White
    Write-Host "  2. Run: flutter pub get" -ForegroundColor White
    Write-Host "  3. Run: flutter run" -ForegroundColor White

} finally {
    Pop-Location
}
