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

class FakeWifiApplet extends Applet.IconApplet {
    constructor(orientation, panelHeight, instanceId) {
        super(orientation, panelHeight, instanceId);
        this.set_applet_icon_symbolic_name("network-wireless-signal-excellent-symbolic");
        this.set_applet_tooltip("Wi-Fi");

        this.menuManager = new PopupMenu.PopupMenuManager(this);
        this.menu = new Applet.AppletPopupMenu(this, orientation);
        this.menuManager.addMenu(this.menu);

        // Cached state — the menu paints from this instantly.
        this._netInfo = { connections: [], ip: null };
        this._networks = null;   // null = never scanned yet
        this._scanning = false;
        this._refreshId = 0;

        // Warm the cache in the background so the very first click is instant too.
        this._refreshAll();
        // Keep it warm while idle; costs nothing on the main loop.
        this._refreshId = GLib.timeout_add_seconds(GLib.PRIORITY_LOW, 30, () => {
            if (this.menu.isOpen) this._refreshAll();
            return GLib.SOURCE_CONTINUE;
        });
    }

    _refreshAll() {
        this._refreshNetInfo();
        this._refreshNetworks();
    }

    _refreshNetInfo() {
        _runAsync(["nmcli", "-t", "-f", "NAME,TYPE,DEVICE", "connection", "show", "--active"], (out) => {
            let conns = [];
            for (let line of out.trim().split("\n")) {
                if (!line) continue;
                let parts = line.split(":");
                conns.push({ name: parts[0], type: parts[1], device: parts[2] });
            }
            this._netInfo.connections = conns;
            this._repaintIfOpen();
        });
        _runAsync(["hostname", "-I"], (out) => {
            this._netInfo.ip = out.trim().split(" ")[0] || null;
            this._repaintIfOpen();
        });
    }

    _refreshNetworks() {
        if (this._scanning) return;
        this._scanning = true;
        _runAsync(["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY", "device", "wifi", "list"], (out) => {
            let nets = [];
            let seen = {};
            for (let line of out.trim().split("\n")) {
                if (!line) continue;
                let parts = line.split(":");
                let ssid = parts[0];
                if (ssid && !seen[ssid]) {
                    seen[ssid] = true;
                    nets.push({ ssid: ssid, signal: parts[1] || "?", security: parts[2] || "" });
                }
            }
            this._networks = nets;
            this._scanning = false;
            this._repaintIfOpen();
        });
    }

    _repaintIfOpen() {
        if (this.menu.isOpen) this._buildMenu();
    }

    _buildMenu() {
        this.menu.removeAll();

        let header = new PopupMenu.PopupMenuItem("Wi-Fi", { reactive: false });
        header.label.set_style("font-weight: bold; font-size: 1.1em;");
        this.menu.addMenuItem(header);
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        for (let conn of this._netInfo.connections) {
            let icon = conn.type === "802-11-wireless"
                ? "network-wireless-signal-excellent-symbolic"
                : "network-wired-symbolic";
            let item = new PopupMenu.PopupIconMenuItem(
                conn.name + "  (" + conn.device + ")", icon, St.IconType.SYMBOLIC, { reactive: false });
            this.menu.addMenuItem(item);
        }
        if (this._netInfo.connections.length === 0) {
            this.menu.addMenuItem(new PopupMenu.PopupMenuItem("No active connections", { reactive: false }));
        }

        this.menu.addMenuItem(new PopupMenu.PopupMenuItem(
            "IP: " + (this._netInfo.ip || "…"), { reactive: false }));

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        let wifiHeader = new PopupMenu.PopupMenuItem("Available Networks", { reactive: false });
        wifiHeader.label.set_style("font-weight: bold;");
        this.menu.addMenuItem(wifiHeader);

        if (this._networks === null) {
            this.menu.addMenuItem(new PopupMenu.PopupMenuItem("Scanning…", { reactive: false }));
        } else if (this._networks.length === 0) {
            this.menu.addMenuItem(new PopupMenu.PopupMenuItem("No Wi-Fi networks found", { reactive: false }));
        } else {
            for (let net of this._networks.slice(0, 10)) {
                let signalNum = parseInt(net.signal) || 0;
                let signalIcon;
                if (signalNum >= 75) signalIcon = "network-wireless-signal-excellent-symbolic";
                else if (signalNum >= 50) signalIcon = "network-wireless-signal-good-symbolic";
                else if (signalNum >= 25) signalIcon = "network-wireless-signal-ok-symbolic";
                else signalIcon = "network-wireless-signal-weak-symbolic";

                let label = net.ssid + "  " + net.signal + "%";
                if (net.security && net.security !== "--") label += "  🔒";

                let item = new PopupMenu.PopupIconMenuItem(label, signalIcon, St.IconType.SYMBOLIC);
                let ssid = net.ssid;
                item.connect("activate", () => {
                    Util.spawn(["nmcli", "device", "wifi", "connect", ssid]);
                });
                this.menu.addMenuItem(item);
            }
        }

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        let rescan = new PopupMenu.PopupMenuItem("Rescan");
        rescan.connect("activate", () => { this._networks = null; this._refreshAll(); });
        this.menu.addMenuItem(rescan);

        let settingsItem = new PopupMenu.PopupMenuItem("Network Settings...");
        settingsItem.connect("activate", () => { Util.spawnCommandLine("cinnamon-settings network"); });
        this.menu.addMenuItem(settingsItem);
    }

    on_applet_clicked() {
        // Paint from cache immediately, then refresh in the background.
        this._buildMenu();
        this.menu.toggle();
        if (this.menu.isOpen) this._refreshAll();
    }

    on_applet_removed_from_panel() {
        if (this._refreshId) { GLib.source_remove(this._refreshId); this._refreshId = 0; }
    }
}

function main(metadata, orientation, panelHeight, instanceId) {
    return new FakeWifiApplet(orientation, panelHeight, instanceId);
}
