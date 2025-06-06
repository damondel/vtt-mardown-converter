# Batch VTT to Markdown Converter
# documentId: script-batch-convert-vtt-content-processing
# Usage: .\batch-convert-vtt.ps1 [-SourceDir "path\to\vtt\files"] [-OutputDir "path\to\output"] [-Filter "*.vtt"] [-AnonymizeNames] [-UseParticipantIDs]

param(
    [Parameter(Mandatory=$false, HelpMessage="Directory containing VTT files")]
    [string]$SourceDir,
    
    [Parameter(Mandatory=$false, HelpMessage="Output directory for markdown files")]
    [string]$OutputDir,
    
    [Parameter(Mandatory=$false, HelpMessage="File filter pattern")]
    [string]$Filter = "*.vtt",
    
    [Parameter(Mandatory=$false, HelpMessage="Process subdirectories recursively")]
    [switch]$Recursive,
    
    [Parameter(Mandatory=$false, HelpMessage="Anonymize speaker names (replace with initials/IDs)")]
    [switch]$AnonymizeNames,
    
    [Parameter(Mandatory=$false, HelpMessage="Use simple participant IDs (P1, P2, etc.) instead of initials")]
    [switch]$UseParticipantIDs
)

# Get script directory
$scriptPath = Split-Path -Parent $PSCommandPath
$converterScript = Join-Path $scriptPath "convert-vtt-to-markdown.ps1"

# Check if the converter script exists
if (-not (Test-Path $converterScript)) {
    Write-Error "Converter script not found: $converterScript"
    Write-Host "Please ensure convert-vtt-to-markdown.ps1 is in the same directory."
    exit 1
}

# Set default source directory
if (-not $SourceDir) {
    $scriptRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $SourceDir = Join-Path $scriptRoot "data\transcripts"
}

# Set default output directory
if (-not $OutputDir) {
    $scriptRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $OutputDir = Join-Path $scriptRoot "data\markdown-output"
}

# Validate source directory
if (-not (Test-Path $SourceDir)) {
    Write-Error "Source directory not found: $SourceDir"
    exit 1
}

Write-Host "=== Batch VTT to Markdown Converter ===" -ForegroundColor Cyan
Write-Host "Source Directory: $SourceDir"
Write-Host "Output Directory: $OutputDir"
Write-Host "Filter: $Filter"
Write-Host "Recursive: $Recursive"
if ($AnonymizeNames) {
    Write-Host "Anonymization: Enabled" -ForegroundColor Yellow
    if ($UseParticipantIDs) {
        Write-Host "Format: Participant IDs (P1, P2, etc.)" -ForegroundColor Yellow
    } else {
        Write-Host "Format: Initials" -ForegroundColor Yellow
    }
} else {
    Write-Host "Anonymization: Disabled"
}
Write-Host "=======================================`n" -ForegroundColor Cyan

# Find VTT files
$searchParams = @{
    Path = $SourceDir
    Filter = $Filter
}

if ($Recursive) {
    $searchParams.Recurse = $true
}

$vttFiles = Get-ChildItem @searchParams | Where-Object { -not $_.PSIsContainer }

if ($vttFiles.Count -eq 0) {
    Write-Warning "No VTT files found in $SourceDir with filter $Filter"
    exit 0
}

Write-Host "Found $($vttFiles.Count) VTT file(s) to process:`n"

# Process each file
$successCount = 0
$errorCount = 0
$results = @()

foreach ($vttFile in $vttFiles) {
    Write-Host "Processing: $($vttFile.Name)" -ForegroundColor Yellow
    
    try {
        # Create subdirectory structure in output if processing recursively
        $relativePath = $vttFile.DirectoryName.Substring($SourceDir.Length).TrimStart('\', '/')
        $targetDir = if ($relativePath) { Join-Path $OutputDir $relativePath } else { $OutputDir }
        
        # Run the converter
        $converterParams = @{
            VttFile = $vttFile.FullName
            OutputDir = $targetDir
        }
        
        if ($AnonymizeNames) {
            $converterParams.AnonymizeNames = $true
        }
        
        if ($UseParticipantIDs) {
            $converterParams.UseParticipantIDs = $true
        }
        
        $result = & $converterScript @converterParams
        
        if ($LASTEXITCODE -eq 0) {
            $successCount++
            $status = "SUCCESS"
            Write-Host "  ✓ Converted successfully" -ForegroundColor Green
        } else {
            $errorCount++
            $status = "ERROR"
            Write-Host "  ✗ Conversion failed" -ForegroundColor Red
        }
        
        $results += [PSCustomObject]@{
            File = $vttFile.Name
            Path = $vttFile.FullName
            Status = $status
            OutputDir = $targetDir
        }
        
    } catch {
        $errorCount++
        $status = "ERROR"
        Write-Host "  ✗ Exception: $($_.Exception.Message)" -ForegroundColor Red
        
        $results += [PSCustomObject]@{
            File = $vttFile.Name
            Path = $vttFile.FullName
            Status = $status
            Error = $_.Exception.Message
        }
    }
    
    Write-Host ""
}

# Summary report
Write-Host "=== Batch Conversion Summary ===" -ForegroundColor Cyan
Write-Host "Total files processed: $($vttFiles.Count)"
Write-Host "Successful conversions: $successCount" -ForegroundColor Green
Write-Host "Failed conversions: $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { "Red" } else { "Green" })
Write-Host "================================`n" -ForegroundColor Cyan

# Detailed results table
if ($results.Count -gt 0) {
    Write-Host "Detailed Results:" -ForegroundColor White
    $results | Format-Table -Property File, Status, OutputDir -AutoSize
}

# List any errors
$errors = $results | Where-Object { $_.Status -eq "ERROR" }
if ($errors.Count -gt 0) {
    Write-Host "Files with errors:" -ForegroundColor Red
    foreach ($error in $errors) {
        Write-Host "  - $($error.File): $($error.Error)" -ForegroundColor Red
    }
}

Write-Host "Batch conversion completed." -ForegroundColor Cyan
