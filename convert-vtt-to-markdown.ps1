# filepath: convert-vtt-to-markdown.ps1
# Generalized script to convert any VTT file to Markdown with YAML front matter
# documentId: script-convert-vtt-to-markdown-content-processing
# Usage: .\convert-vtt-to-markdown.ps1 -VttFile "path\to\file.vtt" [-OutputDir "path\to\output"] [-Title "Custom Title"] [-NoAnonymization]
#
# Anonymization Options (enabled by default):
# -AnonymizeNames: Replace speaker names with initials or participant IDs for privacy (DEFAULT: enabled)
# -UseParticipantIDs: Use P1, P2, P3 format instead of initials (DEFAULT: enabled)
# -NoAnonymization: Disable anonymization to show real speaker names
#
# Examples:
# .\convert-vtt-to-markdown.ps1 -VttFile "meeting.vtt"                    # Uses anonymization with participant IDs
# .\convert-vtt-to-markdown.ps1 -VttFile "meeting.vtt" -NoAnonymization  # Shows real speaker names

param(
    [Parameter(Mandatory=$true, HelpMessage="Path to the VTT file to convert")]
    [string]$VttFile,
    
    [Parameter(Mandatory=$false, HelpMessage="Output directory for the markdown file")]
    [string]$OutputDir,
    
    [Parameter(Mandatory=$false, HelpMessage="Custom title for the transcript")]
    [string]$Title,
    
    [Parameter(Mandatory=$false, HelpMessage="Custom keywords for the transcript")]
    [string]$Keywords,
    
    [Parameter(Mandatory=$false, HelpMessage="Meeting type/category")]
    [string]$MeetingType = "meeting_transcript",
    
    [Parameter(Mandatory=$false, HelpMessage="Unique document identifier for linking")]
    [string]$DocumentId,
    
    [Parameter(Mandatory=$false, HelpMessage="Comma-separated list of related document IDs")]
    [string]$RelatedDocuments,
      [Parameter(Mandatory=$false, HelpMessage="JSON object with document link types and IDs (e.g. '{`"notes`":`"doc-123`",`"slides`":`"doc-456`"}'")]
    [string]$DocumentLinks,
      
    [Parameter(Mandatory=$false, HelpMessage="Anonymize speaker names (replace with initials/IDs) - enabled by default")]
    [switch]$AnonymizeNames = $true,
    
    [Parameter(Mandatory=$false, HelpMessage="Use simple participant IDs (P1, P2, etc.) instead of initials")]
    [switch]$UseParticipantIDs = $true,
    
    [Parameter(Mandatory=$false, HelpMessage="Disable anonymization to show real speaker names")]
    [switch]$NoAnonymization
)

# Cross-platform path helper function
function Join-PathCrossPlatform {
    param([string[]]$Paths)
    return [System.IO.Path]::Combine($Paths)
}

# Function to validate PowerShell version and provide guidance
function Test-PowerShellCompatibility {
    $version = $PSVersionTable.PSVersion
    if ($version.Major -lt 5) {
        Write-Warning "This script requires PowerShell 5.1 or later. Current version: $version"
        Write-Host "Please upgrade PowerShell or use PowerShell Core 6+." -ForegroundColor Yellow
        return $false
    }
    return $true
}

# Validate environment before proceeding
if (-not (Test-PowerShellCompatibility)) {
    exit 1
}

# Function to generate title from filename
function Get-TitleFromFilename {
    param([string]$filename)
    
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($filename)
      # Convert common patterns to readable titles
    $title = $baseName -replace "_", " " -replace "-", " "
    # Fixed: removed problematic regex that was splitting every character
    
    # Split into words, capitalize each word, and join properly
    $words = $title -split '\s+' | Where-Object { $_.Length -gt 0 }
    $capitalizedWords = $words | ForEach-Object { 
        if ($_.Length -gt 1) {
            $_.Substring(0,1).ToUpper() + $_.Substring(1).ToLower()
        } else {
            $_.ToUpper()
        }
    }
      return $capitalizedWords -join " "
}

# Function to generate keywords from filename and path
function Get-KeywordsFromContext {
    param([string]$filepath)
    
    $keywords = @()
    
    # Extract from path segments
    $pathParts = $filepath -split [regex]::Escape([System.IO.Path]::DirectorySeparatorChar)
    foreach ($part in $pathParts) {
        if ($part -match "(bicep|azure|arc|meeting|transcript|change|safe|connecting|resources)") {
            $keywords += $matches[1]
        }
    }
    
    # Extract from filename
    $filename = [System.IO.Path]::GetFileNameWithoutExtension($filepath)
    if ($filename -match "(bicep|azure|arc|meeting|roundtable|kickoff|research|update)") {
        $keywords += $matches[1]
    }
    
    # Add common meeting-related keywords
    $keywords += @("meeting", "transcript", "discussion")
    
    # Remove duplicates and return
    return ($keywords | Select-Object -Unique) -join ", "
}

# Function to generate a document ID based on filename and date
function Get-DocumentIdFromContext {
    param([string]$filepath, [string]$customId)
    
    # If custom ID is provided, use it
    if ($customId -and $customId.Trim() -ne "") {
        return $customId.Trim()
    }
    
    # Generate ID from filename and date
    $filename = [System.IO.Path]::GetFileNameWithoutExtension($filepath)
    $cleanName = $filename -replace '[^a-zA-Z0-9\-_]', '-' -replace '-+', '-'
    $dateStamp = Get-Date -Format "yyyyMMdd"
    
    return "transcript-$cleanName-$dateStamp"
}

# Function to parse and validate document links JSON
function Get-DocumentLinksFromJson {
    param([string]$jsonString)
    
    if (-not $jsonString -or $jsonString.Trim() -eq "") {
        return $null
    }
    
    try {
        $links = $jsonString | ConvertFrom-Json
        return $links
    } catch {
        Write-Warning "Invalid JSON format for DocumentLinks: $jsonString"
        return $null
    }
}

# Function to get anonymized speaker name
function Get-AnonymizedSpeakerName {
    param(
        [string]$originalName,
        [hashtable]$speakerMapping,
        [bool]$useParticipantIDs
    )
    
    if (-not $speakerMapping.ContainsKey($originalName)) {
        if ($useParticipantIDs) {
            # Use simple P1, P2, P3 format
            $participantNumber = $speakerMapping.Count + 1
            $anonymizedName = "P$participantNumber"
        } else {
            # Use initials from the name
            $nameParts = $originalName -split '\s+'
            if ($nameParts.Count -eq 1) {
                # Single name - use first letter + number
                $anonymizedName = $nameParts[0][0].ToString().ToUpper() + "1"
            } elseif ($nameParts.Count -eq 2) {
                # First and last name - use initials
                $anonymizedName = ($nameParts[0][0] + $nameParts[1][0]).ToString().ToUpper()
            } else {
                # Multiple names - use first and last initials
                $anonymizedName = ($nameParts[0][0] + $nameParts[-1][0]).ToString().ToUpper()
            }
            
            # Handle duplicate initials by adding numbers
            $baseAnonymized = $anonymizedName
            $counter = 1
            while ($speakerMapping.Values -contains $anonymizedName) {
                $counter++
                $anonymizedName = $baseAnonymized + $counter
            }
        }
        
        $speakerMapping[$originalName] = $anonymizedName
        Write-Host "Mapping speaker: '$originalName' -> '$anonymizedName'"
    }
    
    return $speakerMapping[$originalName]
}

# Validate input file
if (-not (Test-Path $VttFile)) {
    Write-Error "VTT file not found: $VttFile"
    exit 1
}

$VttFile = Resolve-Path $VttFile
Write-Host "Converting VTT file: $VttFile"

# Determine output directory
if (-not $OutputDir) {
    $OutputDir = Join-Path (Get-Location) "output"
}

# Create output directory if it doesn't exist
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Host "Created output directory: $OutputDir"
}

# Generate output filename
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($VttFile)
$mdOutputPath = Join-Path $OutputDir "$baseName.md"

# Generate title if not provided
if (-not $Title) {
    $Title = Get-TitleFromFilename $baseName
}

# Generate keywords if not provided
if (-not $Keywords) {
    $Keywords = Get-KeywordsFromContext $VttFile
}

# Get current date for metadata
$currentDate = Get-Date -Format "yyyy-MM-dd"

# Generate document ID if not provided
$documentId = Get-DocumentIdFromContext -filepath $VttFile -customId $DocumentId

# Process related documents
$relatedDocsList = @()
if ($RelatedDocuments -and $RelatedDocuments.Trim() -ne "") {
    $relatedDocsList = ($RelatedDocuments -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
}

# Process document links
$documentLinksObj = Get-DocumentLinksFromJson -jsonString $DocumentLinks

# Read the VTT file with memory optimization
try {
    Write-Host "Reading VTT file..." -ForegroundColor Gray
    
    # For large files, read in chunks to reduce memory usage
    $fileInfo = Get-Item -Path $VttFile
    $fileSizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
    Write-Host "File size: $fileSizeMB MB" -ForegroundColor Gray
    
    if ($fileInfo.Length -gt 50MB) {
        Write-Host "Large file detected. Using optimized reading..." -ForegroundColor Yellow
        # For very large files, read line by line
        $lines = Get-Content -Path $VttFile -Encoding UTF8
    } else {
        # For smaller files, use the existing approach but with cleanup
        $content = Get-Content -Path $VttFile -Raw -Encoding UTF8
        $lines = $content -split "`r`n|`n"
        
        # Clear the raw content from memory immediately
        $content = $null
        [System.GC]::Collect()
    }
} catch {
    Write-Error "Failed to read VTT file: $_"
    exit 1
}

# Initialize processing variables
$currentSpeaker = ""
$currentText = ""
$inDialogue = $false
$speakersList = @{}
$speakerMapping = @{}  # For anonymization mapping
$processedLines = 0
$totalLines = $lines.Count

Write-Host "Processing transcript content..." -ForegroundColor White
Write-Host "Total lines to process: $totalLines" -ForegroundColor Gray

# Use StringBuilder for efficient string concatenation
$markdownBuilder = [System.Text.StringBuilder]::new()
$null = $markdownBuilder.AppendLine("---")
$null = $markdownBuilder.AppendLine("title: `"$Title`"")
$null = $markdownBuilder.AppendLine("date: `"$currentDate`"")
$null = $markdownBuilder.AppendLine("type: `"$MeetingType`"")
$null = $markdownBuilder.AppendLine("keywords: `"$Keywords`"")
$null = $markdownBuilder.AppendLine("source_file: `"$(Split-Path -Leaf $VttFile)`"")
$null = $markdownBuilder.AppendLine("document_id: `"$documentId`"")

# Add related documents if specified
if ($relatedDocsList.Count -gt 0) {
    $relatedDocsYaml = ($relatedDocsList | ForEach-Object { "`"$_`"" }) -join ", "
    $null = $markdownBuilder.AppendLine("related_documents: [$relatedDocsYaml]")
}

# Add document links if specified
if ($documentLinksObj) {
    $null = $markdownBuilder.AppendLine("document_links:")
    $documentLinksObj.PSObject.Properties | ForEach-Object {
        $null = $markdownBuilder.AppendLine("  $($_.Name): `"$($_.Value)`"")
    }
}

$null = $markdownBuilder.AppendLine("---")
$null = $markdownBuilder.AppendLine("")
$null = $markdownBuilder.AppendLine("# $Title")
$null = $markdownBuilder.AppendLine("")
$null = $markdownBuilder.AppendLine("> This is an automatically generated transcript that may contain minor inaccuracies.")
$null = $markdownBuilder.AppendLine("")

# Process the transcript with progress tracking
foreach ($line in $lines) {
    $processedLines++
    
    # Show progress every 100 lines for large files
    if ($totalLines -gt 500 -and $processedLines % 100 -eq 0) {
        $percentComplete = [math]::Round(($processedLines / $totalLines) * 100, 1)
        Write-Host "Progress: $percentComplete% ($processedLines/$totalLines)" -ForegroundColor Gray
    }
      # Skip WEBVTT header, timestamps, empty lines, and UUID identifier lines
    if ($line -eq "WEBVTT" -or $line -eq "" -or 
        $line -match "^\d{2}:\d{2}:\d{2}\.\d{3} --> \d{2}:\d{2}:\d{2}\.\d{3}$" -or 
        $line -match "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\/\d+-\d+$" -or 
        $line -match "^\d{2}:\d{2}:\d{2}\.\d{3}$" -or
        $line -match "^NOTE\s" -or
        $line -match "^STYLE\s") {
        continue
    }
    
    # Clean up the line - remove VTT IDs and tags (but preserve speaker tags for now)
    $cleanedLine = $line -replace '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\/\d+-\d+', ''
    
    # Check if line contains a speaker designation BEFORE cleaning other tags
    if ($cleanedLine -match "<v\s+([^>]+)>(.*)") {
        $originalSpeaker = $matches[1].Trim()
        $text = $matches[2].Trim()
          
        # Clean the text of remaining tags
        $text = $text -replace '<\/v>', ''
        $text = $text -replace '<[^>]*>', ''
        
        # Get the speaker name (anonymized or original)
        if ($AnonymizeNames -and -not $NoAnonymization) {
            $speaker = Get-AnonymizedSpeakerName -originalName $originalSpeaker -speakerMapping $speakerMapping -useParticipantIDs $UseParticipantIDs
        } else {
            $speaker = $originalSpeaker
        }
        
        # Record all speakers we find
        if (-not $speakersList.ContainsKey($speaker)) {
            $speakersList[$speaker] = $true
        }
          
        # If we detect a new speaker, output the previous speaker's text
        if ($currentSpeaker -ne "" -and $currentSpeaker -ne $speaker -and $currentText -ne "") {
            $null = $markdownBuilder.AppendLine("**${currentSpeaker}:** " + $currentText.Trim())
            $null = $markdownBuilder.AppendLine("")
            $currentText = ""
        }
        
        $currentSpeaker = $speaker
        $currentText += "$text "
        $inDialogue = $true
    } else {
        # Now clean all remaining tags for non-speaker lines
        $cleanedLine = $cleanedLine -replace '<\/v>', ''
        $cleanedLine = $cleanedLine -replace '<[^>]*>', ''
        
        # If we're in a dialogue but no speaker tag, append to current text
        if ($inDialogue -and $currentSpeaker -ne "" -and $cleanedLine.Trim() -ne "") {
            # Clean up the text before adding
            $cleanText = $cleanedLine -replace '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\/\d+-\d+', ''
            $cleanText = $cleanText.Trim()
            if ($cleanText -ne "") {
                $currentText += "$cleanText "
            }
        }
        # Handle lines that might be speaker names without tags (fallback)
        elseif ($cleanedLine.Trim() -ne "" -and -not $inDialogue) {
            # Check if this looks like a speaker transition
            if ($cleanedLine -match "^([A-Za-z\s]+):\s*(.*)") {
                $originalSpeaker = $matches[1].Trim()
                $text = $matches[2].Trim()
                  
                # Get the speaker name (anonymized or original)
                if ($AnonymizeNames -and -not $NoAnonymization) {
                    $speaker = Get-AnonymizedSpeakerName -originalName $originalSpeaker -speakerMapping $speakerMapping -useParticipantIDs $UseParticipantIDs
                } else {
                    $speaker = $originalSpeaker
                }
                  
                if (-not $speakersList.ContainsKey($speaker)) {
                    $speakersList[$speaker] = $true
                }
                
                if ($currentSpeaker -ne "" -and $currentText -ne "") {
                    $null = $markdownBuilder.AppendLine("**${currentSpeaker}:** " + $currentText.Trim())
                    $null = $markdownBuilder.AppendLine("")
                }
                
                $currentSpeaker = $speaker
                $currentText = "$text "
                $inDialogue = $true
            }
        }
    }
}

# Add the last speaker's text
if ($currentSpeaker -ne "" -and $currentText -ne "") {
    $null = $markdownBuilder.AppendLine("**${currentSpeaker}:** " + $currentText.Trim())
    $null = $markdownBuilder.AppendLine("")
}

# If we found speakers, add participants section and update YAML
if ($speakersList.Count -gt 0) {
    # Build participants section using StringBuilder
    $participantsBuilder = [System.Text.StringBuilder]::new()
    $null = $participantsBuilder.AppendLine("## Participants")
    $null = $participantsBuilder.AppendLine("")
    
    if ($AnonymizeNames -and -not $NoAnonymization -and $speakerMapping.Count -gt 0) {
        # Show anonymized names with original mapping
        foreach ($speaker in $speakersList.Keys | Sort-Object) {
            $null = $participantsBuilder.Append("- **$speaker**")
            
            # Find the original name for this anonymized speaker
            $originalName = ($speakerMapping.GetEnumerator() | Where-Object { $_.Value -eq $speaker }).Key
            if ($originalName) {
                $null = $participantsBuilder.Append(" *(anonymized)*")
            }
            $null = $participantsBuilder.AppendLine("")
        }
        
        # Add anonymization note
        $null = $participantsBuilder.AppendLine("")
        $null = $participantsBuilder.AppendLine("*Note: Speaker names have been anonymized for privacy.*")
        
        # Use anonymized names in YAML metadata
        $participantsString = $speakersList.Keys -join ", "
    } else {
        # Show original names
        foreach ($speaker in $speakersList.Keys | Sort-Object) {
            $null = $participantsBuilder.AppendLine("- **$speaker**")
        }
        $participantsString = $speakersList.Keys -join ", "
    }
    
    $null = $participantsBuilder.AppendLine("")
    
    # Update the markdown builder with participants info
    $markdownContent = $markdownBuilder.ToString()
    $markdownContent = $markdownContent -replace "(source_file: `"[^`"]+`"`n)", "`$1participants: `"$participantsString`"`n"
    
    # Insert the participants list after the introduction
    $participantsSection = $participantsBuilder.ToString()
    $markdownContent = $markdownContent -replace "(# [^`n]+`n`n> This is an automatically generated transcript that may contain minor inaccuracies\.`n`n)", "`$1$participantsSection"
    
    $markdown = $markdownContent
    Write-Host "Found $($speakersList.Count) speakers: $($speakersList.Keys -join ', ')"
} else {
    $markdown = $markdownBuilder.ToString()
    Write-Host "No speakers detected in VTT file - treating as plain transcript"
}

# Clean up memory
$markdownBuilder = $null
$lines = $null
[System.GC]::Collect()

# Write the markdown to the output file
try {
    $markdown | Out-File -FilePath $mdOutputPath -Encoding UTF8
    Write-Host "Successfully created Markdown file: $mdOutputPath"
    
    # Display file information
    if (Test-Path $mdOutputPath) {
        $fileInfo = Get-Item $mdOutputPath
        Write-Host "File size: $($fileInfo.Length) bytes"
        Write-Host "Created: $($fileInfo.CreationTime)"
    }
} catch {
    Write-Error "Failed to write markdown file: $_"
    exit 1
}

# Summary
Write-Host "`n=== Conversion Summary ===" -ForegroundColor Green
Write-Host "Input:  $VttFile"
Write-Host "Output: $mdOutputPath"
Write-Host "Title:  $Title"
Write-Host "Type:   $MeetingType"
Write-Host "Speakers: $($speakersList.Count)"
if ($AnonymizeNames -and -not $NoAnonymization) {
    Write-Host "Anonymization: Enabled ($($speakerMapping.Count) speakers anonymized)"
    if ($UseParticipantIDs) {
        Write-Host "Format: Participant IDs (P1, P2, etc.)"
    } else {
        Write-Host "Format: Initials with numbers"
    }
} else {
    Write-Host "Anonymization: Disabled (original names preserved)"
}
Write-Host "=========================" -ForegroundColor Green
