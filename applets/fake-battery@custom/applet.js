const Applet = imports.ui.applet;
const PopupMenu = imports.ui.popupMenu;
const St = imports.gi.St;
const GLib = imports.gi.GLib;
const Gio = imports.gi.Gio;
const Mainloop = imports.mainloop;
const Util = imports.misc.util;

const BATTERY_PATH = "/sys/class/power_supply";
const UPDATE_INTERVAL = 15;   // seconds

class BatteryApplet extends Applet.TextIconApplet {
    constructor(orientation, panelHeight, instanceId) {
        super(orientation, panelHeight, instanceId);

        this.menuManager = new PopupMenu.PopupMenuManager(this);
        this.menu = new Applet.AppletPopupMenu(this, orientation);
        this.menuManager.addMenu(this.menu);

        this._battery = this._findBattery();
        this._charged = false;
        this._pulseId = 0;
        this._timerId = 0;
        this._saver = this._readMode() === "saver";

        this._update();
        this._startTimer();
    }

    // ------------------------------------------------------------- reading --

    _findBattery() {
        try {
            let dir = Gio.File.new_for_path(BATTERY_PATH);
            let enumerator = dir.enumerate_children("standard::name", Gio.FileQueryInfoFlags.NONE, null);
            let info;
            while ((info = enumerator.next_file(null)) !== null) {
                let name = info.get_name();
                if (!name.match(/^BAT[0-9]/)) continue;
                let typePath = BATTERY_PATH + "/" + name + "/type";
                let [ok, contents] = GLib.file_get_contents(typePath);
                if (ok && this._decode(contents).trim() === "Battery") {
                    return BATTERY_PATH + "/" + name;
                }
            }
        } catch (e) {}
        return null;
    }

    _decode(bytes) {
        if (bytes === null || bytes === undefined) return "";
        if (typeof bytes === "string") return bytes;
        try { return new TextDecoder("utf-8").decode(bytes); }
        catch (e) { return imports.byteArray.toString(bytes); }
    }

    _readFile(path) {
        try {
            let [ok, contents] = GLib.file_get_contents(path);
            if (ok) return this._decode(contents).trim();
        } catch (e) {}
        return null;
    }

    _readMode() {
        let p = GLib.get_home_dir() + "/.config/47industries/power-mode";
        let v = this._readFile(p);
        return v || "balanced";
    }

    _getBatteryInfo() {
        if (!this._battery) return null;

        let capacity  = this._readFile(this._battery + "/capacity");
        let status    = this._readFile(this._battery + "/status");
        let energyNow = this._readFile(this._battery + "/energy_now")  || this._readFile(this._battery + "/charge_now");
        let energyFul = this._readFile(this._battery + "/energy_full") || this._readFile(this._battery + "/charge_full");
        let powerNow  = this._readFile(this._battery + "/power_now")   || this._readFile(this._battery + "/current_now");
        let design    = this._readFile(this._battery + "/energy_full_design") || this._readFile(this._battery + "/charge_full_design");

        let percent = capacity ? parseInt(capacity) : 0;
        let isCharging = status === "Charging";
        let isFull = status === "Full";
        let isDischarging = status === "Discharging";
        let timeRemaining = null;

        let power = powerNow ? parseInt(powerNow) : 0;
        if (power > 0) {
            let energy = energyNow ? parseInt(energyNow) : 0;
            let full = energyFul ? parseInt(energyFul) : 0;
            if (isDischarging && energy > 0) timeRemaining = this._formatTime(energy / power);
            else if (isCharging && full > 0 && energy >= 0) timeRemaining = this._formatTime((full - energy) / power);
        }

        // Battery health: how much of the original capacity is left.
        let health = null;
        if (energyFul && design) {
            let f = parseInt(energyFul), d = parseInt(design);
            if (d > 0) health = Math.round((f / d) * 100);
        }

        // Live draw in watts (power_now is µW on energy_* systems).
        let watts = null;
        if (power > 0 && energyNow && this._readFile(this._battery + "/power_now")) {
            watts = (power / 1000000).toFixed(1);
        }

        return { percent, status: status || "Unknown", isCharging, isFull, isDischarging,
                 timeRemaining, health, watts };
    }

    _formatTime(hours) {
        if (!isFinite(hours) || hours <= 0) return null;
        let h = Math.floor(hours);
        let m = Math.round((hours - h) * 60);
        if (m === 60) { h += 1; m = 0; }
        if (h > 0 && m > 0) return h + "h " + m + "m";
        if (h > 0) return h + "h";
        return m + "m";
    }

    _getIconName(percent, isCharging, isFull) {
        if (isFull || (isCharging && percent >= 99)) return "battery-full-charged-symbolic";
        let level;
        if (percent >= 80) level = "full";
        else if (percent >= 50) level = "good";
        else if (percent >= 20) level = "low";
        else if (percent >= 5) level = "caution";
        else level = "empty";
        return isCharging ? "battery-" + level + "-charging-symbolic" : "battery-" + level + "-symbolic";
    }

    // ------------------------------------------------------------- painting --

    // Charging = solid green. No breathing, no animation.
    //
    // Dean called the pulse ugly (2026-09-05) and he was right twice over.
    // Aesthetically: a panel element that moves in the corner of your eye is a
    // distraction, not information. Technically: it was a Mainloop timer firing
    // every 900ms forever, waking the CPU ~4000 times an hour to repaint a
    // colour that is now constant — on the exact laptop we are trying to squeeze
    // five hours out of. The state is static, so the paint is a one-shot.
    _startPulse() {
        if (this._charged) return;
        this._charged = true;
        try {
            this._applet_icon.set_style("color: #4ade80;");
            this._applet_label.set_style("color: #4ade80; font-weight: bold;");
        } catch (e) {}
    }

