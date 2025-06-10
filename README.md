# VTT to Markdown Converter

A streamlined PowerShell toolkit for converting VTT (Video Text Track) files to well-formatted Markdown documents with YAML front matter. This tool transforms subtitle/transcript files into structured documentation optimized for knowledge management workflows.

## 🚀 Features

- **Single File Conversion**: Convert individual VTT files to Markdown
- **Batch Processing**: Process entire directories of VTT files automatically
- **Speaker Anonymization**: Privacy-focused options to anonymize speaker names
- **Document Linking**: Link transcripts to related documents using unique IDs
- **YAML Front Matter**: Automatic generation of metadata headers for static site generators
- **Flexible Output**: Customizable output directories and file naming conventions
- **Keyword Generation**: Automatic keyword extraction from file context
- **Privacy-First Design**: Data isolation with local-only transcript storage

## 📋 Prerequisites

- Windows PowerShell 5.1 or PowerShell Core 6+
- Read/write access to source and output directories
- VTT files from meeting recordings, webinars, or video content

## 🔧 Scripts

### `convert-vtt-to-markdown.ps1`

Converts a single VTT file to Markdown format with YAML front matter and optional speaker anonymization.

#### 📖 Usage
```powershell
# Basic conversion with anonymization (default)
.\convert-vtt-to-markdown.ps1 -VttFile "meeting.vtt"

# Disable anonymization to show real names
.\convert-vtt-to-markdown.ps1 -VttFile "meeting.vtt" -NoAnonymization

# Custom output directory and title
.\convert-vtt-to-markdown.ps1 -VttFile "meeting.vtt" -OutputDir "output" -Title "Team Meeting"

# With document linking for knowledge management
.\convert-vtt-to-markdown.ps1 -VttFile "meeting.vtt" -DocumentId "standup-2025-q2-week24" -RelatedDocuments "agenda-001,action-items-001" -DocumentLinks '{"notes":"meeting-notes-001","slides":"presentation-slides-001"}'

# Anonymize speaker names
.\convert-vtt-to-markdown.ps1 -VttFile "meeting.vtt" -AnonymizeNames

# Use participant IDs (P1, P2, P3) instead of initials
.\convert-vtt-to-markdown.ps1 -VttFile "meeting.vtt" -AnonymizeNames -UseParticipantIDs
```

#### 📊 Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `VttFile` | String | Yes | - | Path to the VTT file to convert |
| `OutputDir` | String | No | Same as input | Output directory for the markdown file |
| `Title` | String | No | Auto-generated | Custom title for the document |
| `Keywords` | String | No | Auto-generated | Custom keywords for metadata |
| `MeetingType` | String | No | "meeting_transcript" | Type classification for the document |
| `DocumentId` | String | No | Auto-generated | Unique identifier for document linking |
| `RelatedDocuments` | String | No | None | Comma-separated list of related document IDs |
| `DocumentLinks` | String | No | None | JSON object with link types and document IDs |
| `AnonymizeNames` | Switch | No | True | Enable speaker name anonymization |

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
