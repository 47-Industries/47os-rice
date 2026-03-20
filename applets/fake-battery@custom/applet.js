const Applet = imports.ui.applet;
const PopupMenu = imports.ui.popupMenu;
const St = imports.gi.St;
const GLib = imports.gi.GLib;
const Gio = imports.gi.Gio;
const Mainloop = imports.mainloop;
const Util = imports.misc.util;

const BATTERY_PATH = "/sys/class/power_supply";
const UPDATE_INTERVAL = 30; // seconds

class BatteryApplet extends Applet.IconApplet {
    constructor(orientation, panelHeight, instanceId) {
        super(orientation, panelHeight, instanceId);

        this.menuManager = new PopupMenu.PopupMenuManager(this);
        this.menu = new Applet.AppletPopupMenu(this, orientation);
        this.menuManager.addMenu(this.menu);

        this._battery = this._findBattery();
        this._update();
        this._startTimer();
    }

    _findBattery() {
        // Look for a battery in /sys/class/power_supply/
        try {
            let dir = Gio.File.new_for_path(BATTERY_PATH);
            let enumerator = dir.enumerate_children("standard::name", Gio.FileQueryInfoFlags.NONE, null);
            let info;
            while ((info = enumerator.next_file(null)) !== null) {
                let name = info.get_name();
                let typePath = BATTERY_PATH + "/" + name + "/type";
                let [ok, contents] = GLib.file_get_contents(typePath);
                if (ok) {
                    let type = contents.toString().trim();
                    if (type === "Battery") {
                        return BATTERY_PATH + "/" + name;
                    }
                }
            }
        } catch (e) {
            // No power_supply directory or error reading it
        }
        return null;
    }

    _readFile(path) {
        try {
            let [ok, contents] = GLib.file_get_contents(path);
            if (ok) return contents.toString().trim();
        } catch (e) {}
        return null;
    }

    _getBatteryInfo() {
        if (!this._battery) return null;

        let capacity = this._readFile(this._battery + "/capacity");
        let status = this._readFile(this._battery + "/status");
        let energyNow = this._readFile(this._battery + "/energy_now");
        let energyFull = this._readFile(this._battery + "/energy_full");
        let powerNow = this._readFile(this._battery + "/power_now");

        // Some systems use charge_now/charge_full instead of energy_now/energy_full
        if (!energyNow) energyNow = this._readFile(this._battery + "/charge_now");
        if (!energyFull) energyFull = this._readFile(this._battery + "/charge_full");
        if (!powerNow) powerNow = this._readFile(this._battery + "/current_now");

        let percent = capacity ? parseInt(capacity) : 0;
        let isCharging = status === "Charging";
        let isFull = status === "Full";
        let isDischarging = status === "Discharging";
        let timeRemaining = null;

        // Calculate time remaining
        let power = powerNow ? parseInt(powerNow) : 0;
        if (power > 0) {
            let energy = energyNow ? parseInt(energyNow) : 0;
            let full = energyFull ? parseInt(energyFull) : 0;

            if (isDischarging && energy > 0) {
                let hours = energy / power;
                timeRemaining = this._formatTime(hours);
            } else if (isCharging && full > 0 && energy >= 0) {
                let hours = (full - energy) / power;
                timeRemaining = this._formatTime(hours);
            }
        }

        return {
            percent: percent,
            status: status || "Unknown",
            isCharging: isCharging,
            isFull: isFull,
            isDischarging: isDischarging,
            timeRemaining: timeRemaining
        };
    }

    _formatTime(hours) {
        if (hours <= 0) return null;
        let h = Math.floor(hours);
        let m = Math.round((hours - h) * 60);
        if (h > 0 && m > 0) return h + "h " + m + "m";
        if (h > 0) return h + "h";
        return m + "m";
    }

