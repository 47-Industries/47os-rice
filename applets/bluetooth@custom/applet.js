const Applet = imports.ui.applet;
const PopupMenu = imports.ui.popupMenu;
const GLib = imports.gi.GLib;
const Gio = imports.gi.Gio;
const Util = imports.misc.util;
const St = imports.gi.St;

// Decode subprocess output without the deprecated Uint8Array.toString() path.
function _decode(bytes) {
    if (bytes === null || bytes === undefined) return "";
    if (typeof bytes === "string") return bytes;
    try { return new TextDecoder("utf-8").decode(bytes); }
    catch (e) { return imports.byteArray.toString(bytes); }
}

// Run a command OFF the Cinnamon main loop. Never blocks the desktop.
// Every bluetoothctl call can stall for seconds when the adapter is asleep,
// so nothing here is ever allowed to run synchronously.
function _runAsync(argv, onDone) {
    let proc;
    try {
        proc = new Gio.Subprocess({
            argv: argv,
            flags: Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_SILENCE
        });
        proc.init(null);
    } catch (e) {
        onDone("");
        return;
    }
    proc.communicate_utf8_async(null, null, (p, res) => {
        let out = "";
        try {
            let [, stdout] = p.communicate_utf8_finish(res);
            out = _decode(stdout);
        } catch (e) { out = ""; }
        onDone(out);
    });
}

// Friendly label for known device classes so an Xbox pad doesn't read as a MAC.
function _iconFor(name, icon) {
    let n = (name || "").toLowerCase();
    if (icon === "audio-headset" || icon === "audio-headphones") return "audio-headphones-symbolic";
    if (icon === "audio-card" || n.indexOf("speaker") >= 0) return "audio-speakers-symbolic";
    if (icon === "input-gaming" || n.indexOf("controller") >= 0 || n.indexOf("xbox") >= 0 ||
        n.indexOf("dualsense") >= 0 || n.indexOf("dualshock") >= 0) return "input-gaming-symbolic";
    if (icon === "input-keyboard" || n.indexOf("keyboard") >= 0) return "input-keyboard-symbolic";
    if (icon === "input-mouse" || n.indexOf("mouse") >= 0) return "input-mouse-symbolic";
    if (icon === "phone" || n.indexOf("iphone") >= 0 || n.indexOf("pixel") >= 0) return "phone-symbolic";
    return "bluetooth-symbolic";
}

class BluetoothApplet extends Applet.IconApplet {
    constructor(orientation, panelHeight, instanceId) {
        super(orientation, panelHeight, instanceId);

        this._hasAdapter = false;
        this._powered = false;
        this._devices = [];       // {mac, name, connected, icon}
        this._scanning = false;
        this._busy = false;
        this._refreshId = 0;

        this.set_applet_icon_symbolic_name("bluetooth-disabled-symbolic");
        this.set_applet_tooltip("Bluetooth");

        this.menuManager = new PopupMenu.PopupMenuManager(this);
        this.menu = new Applet.AppletPopupMenu(this, orientation);
        this.menuManager.addMenu(this.menu);

        // Warm the cache so the first click paints instantly.
        this._refresh();
        this._refreshId = GLib.timeout_add_seconds(GLib.PRIORITY_LOW, 10, () => {
            if (this.menu.isOpen || this._scanning) this._refresh();
            return GLib.SOURCE_CONTINUE;
        });
    }

    // ---------- state ----------

    _refresh() {
        _runAsync(["bluetoothctl", "show"], (out) => {
            this._hasAdapter = out.indexOf("Controller") >= 0 || out.indexOf("Powered:") >= 0;
            this._powered = /Powered:\s*yes/.test(out);
            this._updateIcon();
            if (this._hasAdapter) this._refreshDevices();
            else { this._devices = []; if (this.menu.isOpen) this._buildMenu(); }
        });
    }

