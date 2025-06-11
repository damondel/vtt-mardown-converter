# Final Batch VTT to Markdown Converter
# Usage: .\batch-convert-vtt-final.ps1 [-SourceDir "path"] [-OutputDir "path"] [-Recursive] [-NoAnonymization] [-DocumentLinksTemplate "json"]

param(
    [string]$SourceDir = "c:\Users\damondel\dev\data\transcripts",
    [string]$OutputDir = "c:\Users\damondel\dev\data\markdown-output",
    [switch]$Recursive,
    [switch]$NoAnonymization,
    [string]$DocumentLinksTemplate = "",
    [switch]$EnableDocumentLinking,
    [string]$DocumentIdPrefix = "transcript",
    [string]$GlobalRelatedDocs = "",
    [string]$GlobalDocumentLinks = ""
)

Write-Host "=== Batch VTT to Markdown Converter ===" -ForegroundColor Cyan
Write-Host "Source: $SourceDir" -ForegroundColor White
Write-Host "Output: $OutputDir" -ForegroundColor White
Write-Host "Recursive: $Recursive" -ForegroundColor White

if ($NoAnonymization) {
    Write-Host "Anonymization: Disabled (showing real names)" -ForegroundColor Yellow
} else {
    Write-Host "Anonymization: Enabled (using initials: SM, DC, MJ, etc.)" -ForegroundColor Green
}

if ($EnableDocumentLinking) {
    Write-Host "Document Linking: Enabled" -ForegroundColor Green
    if ($DocumentIdPrefix) {
        Write-Host "  Document ID Prefix: $DocumentIdPrefix" -ForegroundColor Gray
    }
    if ($GlobalRelatedDocs) {
        Write-Host "  Global Related Docs: $GlobalRelatedDocs" -ForegroundColor Gray
    }
    if ($GlobalDocumentLinks) {
        Write-Host "  Global Document Links: $GlobalDocumentLinks" -ForegroundColor Gray
    }
} else {
    Write-Host "Document Linking: Disabled (basic conversion)" -ForegroundColor Gray
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

# Start batch processing timer
$batchStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# Process each file using optimized approach with memory management
$success = 0
$failed = 0
$fileIndex = 0

foreach ($vttFile in $vttFiles) {
    $fileIndex++
    $percentComplete = [math]::Round(($fileIndex / $vttFiles.Count) * 100, 1)
    
    Write-Host "[$fileIndex/$($vttFiles.Count)] ($percentComplete%) Processing: $($vttFile.Name)" -ForegroundColor Yellow
    
    # Show file size for performance monitoring
    $fileSizeMB = [math]::Round($vttFile.Length / 1MB, 2)
    if ($fileSizeMB -gt 0.1) {
        Write-Host "  File size: $fileSizeMB MB" -ForegroundColor Gray
    }
      try {
        # Use the working PowerShell approach with progress monitoring
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        # Build conversion parameters
        $conversionParams = @{
            VttFile = $vttFile.FullName
            OutputDir = $OutputDir
        }
        
        # Add anonymization setting
        if ($NoAnonymization) {
            $conversionParams.NoAnonymization = $true
        }
          # Add document linking parameters if enabled
        if ($EnableDocumentLinking) {
            # Generate custom document ID using the prefix
            $fileBaseName = $vttFile.BaseName
            $dateStamp = (Get-Date).ToString("yyyyMMdd")
            $customDocId = "$DocumentIdPrefix-$fileBaseName-$dateStamp"
            $conversionParams.DocumentId = $customDocId
            
            Write-Host "  Document ID: $customDocId" -ForegroundColor Gray
            
            # Add global related documents if provided
            if ($GlobalRelatedDocs) {
                $conversionParams.RelatedDocuments = $GlobalRelatedDocs
                Write-Host "  Related Docs: $GlobalRelatedDocs" -ForegroundColor Gray
            }
            
            # Add global document links if provided
            if ($GlobalDocumentLinks) {
                $conversionParams.DocumentLinks = $GlobalDocumentLinks
                Write-Host "  Document Links: $GlobalDocumentLinks" -ForegroundColor Gray
            }
        }
        
        # Execute conversion with parameters
        & $converterScript @conversionParams
        
        $stopwatch.Stop()
        $processingTime = $stopwatch.Elapsed.TotalSeconds
        
        # Check if output file was created
        $expectedOutput = Join-Path $OutputDir "$($vttFile.BaseName).md"
        if (Test-Path $expectedOutput) {
            $fileInfo = Get-Item $expectedOutput
            Write-Host "  SUCCESS: Created $($fileInfo.Name) ($($fileInfo.Length) bytes) in $([math]::Round($processingTime, 2))s" -ForegroundColor Green
            $success++
        } else {
            Write-Host "  FAILED: No output file created" -ForegroundColor Red
            $failed++
        }
        
        # Force garbage collection after processing large files
        if ($fileSizeMB -gt 5) {
            [System.GC]::Collect()
            Write-Host "  Memory cleanup performed" -ForegroundColor Gray
        }
        
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $failed++
    }
    
    Write-Host ""
}

# Summary with performance metrics
$batchStopwatch.Stop()
$totalBatchTime = $batchStopwatch.Elapsed.TotalSeconds

Write-Host "=== Batch Conversion Summary ===" -ForegroundColor Cyan
Write-Host "Total files found: $($vttFiles.Count)" -ForegroundColor White
Write-Host "Successfully converted: $success" -ForegroundColor Green
Write-Host "Failed conversions: $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })

# Calculate total file sizes processed
$totalSizeMB = [math]::Round(($vttFiles | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
Write-Host "Total data processed: $totalSizeMB MB" -ForegroundColor White

# Performance metrics
Write-Host "Total batch time: $([math]::Round($totalBatchTime, 2))s" -ForegroundColor Cyan
if ($success -gt 0) {
    $avgTimePerFile = [math]::Round($totalBatchTime / $success, 2)
    Write-Host "Average time per file: ${avgTimePerFile}s" -ForegroundColor Gray
    
    if ($totalSizeMB -gt 0) {
        $throughputMBps = [math]::Round($totalSizeMB / $totalBatchTime, 2)
        Write-Host "Processing throughput: $throughputMBps MB/s" -ForegroundColor Gray
    }
}

Write-Host "================================" -ForegroundColor Cyan

if ($failed -eq 0) {
    Write-Host "All conversions completed successfully!" -ForegroundColor Green
    Write-Host "💡 Tip: Large files are automatically optimized for memory usage" -ForegroundColor Gray
    exit 0
} else {
    Write-Host "Some conversions failed. Check the output above for details." -ForegroundColor Yellow
    exit 1
}
