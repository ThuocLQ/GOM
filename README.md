# Delivery Copy

Delivery Copy collects files for software delivery. The portable package is intentionally simple: a CMD launcher and a PowerShell application script.

## Run

1. Right-click the ZIP and choose **Extract All**.
2. Open the extracted folder and double-click **`DeliveryCopy.cmd`**.
3. If startup fails, the CMD window stays open and prints the error. It also writes `DeliveryCopy_startup_error.log` beside the tool.

Windows PowerShell 5.1 is included with Windows 10 and 11. Git for Windows is required only for Git comparison.

## Git workflow

1. Choose the repository folder as **Source folder**.
2. Select the **Base branch** and **Compare branch**.
3. Click **Sync and compare**. The tool runs `git fetch --all --prune` before comparison, keeping remote branch references current without changing your checked-out branch.
4. Review the file list, then continue to **Delivery**.

## Included capabilities

- Rename-safe Git comparison.
- Optional staged, unstaged, and untracked changes.
- Paste one file path per line from Git, Excel, or another tool.
- Add a manually typed folder path, browse a folder, or choose individual files.
- Preserve source folder structure, duplicate-file handling, SHA-256 verification, CSV manifest, and optional `runscript.sql`.
