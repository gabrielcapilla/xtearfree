# xtearfree

A command-line tool to manage TearFree settings for X11 displays, allowing users to enable, disable, or query the TearFree status of connected monitors.

## Description

**xtearfree** is a lightweight utility written in Nim that simplifies the management of the TearFree feature on X11 displays. It uses `xrandr` to detect connected displays and apply or query TearFree settings. The tool supports enabling/disabling TearFree across all connected displays and provides status information. Notifications are displayed using `notify-send` (optional) unless the `--silent` flag is used.

## Features

- Enable TearFree on all connected displays (`on` command).
- Disable TearFree on all connected displays (`off` command).
- Query the current TearFree status for each display (`status` command).
- Silent mode (`--silent`) to suppress graphical notifications and show console output only.
- Simple and lightweight, built with Nim for performance.
- MIT-licensed, open-source software.

## Prerequisites

Before installing and using **xtearfree**, ensure you have the following:

- **Nim** (version 2.0.8 or higher).
- **xrandr**: Required to detect and configure displays (usually included in X11 environments).
- **notify-send** (libnotify): Optional, for graphical notifications (not required in `--silent` mode).
- A Linux system with an X11 display server.

To check if `xrandr` and `notify-send` are installed, run:

```bash
xrandr --version
notify-send --version
```

## Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/gabrielcapilla/xtearfree.git
   cd xtearfree
   ```

2. Install dependencies and build the project using Nimble:

   ```bash
   nimble install
   ```

3. (Optional) The binary `fs` will be generated in the project directory and can be moved to a system path (e.g., `/usr/local/bin`) for global access:

   ```bash
   sudo mv fs /usr/local/bin
   ```

## Usage

Run `fs` with one of the following commands:

```bash
fs [COMMAND] [OPTIONS]
```

### Commands
- `on`: Enable TearFree on all connected displays.
- `off`: Disable TearFree on all connected displays.
- `status`: Display the current TearFree status for each connected display.

### Options
- `--silent`: Suppress graphical notifications and show console output only.

### Examples
- Enable TearFree on all displays:
  ```bash
  fs on
  ```
- Disable TearFree:
  ```bash
  fs off
  ```
- Check TearFree status:
  ```bash
  fs status
  ```
- Enable TearFree without notifications:
  ```bash
  fs on --silent
  ```
- Enable TearFree only in your Steam games:
  ```bash
  fs on ; %command% ; fs off
  ```

## Uninstallation

To uninstall **xtearfree**:

1. Uninstall using Nimble:
   ```bash
   nimble uninstall fs
   ```

2. Remove the binary (if moved to a system path):

   ```bash
   sudo rm /usr/local/bin/fs
   ```

---

**Documentation automatically generated by the artificial intelligence model [Gemma 3n](https://deepmind.google/models/gemma/gemma-3n/).*
