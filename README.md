# Delivery Copy

Delivery Copy collects files for software delivery. It is a portable Windows PowerShell 5.1 application with a WPF interface: no EXE, .NET SDK, installer, or build step is required.

## Run

1. Right-click the ZIP and choose **Extract All**.
2. Open the extracted folder and double-click **`DeliveryCopy.cmd`**.
3. If startup fails, the CMD window stays open and prints the error. It also writes `DeliveryCopy_startup_error.log` beside the tool.

Windows PowerShell 5.1 and WPF are included with Windows 10 and 11. Git for Windows is required only for Git comparison.

## Package layout

- `DeliveryCopy.cmd` — portable STA launcher.
- `DeliveryCopy.ps1` — backward-compatible bootstrap.
- `App.ps1` — WPF interaction layer.
- `UI.xaml` — layout, design tokens, and controls.
- `Core.Git.ps1`, `Core.FileOps.ps1`, `Core.SqlPlus.ps1` — independently reviewable application logic.

## Git workflow

1. Choose the repository folder as **Source folder**.
2. Select the **Base branch** and **Compare branch**.
3. Click **Sync and compare**. The tool runs `git fetch --all --prune` before comparison, keeping remote branch references current without changing your checked-out branch.
4. Review the file list, then continue to **Delivery**.

## Included capabilities

- Rename-safe Git comparison, after `git fetch --all --prune`.
- Optional staged, unstaged, and untracked changes.
- Paste one file path per line from Git, Excel, or another tool.
- Add a manually typed folder path, browse a folder, or choose individual files.
- Preserve source folder structure, duplicate-file handling, SHA-256 verification, CSV manifest, and optional `runscript.sql`.
- Background folder scan and background copy/verification, with cooperative cancellation that still saves the manifest.
- Password is kept only in memory. `runscript.sql` never contains a password; SQL*Plus prompts when it runs.
