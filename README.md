# Unraid Backup Rsync

A bash script for Unraid that backs up selected user shares to an unassigned disk using `rsync`. It mirrors each source to a `current/` folder while automatically archiving any changed or deleted files into timestamped `archive/` directories, giving you point-in-time recovery. Before running, it verifies the destination disk is mounted to prevent accidentally writing to the array.

Old archives and logs are automatically pruned after a configurable retention period (default 90 days). Unraid web GUI notifications are sent on both failure (disk not mounted) and successful completion. All output, including rsync stats and errors, is captured in date-stamped log files on the destination disk.