    _refreshDevices() {
        _runAsync(["bluetoothctl", "devices"], (out) => {
            let devs = [];
            let lines = out.split("\n");
            for (let line of lines) {
                let m = line.match(/^Device\s+([0-9A-Fa-f:]{17})\s+(.*)$/);
                if (m) devs.push({ mac: m[1], name: m[2].trim() || m[1], connected: false, icon: "" });
            }
            this._devices = devs;
            if (devs.length === 0) { this._updateIcon(); if (this.menu.isOpen) this._buildMenu(); return; }

            let pending = devs.length;
            for (let d of devs) {
                _runAsync(["bluetoothctl", "info", d.mac], (info) => {
                    d.connected = /Connected:\s*yes/.test(info);
                    d.paired = /Paired:\s*yes/.test(info);
                    let im = info.match(/Icon:\s*(\S+)/);
                    d.icon = im ? im[1] : "";
                    if (--pending === 0) {
                        this._devices.sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name));
                        this._updateIcon();
                        if (this.menu.isOpen) this._buildMenu();
                    }
                });
            }
        });
    }

    _updateIcon() {
        let connected = this._devices.some((d) => d.connected);
        if (!this._hasAdapter) {
            this.set_applet_icon_symbolic_name("bluetooth-disabled-symbolic");
            this.set_applet_tooltip("Bluetooth: no adapter");
        } else if (!this._powered) {
            this.set_applet_icon_symbolic_name("bluetooth-disabled-symbolic");
            this.set_applet_tooltip("Bluetooth: off");
        } else if (connected) {
            this.set_applet_icon_symbolic_name("bluetooth-active-symbolic");
            let names = this._devices.filter((d) => d.connected).map((d) => d.name).join(", ");
            this.set_applet_tooltip("Bluetooth: " + names);
        } else {
            this.set_applet_icon_symbolic_name("bluetooth-active-symbolic");
            this.set_applet_tooltip("Bluetooth: on");
        }
    }

    // ---------- menu ----------

    _buildMenu() {
        this.menu.removeAll();

        let header = new PopupMenu.PopupMenuItem("Bluetooth", { reactive: false });
        header.label.set_style("font-weight: bold; font-size: 1.1em;");
        this.menu.addMenuItem(header);
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        if (!this._hasAdapter) {
            let none = new PopupMenu.PopupIconMenuItem("No Bluetooth adapter found",
                "dialog-information-symbolic", St.IconType.SYMBOLIC, { reactive: false });
            this.menu.addMenuItem(none);
            this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
            let retry = new PopupMenu.PopupIconMenuItem("Check again", "view-refresh-symbolic", St.IconType.SYMBOLIC);
            retry.connect("activate", () => this._refresh());
            this.menu.addMenuItem(retry);
            return;
        }

        // Power switch
        let sw = new PopupMenu.PopupSwitchMenuItem("Bluetooth", this._powered);
        sw.connect("toggled", (item, state) => {
            this._powered = state;
            this._updateIcon();
            // rfkill first — a soft-blocked adapter silently refuses `power on`.
            _runAsync(["sh", "-c", state
                ? "rfkill unblock bluetooth; bluetoothctl power on"
                : "bluetoothctl power off"], () => {
                GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 1, () => { this._refresh(); return GLib.SOURCE_REMOVE; });
            });
        });
        this.menu.addMenuItem(sw);
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        if (!this._powered) {
            let off = new PopupMenu.PopupMenuItem("Turn on Bluetooth to see devices", { reactive: false });
            off.label.set_style("font-size: 0.9em; opacity: 0.7;");
            this.menu.addMenuItem(off);
        } else {
            let paired = this._devices.filter((d) => d.paired !== false);
            if (paired.length === 0) {
                let none = new PopupMenu.PopupMenuItem("No paired devices", { reactive: false });
                none.label.set_style("font-size: 0.9em; opacity: 0.7;");
                this.menu.addMenuItem(none);
            }
            for (let d of paired) {
                let label = d.connected ? d.name + "  • connected" : d.name;
                let item = new PopupMenu.PopupIconMenuItem(label, _iconFor(d.name, d.icon), St.IconType.SYMBOLIC);
                if (d.connected) item.label.set_style("font-weight: bold;");
                item.connect("activate", () => {
                    let action = d.connected ? "disconnect" : "connect";
                    this.set_applet_tooltip("Bluetooth: " + action + "ing " + d.name + "…");
                    _runAsync(["bluetoothctl", action, d.mac], () => {
                        GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 1, () => { this._refresh(); return GLib.SOURCE_REMOVE; });
                    });
                });
                this.menu.addMenuItem(item);
            }

            this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

            let scanLabel = this._scanning ? "Scanning…" : "Scan for devices";
            let scan = new PopupMenu.PopupIconMenuItem(scanLabel, "edit-find-symbolic", St.IconType.SYMBOLIC);
            scan.connect("activate", () => {
                if (this._scanning) return;
                this._scanning = true;
                this._buildMenu();
                // Discoverable + pairable so a controller in pairing mode is seen.
                _runAsync(["sh", "-c",
                    "bluetoothctl --timeout 15 scan on >/dev/null 2>&1; bluetoothctl pairable on >/dev/null 2>&1"],
                    () => {
                        this._scanning = false;
                        this._refresh();
                        if (this.menu.isOpen) this._buildMenu();
                    });
            });
            this.menu.addMenuItem(scan);
        }

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        let settings = new PopupMenu.PopupIconMenuItem("Bluetooth Settings…",
            "preferences-system-symbolic", St.IconType.SYMBOLIC);
        settings.connect("activate", () => {
            // blueman-manager is the full pairing UI; fall back to Cinnamon's own panel.
            Util.spawnCommandLine("sh -c 'command -v blueman-manager >/dev/null && blueman-manager || cinnamon-settings bluetooth'");
        });
        this.menu.addMenuItem(settings);
    }

    on_applet_clicked() {
        this._buildMenu();
        this.menu.toggle();
        this._refresh();
    }

    on_applet_removed_from_panel() {
        if (this._refreshId) { GLib.source_remove(this._refreshId); this._refreshId = 0; }
    }
}

function main(metadata, orientation, panelHeight, instanceId) {
    return new BluetoothApplet(orientation, panelHeight, instanceId);
}
