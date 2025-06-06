# VTT to Markdown Converter

A PowerShell-based toolkit for converting VTT (Video Text Track) files to well-formatted Markdown documents with YAML front matter.

## Overview

This repository contains PowerShell scripts that convert VTT subtitle/transcript files into structured Markdown documents. The converted files include metadata, proper speaker formatting, and are optimized for documentation workflows.

## Features

- **Single File Conversion**: Convert individual VTT files to Markdown
- **Batch Processing**: Convert multiple VTT files at once
- **Speaker Anonymization**: Option to anonymize speaker names for privacy
- **YAML Front Matter**: Automatic generation of metadata headers
- **Flexible Output**: Customizable output directories and file naming
- **Keyword Generation**: Automatic keyword extraction from context

## Scripts

### `convert-vtt-to-markdown.ps1`

Converts a single VTT file to Markdown format with YAML front matter.

#### Usage
```powershell
# Basic conversion
.\convert-vtt-to-markdown.ps1 -VttFile "meeting.vtt"

# Custom output directory and title
.\convert-vtt-to-markdown.ps1 -VttFile "meeting.vtt" -OutputDir "output" -Title "Team Meeting"

# Anonymize speaker names
.\convert-vtt-to-markdown.ps1 -VttFile "meeting.vtt" -AnonymizeNames

# Use participant IDs (P1, P2, P3) instead of initials
.\convert-vtt-to-markdown.ps1 -VttFile "meeting.vtt" -AnonymizeNames -UseParticipantIDs
```

#### Parameters
- `-VttFile`: Path to the VTT file to convert (required)
- `-OutputDir`: Output directory for the markdown file (optional)
- `-Title`: Custom title for the document (optional, auto-generated if not provided)
- `-AnonymizeNames`: Replace speaker names with initials for privacy
- `-UseParticipantIDs`: Use P1, P2, P3 format instead of initials (requires -AnonymizeNames)

### `batch-convert-vtt.ps1`

Processes multiple VTT files in batch with the same conversion settings.

#### Usage
```powershell
# Convert all VTT files in current directory
.\batch-convert-vtt.ps1

# Convert files from specific source to specific output
.\batch-convert-vtt.ps1 -SourceDir "transcripts" -OutputDir "markdown-output"

# Process recursively with anonymization
.\batch-convert-vtt.ps1 -SourceDir "transcripts" -Recursive -AnonymizeNames

# Custom file filter
.\batch-convert-vtt.ps1 -Filter "meeting*.vtt" -AnonymizeNames -UseParticipantIDs
```

#### Parameters
- `-SourceDir`: Directory containing VTT files (optional, defaults to current directory)
- `-OutputDir`: Output directory for markdown files (optional, defaults to "markdown-output")
- `-Filter`: File filter pattern (optional, defaults to "*.vtt")
- `-Recursive`: Process subdirectories recursively
- `-AnonymizeNames`: Replace speaker names with initials for privacy
- `-UseParticipantIDs`: Use P1, P2, P3 format instead of initials

## Output Format

The converted Markdown files include:

### YAML Front Matter
```yaml
---
title: "Meeting Title"
date: "2025-06-06"
type: "transcript"
keywords: "meeting, discussion, transcript"
source_file: "original.vtt"
---
```

### Formatted Content
- Proper speaker identification
- Timestamp preservation (optional)
- Automatic paragraph formatting
- Privacy-conscious speaker anonymization when requested

## Data Directory Structure

The `data/` directory is excluded from version control and can contain:
- `transcripts/` - Source VTT files
- `markdown-output/` - Converted Markdown files
- `processed/` - Processed files archive
- `temp/` - Temporary processing files

## Requirements

- Windows PowerShell 5.1 or PowerShell Core 6+
- Read/write access to source and output directories

## Privacy Features

### Speaker Anonymization
When using the `-AnonymizeNames` flag:
- Speaker names are replaced with initials (e.g., "John Smith" becomes "JS")
- Consistent mapping maintained throughout the document
- Option to use participant IDs (P1, P2, P3) for additional privacy

### Data Isolation
- All transcript data is kept in the local `data/` directory
- Data directory is excluded from version control
- Only PowerShell scripts are tracked in the repository

## Examples

### Converting a Single Meeting
```powershell
.\convert-vtt-to-markdown.ps1 -VttFile "data\transcripts\team-meeting.vtt" -Title "Weekly Team Sync"
```

### Batch Processing with Privacy
```powershell
.\batch-convert-vtt.ps1 -SourceDir "data\transcripts" -OutputDir "data\markdown-output" -AnonymizeNames -UseParticipantIDs
```

### Processing Specific File Types
```powershell
.\batch-convert-vtt.ps1 -Filter "interview*.vtt" -AnonymizeNames
```

## Contributing

This is a focused toolkit for VTT processing. When contributing:
1. Maintain the privacy-first approach
2. Keep data separate from code
3. Test with various VTT formats
4. Update documentation for new features

## License

This project is intended for internal use and transcript processing workflows.
