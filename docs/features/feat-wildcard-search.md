# Feature: Wildcard Search Support
## Status
**Author**: Joshua Sherwood
**Last Modified**: 2026-Sep-15
**Status**: Complete

## Description
This section outlines the requirement for wildcard search support in filesystem operations. Wildcard searches will be used to identify things like image files (e.g., `*.png`, `*.jpg`) during directory scanning. This ensures that all relevant files, regardless of their specific names, are detected.

## Use Case
When scanning a directory for image files, the system should:
- Use wildcard patterns (e.g., `*.png`, `*.jpg`) to match all files with the specified extensions.
- Return all matching files during the directory scan.

## Technical Implementation
### Directory Scanning with Wildcards
- Modify the `mcp_SwagenticMCP_filesystem` tool to support wildcard searches, update resource documentation.
- Ensure the `recursive_find_file` operation can accept wildcard patterns for names and extensions.
- Ensure the `recursive_find_dir` operation can accept wildcard patterns for names.

## Example Workflow
1. User provides a directory path (e.g., `/path/to/music/album`).
2. The system scans the directory using a wildcard pattern (e.g., `*.png` or `*.jpg`).
   - If any matches are found, the process ends.
   - If no matches are found, user is notified.

## Dependencies
- Support for wildcard searches in the `mcp_SwagenticMCP_filesystem` tool.

---

## Completed Steps
1. **Update Filesystem Tool**:
   - Modify the `mcp_SwagenticMCP_filesystem` tool to support wildcard searches.
2. **Test Wildcard Scanning**:
   - Verify that wildcard searches correctly identify image files.

---

