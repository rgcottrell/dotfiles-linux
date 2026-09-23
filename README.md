# CachyOS + Niri dotfiles

A keyboard-first, Catppuccin Mocha desktop with a mauve accent. Inspired by
Omarchy's cohesive presentation, using Niri, DankMaterialShell (Quickshell),
Ghostty and swaylock.
The background is a quiet Mocha
base colour. Existing browser, file manager, shell, KDE session and CachyOS
repositories remain available.

## Install

Requires an existing CachyOS/Arch installation, a regular desktop user, Git,
Python 3 and sudo. Niri **26.04 or newer** is required. Clone this repository to
a permanent location (for example `~/.dotfiles`), then:

```sh
cd ~/.dotfiles
./install --dry-run --packages
./install --packages
```

`--packages` runs `sudo pacman -Syu --needed` with `packages.txt`, retaining the
normal pacman confirmation. This performs a full system upgrade to avoid Arch
partial upgrades. No AUR helper, remote install script, kernel replacement or
display-manager replacement is used. Review pacman's transaction before accepting.
`--packages-only` installs packages without changing dotfiles. Plain `./install`
only validates and links configuration; it assumes packages are already present.

Select **Niri** in the login screen after logging out. From a TTY, use
`niri-session`, not plain `niri`, so portals and session services are available.
Install a browser and file manager of your choice on a fresh system; the bindings
use your existing XDG defaults. PipeWire/WirePlumber and NetworkManager should be
configured by the base OS. This installer does not enable system services.

The installer backs up each conflicting file or symlink, links individual files
(leaving unrelated files alone), and prints its rollback command. Repeating the
install is a no-op when links are correct. Keep the repository in place: your
configuration points into it. Edits in the repo are live, including Niri hot reload.
The installer refuses symlinked parent directories rather than writing through
them into another dotfiles repository.

## Everyday keys

`Super` is the Windows/Command key.

| Shortcut | Action |
| --- | --- |
| Super+Return / Super+T | Ghostty |
| Super+D | App launcher |
| Super+Space | DMS control centre |
| Super+B / Super+E | Default browser / file manager |
| Super+H/J/K/L or arrows | Focus windows |
| Super+Ctrl+H/J/K/L | Move windows/columns |
| Super+Shift+H/L | Focus adjacent monitor |
| Super+Shift+Ctrl+H/L | Move column to adjacent monitor |
| Super+1…9 / Super+Ctrl+1…9 | Workspace / move column there |
| Super+Tab | Overview |
| Super+R | Cycle column widths |
| Super+F / Super+Shift+F | Maximize column / fullscreen |
| Super+V / Super+W | Float / tabbed column |
| Super+[ / Super+] | Stack/unstack windows |
| Super+Q | Close window |
| Super+O | Shortcut overlay |
| Super+Alt+L | Lock |
| Print / Alt+Print / Ctrl+Print | Region / window / screen capture |
| Super+Shift+E | Logout confirmation |

Idle locks after 5 minutes and turns displays off after 10; locking also runs
before sleep. Desktop helpers are supervised until Niri's IPC connection closes,
so they do not intentionally persist into another desktop session. Xwayland is
started on demand by Niri. The GTK file chooser portal avoids requiring Nautilus.

## Customize

### DankMaterialShell desktop

The supervisor starts DankMaterialShell as the desktop shell. DMS provides the
bar, wallpaper, notifications, launcher, network/audio controls and polkit dialogs.
There is no alternative shell fallback: if DMS is missing or exits, the supervisor
logs the problem and keeps idle locking active. Launcher and menu bindings call
DMS directly. After resolving a shell failure, log out and back into Niri.

To install the new dependencies on an existing setup:

```sh
sudo pacman -Syu --needed dms-shell quickshell
~/.dotfiles/install
```

Then log out and back into Niri. Do not run `dms setup` or enable its global
systemd service: this repository already owns Niri configuration and starts DMS
only for the Niri session. Super+D opens the launcher; Super+Space opens the
control centre, which provides access to settings. Super+O still shows shortcuts.

On first launch, the supervisor creates a regular, editable
`~/.config/DankMaterialShell/settings.json` with the bundled Mocha theme and
application theme generation disabled. Existing DMS settings are preserved.
Change shell preferences in DMS; they are not symlinked into this repository.
The shared theme lives in `config/DankMaterialShell/themes/mocha.json`.

Swayidle and swaylock own automatic locking and sleep
locking. Keep DMS's idle timeouts disabled to avoid competing idle handlers.
Super+Alt+L uses swaylock; DMS's own lock button uses its own lock screen.

### Shared configuration

All shared configuration lives in `config/`; helper commands live in `bin/`.
Mocha colours are explicitly recorded in the configs, and Ghostty uses its bundled
Catppuccin Mocha theme. GTK/Qt applications keep their own themes; the repo does
not install third-party application theme patches.

Copy `docs/local.kdl.example` to `~/.config/niri/local.kdl` for output scale,
keyboard layout and personal binding overrides. This optional file is read last
and never managed by the installer. Use `niri msg outputs` to identify displays.
The local include uses the standard `~/.config` path; if using `XDG_CONFIG_HOME`,
adjust that include accordingly. The installer otherwise respects XDG config and
state paths. Add shared changes to Git; keep machine-specific settings local.

## Validate and restore

```sh
niri validate -c config/niri/config.kdl
python3 -m unittest discover -s tests -v
./install --dry-run
./install --restore ~/.local/state/niri-dotfiles/backups/TRANSACTION/manifest.json
```

Rollback removes only links still pointing at the expected source and restores
the original files. It refuses to overwrite files changed independently since
installation. Restore transactions newest first; backups are private and outside
Git. Installed packages, newly created empty directories and runtime application
state are not removed. Package upgrades cannot be undone by this file rollback.

Package **names and configuration** are reproducible; exact binary versions are
not pinned on CachyOS's rolling repositories. For a precise historical rebuild,
also retain a filesystem snapshot and package cache. Inspect actual versions with
`pacman -Q`; do not replay old version numbers as an unsupported partial downgrade.

## References

- [Niri session setup](https://niri-wm.github.io/niri/Getting-Started.html)
- [Niri portals and desktop components](https://niri-wm.github.io/niri/Important-Software.html)
- [Niri config includes](https://niri-wm.github.io/niri/Configuration:-Include.html)
- [Catppuccin palette](https://catppuccin.com/palette/)
- [Omarchy](https://omarchy.org/)
- [DankMaterialShell installation](https://danklinux.com/docs/dankmaterialshell/installation)
- [DMS custom themes](https://danklinux.com/docs/dankmaterialshell/custom-themes)
