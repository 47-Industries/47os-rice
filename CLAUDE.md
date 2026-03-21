# 47 OS Rice — Project Instructions

## Who You're Working With
Dean Sabr, 23, CEO of 47 Industries LLC. Self-taught developer and Linux enthusiast. Building a premium macOS-clone rice for Linux Mint Cinnamon that can be installed with a single command or distributed as a bootable ISO.

## What This Project Is
47 OS is a comprehensive Linux Mint Cinnamon desktop customization ("rice") designed to look and feel like macOS. It includes a WhiteSur-Dark GTK theme, SF Pro fonts, Plank dock, custom Cinnamon applets and extensions, a full UI sound system with lightsaber drag effects, Spotlight-style search, window transparency toggle, and macOS-style animations. The entire rice is packaged as an 800+ line installer script (`install.sh`) that transforms stock Linux Mint into the full 47 Industries branded desktop.

## Critical Decisions Already Made (DO NOT revisit)
- **Linux Mint Cinnamon** is the base (not Hyprland, GNOME, or KDE)
- **WhiteSur-Dark** is the GTK theme (bundled as tarball, not built from source)
- **Brave** replaces Firefox as the default browser (with Safari icon swap)
- **dconf/gsettings must NEVER be modified during a live Cinnamon session** — always defer to first-login apply script (live dconf changes crash Cinnamon)
- **dconf binary** from live system is the source of truth (not compiled from INI)
- **Theme enforcement script** runs on every login as belt-and-suspenders
- **Ghost Mode VPN applet** was removed — users install their own VPN
- **Glide animation** is used for all window open/close types (consistent)
- **Trash lives in Plank dock**, not on the desktop (macOS-style)

## Tech Stack
| Component | Technology |
|-----------|-----------|
| Base OS | Linux Mint (Cinnamon Desktop) |
| GTK Theme | WhiteSur-Dark (macOS clone, bundled tarball) |
| Icon Theme | WhiteSur-dark icons |
| Cursors | WhiteSur-cursors + Oxy-neon-large |
| Fonts | SF Pro Display / SF Pro Text / Octosquares |
| Dock | Plank (macOS-style, bottom, zoom 175%) |
| Terminal | Alacritty (neon cyan theme) |
| Launcher/Search | Rofi (Spotlight-style search) |
| Transparency | Devilspie2 + custom 47glass toggle system |
| Window Effects | Compiz-windows-effect (wobbly), BurnMyWindows (Glide), MagicLamp (Genie minimize) |
| Browser | Brave (with Safari icon swap) |
| Login Screen | web-greeter with custom 47-macos theme |
| Boot Splash | Plymouth with 47 logo animation |
| Clipboard | CopyQ |
| Touchpad | libinput-gestures |
| Key Bindings | xbindkeys |
| Installer | Bash (`install.sh`, 800+ lines, 16 steps) |

## What's Been Built

### Custom Cinnamon Applets (6)
- `brightness@custom` — brightness slider
- `fake-battery@custom` — macOS-style battery icon (handles desktop PCs)
- `fake-wifi@custom` — macOS-style WiFi icon
- `47sound@custom` — custom sound volume applet
- `vpn-toggle@custom` — VPN toggle (removed from default install)
- `sound@cinnamon.org` — modified stock applet with 47 Sounds slider built in

### Custom Cinnamon Extensions (3)
- `compiz-windows-effect@hermes83.github.com` — wobbly/jelly windows
- `CinnamonBurnMyWindows@klangman` — macOS-style window open/close (Glide)
- `CinnamonMagicLamp@klangman` — macOS Genie minimize effect

### Custom Scripts (~29)
- **Transparency:** `47glass-inject.sh`, `toggle-transparency.sh`, `47transparency`
- **Sound System:** `47sound`, `47sound-inject.sh`, `saber-drag.sh`, `swoosh-watcher.sh`, `window-close-sound.py`, `window-state-sound.py`
- **macOS Features:** `spotlight-search.sh`, `screenshot-float.sh`, `force-quit.sh`, `about-47os.sh`, `pip-toggle.sh`, `powermenu.sh`
- **Window Management:** `close-window.sh`, `maximize-window.sh`, `minimize-window.sh`, `fullscreen-toggle.sh`, `lock-screen.sh`
- **System:** `matrix-47.py`, `dynamic-wallpaper.sh`, `battery-monitor.sh`, `brightness-tracker.sh`, `volume-tracker.sh`, `launch-terminal.sh`, `app-search.sh`