    _stopPulse() {
        this._charged = false;
        if (this._pulseId) { Mainloop.source_remove(this._pulseId); this._pulseId = 0; }
        try {
            this._applet_icon.set_style("");
            this._applet_label.set_style(this._saver ? "color: #fbbf24;" : "");
        } catch (e) {}
    }

    _update() {
        this._saver = this._readMode() === "saver";

        if (!this._battery) {
            this._stopPulse();
            this.set_applet_icon_symbolic_name("battery-full-charged-symbolic");
            this.set_applet_label("");
            this.set_applet_tooltip("Always Plugged In — AC Power");
            return;
        }

        let info = this._getBatteryInfo();
        if (!info) {
            this._stopPulse();
            this.set_applet_icon_symbolic_name("battery-missing-symbolic");
            this.set_applet_label("");
            this.set_applet_tooltip("Battery not found");
            return;
        }

        this.set_applet_icon_symbolic_name(this._getIconName(info.percent, info.isCharging, info.isFull));

        // The label carries the state at a glance: bolt while charging,
        // leaf while in battery saver.
        let label = "";
        // No text bolt: getIconName() already returns battery-<level>-charging-symbolic,
        // which draws the bolt INSIDE the icon. A second standalone bolt was redundant.
        if (info.isCharging)      label = info.percent + "%";
        else if (info.isFull)     label = info.percent + "%";
        else                      label = info.percent + "%";
        if (this._saver && !info.isCharging) label = "ECO " + info.percent + "%";
        this.set_applet_label(label);

        if (info.isCharging) this._startPulse(); else this._stopPulse();

        let tooltip = info.percent + "%";
        if (info.isFull) tooltip += " — Fully Charged";
        else if (info.isCharging) {
            tooltip += " — Charging";
            if (info.timeRemaining) tooltip += " (" + info.timeRemaining + " until full)";
        } else if (info.isDischarging) {
            tooltip += " — On Battery";
            if (info.timeRemaining) tooltip += " (" + info.timeRemaining + " left)";
        }
        if (this._saver) tooltip += "  •  Battery Saver ON";
        this.set_applet_tooltip(tooltip);
    }

    // ---------------------------------------------------------------- menu --

    _buildMenu() {
        this.menu.removeAll();

        let header = new PopupMenu.PopupMenuItem("Power", { reactive: false });
        header.label.set_style("font-weight: bold; font-size: 1.1em;");
        this.menu.addMenuItem(header);
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        if (!this._battery) {
            this.menu.addMenuItem(new PopupMenu.PopupMenuItem("Status:  Always Plugged In", { reactive: false }));
            this.menu.addMenuItem(new PopupMenu.PopupMenuItem("Power Source:  AC Power", { reactive: false }));
        } else {
            let info = this._getBatteryInfo();
            if (info) {
                let statusText = info.isFull ? "Fully Charged"
                               : info.isCharging ? "Charging"
                               : info.isDischarging ? "On Battery" : info.status;

                let items = [["Battery:", info.percent + "%"], ["Status:", statusText]];
                if (info.timeRemaining) {
                    items.push([info.isCharging ? "Time to Full:" : "Time Remaining:", info.timeRemaining]);
                }
                if (info.watts) items.push(["Drawing:", info.watts + " W"]);
                if (info.health !== null) items.push(["Battery Health:", info.health + "%"]);
                items.push(["Power Source:", (info.isCharging || info.isFull) ? "AC Power" : "Battery"]);

                for (let [label, value] of items) {
                    this.menu.addMenuItem(new PopupMenu.PopupMenuItem(label + "  " + value, { reactive: false }));
                }
            }

            this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

            // The toggle Dean asked for.
            let saverSwitch = new PopupMenu.PopupSwitchMenuItem("Battery Saver", this._saver);
            saverSwitch.connect("toggled", (item, state) => {
                this._saver = state;
                Util.spawnCommandLine("47os-powermode " + (state ? "saver" : "balanced"));
                // sysfs + gsettings take a beat to settle before the label is right.
                Mainloop.timeout_add_seconds(2, () => { this._update(); return false; });
            });
            this.menu.addMenuItem(saverSwitch);

            let hint = new PopupMenu.PopupMenuItem(
                this._saver ? "Turbo off, effects parked, screen dimmed"
                            : "Trades speed and effects for runtime",
                { reactive: false });
            hint.label.set_style("font-size: 0.85em; opacity: 0.65;");
            this.menu.addMenuItem(hint);
        }

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        let settingsItem = new PopupMenu.PopupIconMenuItem("Power Settings…",
            "preferences-system-symbolic", St.IconType.SYMBOLIC);
        settingsItem.connect("activate", () => { Util.spawnCommandLine("cinnamon-settings power"); });
        this.menu.addMenuItem(settingsItem);
    }

    _startTimer() {
        this._timerId = Mainloop.timeout_add_seconds(UPDATE_INTERVAL, () => {
            this._update();
            if (this.menu.isOpen) this._buildMenu();
            return true;
        });
    }

    on_applet_clicked() {
        this._update();
        this._buildMenu();
        this.menu.toggle();
    }

    on_applet_removed_from_panel() {
        if (this._timerId) { Mainloop.source_remove(this._timerId); this._timerId = 0; }
        if (this._pulseId) { Mainloop.source_remove(this._pulseId); this._pulseId = 0; }
    }
}

function main(metadata, orientation, panelHeight, instanceId) {
    return new BatteryApplet(orientation, panelHeight, instanceId);
}
