const Applet = imports.ui.applet;
const PopupMenu = imports.ui.popupMenu;
const GLib = imports.gi.GLib;
const Mainloop = imports.mainloop;
const Util = imports.misc.util;
const St = imports.gi.St;
const Slider = imports.ui.slider;

class BrightnessApplet extends Applet.IconApplet {
    constructor(orientation, panelHeight, instanceId) {
        super(orientation, panelHeight, instanceId);

        let iconPath = GLib.build_filenamev([GLib.get_home_dir(), ".local/share/cinnamon/applets/brightness@custom/brightness-icon.png"]);
        this.set_applet_icon_path(iconPath);
        this.set_applet_tooltip("Brightness");

        this.menuManager = new PopupMenu.PopupMenuManager(this);
        this.menu = new Applet.AppletPopupMenu(this, orientation);
        this.menuManager.addMenu(this.menu);

        this._screenBrightness = 1.0;
        this._getScreenBrightness();
    }

    _getScreenBrightness() {
        try {
            let [ok, out] = GLib.spawn_command_line_sync("xrandr --verbose");
            let output = out.toString();
            let match = output.match(/Brightness:\s*([\d.]+)/);
            if (match) {
                this._screenBrightness = parseFloat(match[1]);
            }
        } catch (e) {}
    }

    _setScreenBrightness(value) {
        this._screenBrightness = value;
        // Get connected display name
        try {
            let [ok, out] = GLib.spawn_command_line_sync("xrandr --query");
            let lines = out.toString().split("\n");
            for (let line of lines) {
                if (line.indexOf(" connected") >= 0) {
                    let display = line.split(" ")[0];
                    Util.spawnCommandLine("xrandr --output " + display + " --brightness " + value.toFixed(2));
                }
            }
        } catch (e) {}
    }

    _buildMenu() {
        this.menu.removeAll();

        // Header
        let header = new PopupMenu.PopupMenuItem("Brightness", { reactive: false });
        header.label.set_style("font-weight: bold; font-size: 1.1em;");
        this.menu.addMenuItem(header);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        // Screen brightness label
        let screenLabel = new PopupMenu.PopupMenuItem("Screen Brightness", { reactive: false });
        this.menu.addMenuItem(screenLabel);

        // Screen brightness slider
        let screenSliderItem = new PopupMenu.PopupBaseMenuItem({ activate: false });
        let screenSlider = new Slider.Slider(this._screenBrightness);
        screenSlider.connect("value-changed", (slider, value) => {
            let brightness = Math.max(0.1, value);
            this._setScreenBrightness(brightness);
        });
        screenSliderItem.addActor(screenSlider.actor, { expand: true });
        this.menu.addMenuItem(screenSliderItem);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        // Keyboard brightness label
        let kbLabel = new PopupMenu.PopupMenuItem("Keyboard Brightness", { reactive: false });
        this.menu.addMenuItem(kbLabel);

        // Keyboard brightness slider
        let kbSliderItem = new PopupMenu.PopupBaseMenuItem({ activate: false });
        let kbSlider = new Slider.Slider(0.5);
        kbSlider.connect("value-changed", (slider, value) => {
            // Most desktop PCs don't have keyboard backlight, but if they do:
            let level = Math.round(value * 3);
            Util.spawnCommandLine("bash -c 'echo " + level + " | sudo tee /sys/class/leds/*/brightness 2>/dev/null'");
        });
        kbSliderItem.addActor(kbSlider.actor, { expand: true });
        this.menu.addMenuItem(kbSliderItem);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        // Quick presets
        let presetsHeader = new PopupMenu.PopupMenuItem("Quick Presets", { reactive: false });
        presetsHeader.label.set_style("font-weight: bold;");
        this.menu.addMenuItem(presetsHeader);

        let presets = [
            { name: "25%", value: 0.25 },
            { name: "50%", value: 0.50 },
            { name: "75%", value: 0.75 },
            { name: "100%", value: 1.00 },
        ];

        for (let preset of presets) {
            let item = new PopupMenu.PopupMenuItem(preset.name);
            let val = preset.value;
            item.connect("activate", () => {
                this._setScreenBrightness(val);
            });
            this.menu.addMenuItem(item);
        }

        // Night mode toggle
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        let nightItem = new PopupMenu.PopupMenuItem("Night Mode (Warm)");
        nightItem.connect("activate", () => {
            Util.spawnCommandLine("bash -c 'xrandr --output $(xrandr --query | grep \" connected\" | head -1 | cut -d\" \" -f1) --gamma 1.0:0.85:0.7'");
        });
        this.menu.addMenuItem(nightItem);

        let normalItem = new PopupMenu.PopupMenuItem("Normal Colors");
        normalItem.connect("activate", () => {
            Util.spawnCommandLine("bash -c 'xrandr --output $(xrandr --query | grep \" connected\" | head -1 | cut -d\" \" -f1) --gamma 1.0:1.0:1.0'");
        });
        this.menu.addMenuItem(normalItem);

        // 47 Glass - Transparency slider
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        let glassHeader = new PopupMenu.PopupMenuItem("47 Glass", { reactive: false });
        glassHeader.label.set_style("font-weight: bold;");
        this.menu.addMenuItem(glassHeader);

        let glassItem = new PopupMenu.PopupBaseMenuItem({ activate: false });
        let glassBox = new St.BoxLayout({ vertical: false });

        let glassLabel = new St.Label({ text: "50%" });
        glassLabel.set_style("min-width: 40px; padding-right: 8px;");
        glassBox.add_actor(glassLabel);

        // Read saved level
        let glassLevel = 50;
        try {
            let tPath = GLib.build_filenamev([GLib.get_home_dir(), ".config/47industries/transparency-level"]);
            let [ok2, raw2] = GLib.file_get_contents(tPath);
            glassLevel = parseInt(raw2.toString().trim()) || 50;
        } catch(ex) {}

        let glassSlider = new Slider.Slider(glassLevel / 100);
        glassLabel.set_text(glassLevel + "%");
        glassSlider.connect("value-changed", (slider, value) => {
            let lv = Math.round(value * 100);
            glassLabel.set_text(lv + "%");
            // Debounce: wait 300ms after user stops dragging before applying
            if (this._glassDebounce) {
                Mainloop.source_remove(this._glassDebounce);
                this._glassDebounce = null;
            }
            this._glassDebounce = Mainloop.timeout_add(300, () => {
                this._glassDebounce = null;
                GLib.spawn_command_line_async(GLib.get_home_dir() + "/.local/bin/47transparency set " + lv);
                return false;
            });
        });
        glassBox.add(glassSlider.actor, { expand: true });

        glassItem.addActor(glassBox, { expand: true, span: -1 });
        this.menu.addMenuItem(glassItem);

        // Make popup translucent if transparency is on
        try {
            let [ok3, raw3] = GLib.file_get_contents("/tmp/transparency_state");
            let tState = raw3.toString().trim();
            if (tState === "on") {
                this.menu.actor.set_style("background-color: rgba(15, 15, 15, 0.15); border: 1px solid rgba(255,255,255,0.1); border-radius: 12px; border-image: none;");
                let mc = this.menu.actor.get_children();
                for (let j = 0; j < mc.length; j++) {
                    mc[j].set_style("background-color: transparent; border-image: none;");
                }
            }
        } catch(ex) {}
    }

    on_applet_clicked() {
        this._getScreenBrightness();
        this._buildMenu();
        this.menu.toggle();
    }
}

function main(metadata, orientation, panelHeight, instanceId) {
    return new BrightnessApplet(orientation, panelHeight, instanceId);
}
