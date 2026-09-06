<div align="center">

# 47os-rice

**Transform Linux Mint Cinnamon into 47 OS -- Genesis Edition**

![Bash](https://img.shields.io/badge/Bash-installer-4EAA25?style=flat-square&logo=gnu-bash&logoColor=white)
![Linux Mint](https://img.shields.io/badge/Linux_Mint-Cinnamon-87CF3E?style=flat-square&logo=linux-mint&logoColor=white)
![macOS](https://img.shields.io/badge/Style-macOS_Sonoma-000000?style=flat-square&logo=apple&logoColor=white)

One script &bull; Full desktop rice &bull; macOS-quality UI &bull; Custom applets &bull; Sound system

</div>

---

A comprehensive Linux Mint Cinnamon desktop customization that transforms stock Linux Mint into a premium macOS-style desktop with a single install command. Includes WhiteSur-Dark GTK theme, SF Pro fonts, Plank dock, custom Cinnamon applets, lightsaber drag sounds, Spotlight-style search, window transparency toggle, and macOS-style animations. Packaged as an 800+ line installer script.

| | |
|---|---|
| **Status** | Production |
| **Developer** | 47 Industries LLC |
| **Base OS** | Linux Mint (Cinnamon Desktop) |
| **Installer** | Single Bash script (800+ lines, 16 steps) |

## Install

```bash
sudo apt install git -y && git clone https://github.com/phantom47m/47os-rice.git && cd 47os-rice && bash install.sh
```

## What You Get

- **WhiteSur-Dark** GTK theme (macOS Sonoma look)
- **SF Pro** fonts throughout the system
- **Plank dock** with macOS-style zoom and trash
- **Spotlight-style search** via Rofi (Cmd+Space)
- **macOS window animations** -- Glide open/close, Genie minimize, wobbly drag
- **Lightsaber drag sounds** and full UI sound system
- **Custom login screen** (macOS-style web-greeter theme)
- **47 Industries boot splash** (Plymouth)
- **Brave browser** with Safari icon
- **Alacritty terminal** with neon cyan theme
- **Window transparency toggle** (Ctrl+Alt+G)
- **Custom Cinnamon applets** (brightness, fake battery, fake WiFi, 47 sound)
- Force Quit, PiP, About dialog, and more

## Uninstall

```bash
cd ~/Desktop/47os-rice && bash uninstall.sh
```

## License

Proprietary -- 47 Industries LLC. All rights reserved.

## Contact

**47 Industries LLC**
[47industries.com](https://47industries.com) | hello@47industries.com

## When it freezes

A hard lockup writes nothing to disk. That is why "it froze again" has never
come with any evidence — the kernel never gets to flush a log and journald
never gets to fsync, so after you hold the power button there is nothing to
read. 47OS records the state continuously instead.

    47os-freeze report      what the machine was doing when it last died
    47os-freeze status      is the recorder running, is the guard on

The recorder (`47os-blackbox`, a systemd service) writes one line every two
seconds and fsyncs it: power source, battery, CPU governor and clock, package
temperature, discrete-GPU runtime state, PCIe ASPM policy, load. On a clean
shutdown it writes a CLEAN_STOP marker. **A session that ends without that
marker is a session the machine did not survive**, and the last line is the
state one heartbeat before it went down.

If the report points at power management:

    sudo 47os-freeze guard on     conservative PCIe/runtime power, no reboot
    sudo 47os-freeze guard deep   also disables ASPM and panel self-refresh
    sudo 47os-freeze guard off    back to stock

And when it locks up, you do not have to hold the power button. SysRq is
enabled: hold **Alt+SysRq** and press **R E I S U B**, one letter a second.
That syncs your disks and reboots cleanly even with the desktop dead.