    _getIconName(percent, isCharging, isFull) {
        if (isFull || (isCharging && percent >= 99)) {
            return "battery-full-charged-symbolic";
        }

        let level;
        if (percent >= 80) level = "full";
        else if (percent >= 50) level = "good";
        else if (percent >= 20) level = "low";
        else if (percent >= 5) level = "caution";
        else level = "empty";

        if (isCharging) {
            return "battery-" + level + "-charging-symbolic";
        }
        return "battery-" + level + "-symbolic";
    }

    _update() {
        if (!this._battery) {
            // Desktop / no battery — show plugged-in state
            this.set_applet_icon_symbolic_name("battery-full-charged-symbolic");
            this.set_applet_tooltip("Always Plugged In — AC Power");
            return;
        }

        let info = this._getBatteryInfo();
        if (!info) {
            this.set_applet_icon_symbolic_name("battery-missing-symbolic");
            this.set_applet_tooltip("Battery not found");
            return;
        }

        // Update icon
        this.set_applet_icon_symbolic_name(
            this._getIconName(info.percent, info.isCharging, info.isFull)
        );

        // Update tooltip
        let tooltip = info.percent + "%";
        if (info.isFull) {
            tooltip += " — Fully Charged";
        } else if (info.isCharging) {
            tooltip += " — Charging";
            if (info.timeRemaining) tooltip += " (" + info.timeRemaining + " until full)";
        } else if (info.isDischarging) {
            tooltip += " — On Battery";
            if (info.timeRemaining) tooltip += " (" + info.timeRemaining + " remaining)";
        }
        this.set_applet_tooltip(tooltip);
    }

    _buildMenu() {
        this.menu.removeAll();

        // Header
        let header = new PopupMenu.PopupMenuItem("Power Status", { reactive: false });
        header.label.set_style("font-weight: bold; font-size: 1.1em;");
        this.menu.addMenuItem(header);
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        if (!this._battery) {
            // Desktop mode
            let items = [
                ["Status:", "Always Plugged In"],
                ["Power Source:", "AC Power"]
            ];
            for (let [label, value] of items) {
                let item = new PopupMenu.PopupMenuItem(label + "  " + value, { reactive: false });
                this.menu.addMenuItem(item);
            }
        } else {
            // Laptop mode — show real battery info
            let info = this._getBatteryInfo();
            if (info) {
                let statusText;
                if (info.isFull) statusText = "Fully Charged";
                else if (info.isCharging) statusText = "Charging";
                else if (info.isDischarging) statusText = "On Battery";
                else statusText = info.status;

                let items = [
                    ["Battery:", info.percent + "%"],
                    ["Status:", statusText]
                ];

                if (info.timeRemaining) {
                    if (info.isCharging) {
                        items.push(["Time to Full:", info.timeRemaining]);
                    } else if (info.isDischarging) {
                        items.push(["Time Remaining:", info.timeRemaining]);
                    }
                }

                if (info.isCharging || info.isFull) {
                    items.push(["Power Source:", "AC Power"]);
                } else {
                    items.push(["Power Source:", "Battery"]);
                }

                for (let [label, value] of items) {
                    let item = new PopupMenu.PopupMenuItem(label + "  " + value, { reactive: false });
                    this.menu.addMenuItem(item);
                }
            }
        }

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        // Power settings button
        let settingsItem = new PopupMenu.PopupMenuItem("Power Settings...");
        settingsItem.connect("activate", () => {
            Util.spawnCommandLine("cinnamon-settings power");
        });
        this.menu.addMenuItem(settingsItem);
    }

    _startTimer() {
        this._timerId = Mainloop.timeout_add_seconds(UPDATE_INTERVAL, () => {
            this._update();
            return true; // keep repeating
        });
    }

    on_applet_clicked() {
        this._update(); // refresh before showing
        this._buildMenu();
        this.menu.toggle();
    }

    on_applet_removed_from_panel() {
        if (this._timerId) {
            Mainloop.source_remove(this._timerId);
            this._timerId = null;
        }
    }
}

function main(metadata, orientation, panelHeight, instanceId) {
    return new BatteryApplet(orientation, panelHeight, instanceId);
}
