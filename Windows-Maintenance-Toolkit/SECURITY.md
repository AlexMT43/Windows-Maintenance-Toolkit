# Security policy

## Reporting a vulnerability

Do not publish security-sensitive findings as a public issue. Report them
privately to the repository maintainer.

## Safety model

WMT avoids destructive operations by default:

- Personal folders such as Downloads and Documents are not removed.
- Hibernation is not disabled automatically.
- Restore points are not deleted.
- `DISM /ResetBase` is not used.
- Empty-folder deletion requires explicit confirmation.
- Reparse points, symbolic links and junctions are skipped.
- Cloud-only files and folders (Google Drive, OneDrive, Dropbox) are skipped, and
  virtual cloud drives are never scanned, to avoid propagating deletions to the
  cloud.
- Critical Windows paths are excluded.

Always review changes before running modified forks with administrator rights.
