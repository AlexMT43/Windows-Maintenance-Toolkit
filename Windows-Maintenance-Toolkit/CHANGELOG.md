# Changelog

All notable changes to Windows Maintenance Toolkit will be documented here.

## [1.0.1] - 2026-07-20

### Fixed
- **Critical: prevented data loss on cloud storage.** Empty-folder removal could
  delete cloud-only ("online-only") folders from providers such as Google Drive
  and OneDrive. Because those deletions sync back to the cloud, remote files were
  removed. WMT now:
  - scans only fixed drives backed by a real physical disk, skipping virtual
    cloud drives (e.g. Google Drive's mounted drive) even when Windows reports
    them as fixed;
  - skips any file or folder carrying cloud placeholder attributes (`OFFLINE`,
    `RECALL_ON_OPEN`, `RECALL_ON_DATA_ACCESS`) or a reparse point;
  - excludes known sync folders (OneDrive, Google Drive, Dropbox, DriveFS) by
    default;
  - applies the same cloud guard during temporary-file cleanup.
- Error logging now records the correct path when a deletion fails (previously an
  empty path was logged, and under strict mode the failure handler could throw).
- Elevation cancelled at the UAC prompt now exits cleanly with a message.

### Added
- `SkipCloudFiles` option (default `true`) under `EmptyFolderScan`.

## [1.0.0] - 2026-07-20

### Added
- Interactive Spanish-language maintenance menu.
- Application updates through WinGet.
- Safe temporary-file cleanup.
- Windows Update download-cache cleanup.
- Recycle Bin cleanup.
- Windows component cleanup through DISM.
- Empty-folder removal with exclusions and confirmation.
- Windows integrity checks with DISM and SFC.
- DNS cache cleanup.
- System information report.
- Installed-app export through WinGet.
- Logging for each execution.
- JSON configuration file.
- Administrator elevation and Windows compatibility checks.