### Sound System
- 23 drag/swoosh/saber sound files in `assets/sounds/drag/`
- 12 UI sounds (close, maximize, minimize, transparency, terminal enter, etc.) in `assets/sounds/ui/`

### Browser Extension
- Custom CSS for Discord, GitHub, Google, Reddit, SoundCloud, Spotify, Twitter, YouTube
- Tab open/close sounds

### System-Level
- Plymouth boot splash (47 logo animation)
- GRUB instant boot + 47 OS branding
- LightDM custom login (slick-greeter + web-greeter with 47-macos theme)
- dconf system defaults, gschema override
- Theme enforcement via `/etc/xdg/autostart/`

### Installer (`install.sh`)
- 16-step automated installer
- Full backup before changes (`~/.47os-backup/`)
- Uninstall script (`uninstall.sh`)
- First-login apply script (defers dconf to avoid crashing Cinnamon)
- Safe gsettings wrapper, progress bar, error counting

## Project File Map
```
~/Desktop/Ideas/47os-rice/
├── install.sh                      # Main installer (800+ lines, 16 steps)
├── uninstall.sh                    # Full uninstaller
├── applets/                        # Custom Cinnamon panel applets
│   ├── 47sound@custom/
│   ├── brightness@custom/
│   ├── fake-battery@custom/
│   ├── fake-wifi@custom/
│   ├── sound@cinnamon.org/         # Modified stock applet w/ 47 Sounds
│   └── vpn-toggle@custom/
├── assets/
│   ├── cursors/                    # Oxy-neon-large cursor theme
│   ├── fonts/                      # SF Pro Display/Text/Rounded, Octosquares
│   ├── icons/                      # macOS-style SVG icons
│   ├── images/                     # 47 logos, panel icon, wallpaper
│   ├── sounds/drag/                # 23 lightsaber/swoosh sound files
│   ├── sounds/ui/                  # 12 UI event sounds
│   ├── theme-patches/              # Opaque/translucent CSS + SVG patches
│   └── whitesur-dark-theme.tar.gz  # Bundled GTK theme
├── browser-extension/              # Custom CSS for web apps + tab sounds
├── config/
│   ├── alacritty/                  # Terminal config (neon cyan)
│   ├── autostart/                  # 14 autostart .desktop entries
│   ├── cinnamon/                   # Applet/extension config JSONs
│   ├── dconf/                      # dconf INI + binary
│   ├── devilspie2/                 # Window transparency rules
│   ├── fastfetch/                  # System info config
│   ├── gtk-3.0/                    # GTK CSS overrides
│   ├── plank-launchers/            # Dock items
│   ├── rofi/                       # Spotlight search theme
│   └── xbindkeysrc                 # Keybinding config
├── extensions/                     # Cinnamon extensions (3)
│   ├── CinnamonBurnMyWindows@klangman/
│   ├── CinnamonMagicLamp@klangman/
│   └── compiz-windows-effect@hermes83.github.com/
├── scripts/                        # All custom scripts (~29)
└── system/
    ├── 47os-force-theme.sh         # Login theme enforcement
    ├── dconf/                      # System-wide dconf defaults
    ├── lightdm/                    # Login screen configs
    ├── plymouth/47-logo/           # Boot splash animation frames
    ├── schemas/                    # GSchema override
    └── web-greeter/themes/47-macos/ # Custom login theme
```

## Related Artifacts
- **ISO builds:** `~/Desktop/Ideas/47 OS/47os-build/` (two ISOs, ~3.5GB and ~3.2GB, from March 8-10)
- **Website:** `~/Desktop/Ideas/47os-website/` (Node.js server)
- **GitHub:** https://github.com/phantom47m/47os-rice.git (branch: `master`)

## Known Issues / Gotchas
- **NEVER modify dconf during a live Cinnamon session** — it will crash the desktop and break the panel. Always defer to first-login script.
- Window border/shadow CSS was reverted (was breaking title bars)
- ISOs are outdated — built before many recent install.sh improvements
- The dconf binary from a live configured system is the single source of truth

## Current Status
- Install script is working and tested in VM
- Most recent work (March 20): removed Ghost Mode VPN, added BurnMyWindows Glide animations, fixed battery applet USB detection, added Spotlight search, force quit, About dialog, PiP, clipboard manager, trash in dock, Safari icon for Brave

## Session Workflow
After finishing work, append a brief summary to `SESSION_LOG.md` with:
- Date
- What was done
- What's next
- Any new decisions or discoveries
