# Final Batch VTT to Markdown Converter
# Usage: .\batch-convert-vtt-final.ps1 [-SourceDir "path"] [-OutputDir "path"] [-Recursive] [-NoAnonymization]

param(
    [string]$SourceDir = "c:\Users\damondel\dev\data\transcripts",
    [string]$OutputDir = "c:\Users\damondel\dev\data\markdown-output",
    [switch]$Recursive,
    [switch]$NoAnonymization
)

Write-Host "=== Batch VTT to Markdown Converter ===" -ForegroundColor Cyan
Write-Host "Source: $SourceDir" -ForegroundColor White
Write-Host "Output: $OutputDir" -ForegroundColor White
Write-Host "Recursive: $Recursive" -ForegroundColor White

if ($NoAnonymization) {
    Write-Host "Anonymization: Disabled (showing real names)" -ForegroundColor Yellow
} else {
    Write-Host "Anonymization: Enabled (using participant IDs P1, P2, etc.)" -ForegroundColor Green
}

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Get converter script path
$converterScript = Join-Path $PSScriptRoot "convert-vtt-to-markdown.ps1"

# Validate paths
if (-not (Test-Path $converterScript)) {
    Write-Host "ERROR: Converter script not found: $converterScript" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $SourceDir)) {
    Write-Host "ERROR: Source directory not found: $SourceDir" -ForegroundColor Red
    exit 1
}

# Ensure output directory exists
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Host "Created output directory: $OutputDir" -ForegroundColor Gray
}

# Find VTT files
Write-Host "Searching for VTT files..." -ForegroundColor White
if ($Recursive) {
    $vttFiles = Get-ChildItem -Path $SourceDir -Filter "*.vtt" -Recurse
} else {
    $vttFiles = Get-ChildItem -Path $SourceDir -Filter "*.vtt"
}

if ($vttFiles.Count -eq 0) {
    Write-Host "No VTT files found in: $SourceDir" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($vttFiles.Count) VTT file(s):" -ForegroundColor White
$vttFiles | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Gray }
Write-Host ""

# Process each file using the simple approach that we know works
$success = 0
$failed = 0

foreach ($vttFile in $vttFiles) {
    Write-Host "Processing: $($vttFile.Name)" -ForegroundColor Yellow
    
    try {
        # Use the working PowerShell approach
        if ($NoAnonymization) {
            & $converterScript -VttFile $vttFile.FullName -OutputDir $OutputDir -NoAnonymization
        } else {
            & $converterScript -VttFile $vttFile.FullName -OutputDir $OutputDir
        }
        
        # Check if output file was created
        $expectedOutput = Join-Path $OutputDir "$($vttFile.BaseName).md"
        if (Test-Path $expectedOutput) {
            $fileInfo = Get-Item $expectedOutput
            Write-Host "  SUCCESS: Created $($fileInfo.Name) ($($fileInfo.Length) bytes)" -ForegroundColor Green
            $success++
        } else {
            Write-Host "  FAILED: No output file created" -ForegroundColor Red
            $failed++
        }
        
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $failed++
    }
    
    Write-Host ""
}

# Summary
Write-Host "=== Batch Conversion Summary ===" -ForegroundColor Cyan
Write-Host "Total files found: $($vttFiles.Count)" -ForegroundColor White
Write-Host "Successfully converted: $success" -ForegroundColor Green
Write-Host "Failed conversions: $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })
Write-Host "================================" -ForegroundColor Cyan

if ($failed -eq 0) {
    Write-Host "All conversions completed successfully!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Some conversions failed. Check the output above for details." -ForegroundColor Yellow
    exit 1
}
