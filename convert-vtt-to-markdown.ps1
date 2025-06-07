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
      [Parameter(Mandatory=$false, HelpMessage="Anonymize speaker names (replace with initials/IDs) - enabled by default")]
    [switch]$AnonymizeNames = $true,
    
    [Parameter(Mandatory=$false, HelpMessage="Use simple participant IDs (P1, P2, etc.) instead of initials")]
    [switch]$UseParticipantIDs = $true,
    
    [Parameter(Mandatory=$false, HelpMessage="Disable anonymization to show real speaker names")]
    [switch]$NoAnonymization
)

# Function to generate title from filename
function Get-TitleFromFilename {
    param([string]$filename)
    
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($filename)
    
    # Convert common patterns to readable titles
    $title = $baseName -replace "_", " " -replace "-", " "
    $title = $title -replace "([a-z])([A-Z])", '$1 $2'  # camelCase to spaced
    $title = (Get-Culture).TextInfo.ToTitleCase($title.ToLower())
    
    return $title
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

# Read the VTT file
try {
    $content = Get-Content -Path $VttFile -Raw -Encoding UTF8
} catch {
    Write-Error "Failed to read VTT file: $_"
    exit 1
}

# Process the content
$lines = $content -split "`r`n|`n"

# Start building markdown with YAML front matter
$markdown = "---`n"
$markdown += "title: `"$Title`"`n"
$markdown += "date: `"$currentDate`"`n"
$markdown += "type: `"$MeetingType`"`n"
$markdown += "keywords: `"$Keywords`"`n"
$markdown += "source_file: `"$(Split-Path -Leaf $VttFile)`"`n"
$markdown += "---`n`n"

$markdown += "# $Title`n`n"

# Add a note about the transcript
$markdown += "> This is an automatically generated transcript that may contain minor inaccuracies.`n`n"

# Initialize processing variables
$currentSpeaker = ""
$currentText = ""
$inDialogue = $false
$speakersList = @{}
$speakerMapping = @{}  # For anonymization mapping

Write-Host "Processing transcript content..."

# Process the transcript
foreach ($line in $lines) {
    # Skip WEBVTT header, timestamps, and empty lines
    if ($line -eq "WEBVTT" -or $line -eq "" -or 
        $line -match "^\d{2}:\d{2}:\d{2}\.\d{3} --> \d{2}:\d{2}:\d{2}\.\d{3}$" -or 
        $line -match "^c?[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}" -or 
        $line -match "^\d{2}:\d{2}:\d{2}\.\d{3}$" -or
        $line -match "^NOTE\s" -or
        $line -match "^STYLE\s") {
        continue
    }    # Clean up the line - remove VTT IDs and tags (but preserve speaker tags for now)
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
            $markdown += "**${currentSpeaker}:** " + $currentText.Trim() + "`n`n"
            $currentText = ""
        }
        
        $currentSpeaker = $speaker
        $currentText += "$text "
        $inDialogue = $true    } else {
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
                    $markdown += "**${currentSpeaker}:** " + $currentText.Trim() + "`n`n"
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
    $markdown += "**${currentSpeaker}:** " + $currentText.Trim() + "`n`n"
}

# If we found speakers, add participants section and update YAML
if ($speakersList.Count -gt 0) {
    # Add a participants list
    $participantsMarkdown = "## Participants`n`n"
    
    if ($AnonymizeNames -and -not $NoAnonymization -and $speakerMapping.Count -gt 0) {
        # Show anonymized names with original mapping
        foreach ($speaker in $speakersList.Keys | Sort-Object) {
            $participantsMarkdown += "- **$speaker**"
            
            # Find the original name for this anonymized speaker
            $originalName = ($speakerMapping.GetEnumerator() | Where-Object { $_.Value -eq $speaker }).Key
            if ($originalName) {
                $participantsMarkdown += " *(anonymized)*"
            }
            $participantsMarkdown += "`n"
        }
        
        # Add anonymization note
        $participantsMarkdown += "`n*Note: Speaker names have been anonymized for privacy.*`n"
        
        # Use anonymized names in YAML metadata
        $participantsString = $speakersList.Keys -join ", "
    } else {
        # Show original names
        foreach ($speaker in $speakersList.Keys | Sort-Object) {
            $participantsMarkdown += "- **$speaker**`n"
        }
        $participantsString = $speakersList.Keys -join ", "
    }
    
    $participantsMarkdown += "`n"
    $markdown = $markdown -replace "(source_file: `"[^`"]+`"\n)", "`$1participants: `"$participantsString`"`n"
    
    # Insert the participants list after the introduction
    $markdown = $markdown -replace "(# [^`n]+`n`n> This is an automatically generated transcript that may contain minor inaccuracies\.`n`n)", "`$1$participantsMarkdown"
    
    Write-Host "Found $($speakersList.Count) speakers: $($speakersList.Keys -join ', ')"
} else {
    Write-Host "No speakers detected in VTT file - treating as plain transcript"
}

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
