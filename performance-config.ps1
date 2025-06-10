# VTT Library Performance Configuration
# This file contains optimized settings for better performance

# Memory Management Settings
$LARGE_FILE_THRESHOLD_MB = 50          # Files larger than this use line-by-line reading
$MEMORY_CLEANUP_THRESHOLD_MB = 5       # Files larger than this trigger garbage collection
$PROGRESS_UPDATE_INTERVAL = 100        # Show progress every N lines for large files

# VS Code Performance Settings Applied:
# - File watcher exclusions for output directories
# - Search exclusions for temporary files
# - Editor limit increased to 15 tabs
# - Large file optimizations enabled
# - Auto-save on window change
# - PowerShell console optimizations

# Batch Processing Optimizations:
# - Progress tracking with file indexing
# - Processing time monitoring
# - File size reporting
# - Memory cleanup for large files
# - Total data processed metrics

# Individual File Processing Optimizations:
# - Chunked reading for large files (>50MB)
# - StringBuilder for efficient string concatenation
# - Immediate memory cleanup after raw content reading
# - Progress reporting for files with >500 lines
# - Garbage collection triggers

Write-Host "VTT Library Performance Configuration Loaded" -ForegroundColor Green
Write-Host "Large file threshold: $LARGE_FILE_THRESHOLD_MB MB" -ForegroundColor Gray
Write-Host "Memory cleanup threshold: $MEMORY_CLEANUP_THRESHOLD_MB MB" -ForegroundColor Gray
