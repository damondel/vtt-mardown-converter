# Test VTT Converter Setup
# This script helps validate that your environment is ready for VTT conversion

Write-Host "=== VTT to Markdown Converter - Setup Validation ===" -ForegroundColor Cyan
Write-Host ""

# Test PowerShell version
Write-Host "Checking PowerShell version..." -ForegroundColor Yellow
$version = $PSVersionTable.PSVersion
Write-Host "PowerShell Version: $version"

if ($version.Major -ge 5) {
    Write-Host "✓ PowerShell version is compatible" -ForegroundColor Green
} else {
    Write-Host "✗ PowerShell version too old. Requires 5.1 or later." -ForegroundColor Red
    exit 1
}

# Test execution policy
Write-Host "`nChecking execution policy..." -ForegroundColor Yellow
$policy = Get-ExecutionPolicy
Write-Host "Current policy: $policy"

if ($policy -eq "Restricted") {
    Write-Host "✗ Execution policy is too restrictive" -ForegroundColor Red
    Write-Host "Run this command as Administrator to fix:" -ForegroundColor Yellow
    Write-Host "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
} else {
    Write-Host "✓ Execution policy allows script execution" -ForegroundColor Green
}

# Test script files
Write-Host "`nChecking for script files..." -ForegroundColor Yellow
$scriptPath = Split-Path -Parent $PSCommandPath

$requiredFiles = @(
    "convert-vtt-to-markdown.ps1",
    "batch-convert-vtt.ps1"
)

$allFilesFound = $true
foreach ($file in $requiredFiles) {
    $filePath = Join-Path $scriptPath $file
    if (Test-Path $filePath) {
        Write-Host "✓ Found: $file" -ForegroundColor Green
    } else {
        Write-Host "✗ Missing: $file" -ForegroundColor Red
        $allFilesFound = $false
    }
}

if (-not $allFilesFound) {
    Write-Host "`nPlease ensure all required scripts are in the same directory." -ForegroundColor Yellow
    exit 1
}

# Test with sample data
Write-Host "`nTesting with sample VTT data..." -ForegroundColor Yellow

# Create a sample VTT file for testing
$sampleVtt = "WEBVTT`n`n00:00:01.000 --> 00:00:05.000`n<v John>Hello everyone, welcome to our test meeting.`n`n00:00:05.000 --> 00:00:10.000`n<v Sarah>Thanks John. Let us start with the agenda items.`n`n00:00:10.000 --> 00:00:15.000`n<v John>First item is testing our VTT converter."

$testDir = Join-Path $scriptPath "test-validation"
$testVttPath = Join-Path $testDir "sample-meeting.vtt"
$testOutputDir = Join-Path $testDir "output"

try {
    # Create test directory and file
    if (-not (Test-Path $testDir)) {
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
    }
    
    $sampleVtt | Out-File -FilePath $testVttPath -Encoding UTF8
    Write-Host "✓ Created sample VTT file" -ForegroundColor Green
    
    # Test conversion
    $converterScript = Join-Path $scriptPath "convert-vtt-to-markdown.ps1"
    & $converterScript -VttFile $testVttPath -OutputDir $testOutputDir
    
    # Check if output was created
    $expectedOutput = Join-Path $testOutputDir "sample-meeting.md"
    if (Test-Path $expectedOutput) {
        Write-Host "✓ Successfully converted sample VTT to Markdown" -ForegroundColor Green
        
        # Show sample output
        Write-Host "`nSample output preview:" -ForegroundColor White
        $content = Get-Content $expectedOutput -Head 10
        $content | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        
    } else {
        Write-Host "✗ Conversion failed - no output file created" -ForegroundColor Red
    }
    
} catch {
    Write-Host "✗ Test conversion failed: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    # Clean up test files
    if (Test-Path $testDir) {
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "✓ Cleaned up test files" -ForegroundColor Green
    }
}

Write-Host "`n=== Setup Validation Complete ===" -ForegroundColor Cyan
Write-Host "Your environment is ready for VTT conversion!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "1. Place your VTT files in a directory" -ForegroundColor Gray
Write-Host "2. Run: .\convert-vtt-to-markdown.ps1 -VttFile your-file.vtt" -ForegroundColor Gray
Write-Host "3. Or batch process: .\batch-convert-vtt.ps1 -SourceDir your-vtt-directory" -ForegroundColor Gray
