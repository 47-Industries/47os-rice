#!/usr/bin/env bash
# 47 Industries - Inject 47 Sound slider into Cinnamon sound applet
# DEPRECATED: The sound@cinnamon.org applet now has 47 Sounds built in.
# This script is kept for reference but should NOT run.
# The autostart .desktop file has been disabled (X-GNOME-Autostart-enabled=false).

echo "47sound-inject.sh: SKIPPED - 47 Sounds is now built into sound@cinnamon.org applet"
exit 0

sleep 3

# Wait for the sound applet to exist
for i in $(seq 1 20); do
    result=$(dbus-send --session --dest=org.Cinnamon --type=method_call --print-reply /org/Cinnamon org.Cinnamon.Eval string:"
let panel = imports.ui.main.panel;
let children = panel._rightBox.get_children();
for (let i = 0; i < children.length; i++) {
    let d = children[i]._delegate;
    if (d && d._uuid === 'sound@cinnamon.org' && d.menu) {
        'ready';
    }
}
'waiting';
" 2>/dev/null | grep -o '"ready\|"waiting')

    if [[ "$result" == *"ready"* ]]; then
        break
    fi
    sleep 1
done

# Inject the 47 Sound slider
dbus-send --session --dest=org.Cinnamon --type=method_call --print-reply /org/Cinnamon org.Cinnamon.Eval string:"
let panel = imports.ui.main.panel;
let children = panel._rightBox.get_children();
let applet = null;
for (let i = 0; i < children.length; i++) {
    let d = children[i]._delegate;
    if (d && d._uuid === 'sound@cinnamon.org') { applet = d; break; }
}
let result = 'no applet';
if (applet && !applet._47slider) {
    try {
        let St = imports.gi.St;
        let Slider = imports.ui.slider;
        let PopupMenu = imports.ui.popupMenu;
        let GLib = imports.gi.GLib;
        let Mainloop = imports.mainloop;

        let sep = new PopupMenu.PopupSeparatorMenuItem();
        applet.menu.addMenuItem(sep);

        let item = new PopupMenu.PopupBaseMenuItem({ activate: false });
        let box = new St.BoxLayout({ vertical: false });

        let icon = new St.Icon({
            icon_name: 'xsi-audio-volume-high',
            icon_type: St.IconType.SYMBOLIC,
            icon_size: 16,
            reactive: true,
            track_hover: true,
            style: 'padding-right: 8px;'
        });
        icon.connect('button-press-event', function() {
            GLib.spawn_command_line_async(GLib.get_home_dir() + '/.local/bin/47sound toggle');
            Mainloop.timeout_add(150, function() {
                try {
                    let path = GLib.build_filenamev([GLib.get_home_dir(), '.config/47industries/sound-state']);
                    let [ok2, raw] = GLib.file_get_contents(path);
                    let txt = raw.toString();
                    let mt = /muted=true/.test(txt);
                    let vm = txt.match(/volume=(\d+)/);
                    let vl = vm ? parseInt(vm[1]) : 100;
                    if (mt) {
                        label.set_text('47 Sounds: Muted');
                        icon.icon_name = 'xsi-audio-volume-muted';
                    } else {
                        label.set_text('47 Sounds: ' + vl + '%');
                        icon.icon_name = vl > 0 ? 'xsi-audio-volume-high' : 'xsi-audio-volume-muted';
                    }
                } catch(ex) {}
                return false;
            });
        });
        box.add_actor(icon);

        let label = new St.Label({ text: '47 Sounds: 100%' });
        label.set_style('min-width: 110px; padding-right: 8px;');
        box.add_actor(label);

        let slider = new Slider.Slider(1.0);
        slider.connect('value-changed', function(s, value) {
            let vol = Math.round(value * 100);
            label.set_text('47 Sounds: ' + vol + '%');
            GLib.spawn_command_line_async(GLib.get_home_dir() + '/.local/bin/47sound vol ' + vol);
            icon.icon_name = vol > 0 ? 'xsi-audio-volume-high' : 'xsi-audio-volume-muted';
        });
        box.add(slider.actor, { expand: true });

        item.addActor(box, { expand: true, span: -1 });
        applet.menu.addMenuItem(item);
        applet._47slider = slider;
        applet._47label = label;
        applet._47icon = icon;

        // Make sound popup translucent (inline style overrides CSS)
        try {
            let stateFile = GLib.build_filenamev(['/tmp', 'transparency_state']);
            let [ok3, raw3] = GLib.file_get_contents(stateFile);
            let tState = raw3.toString().trim();
            if (tState === 'on') {
                applet.menu.actor.set_style('background-color: rgba(15, 15, 15, 0.15); border: 1px solid rgba(255,255,255,0.1); border-radius: 12px; border-image: none;');
            }
        } catch(ex) {}

        // Read initial state
        try {
            let path = GLib.build_filenamev([GLib.get_home_dir(), '.config/47industries/sound-state']);
            let [ok2, raw] = GLib.file_get_contents(path);
            let txt = raw.toString();
            let mt = /muted=true/.test(txt);
            let vm = txt.match(/volume=(\d+)/);
            let vl = vm ? parseInt(vm[1]) : 100;
            slider.setValue(vl / 100);
            if (mt) {
                label.set_text('47 Sounds: Muted');
                icon.icon_name = 'xsi-audio-volume-muted';
            } else {
                label.set_text('47 Sounds: ' + vl + '%');
                icon.icon_name = vl > 0 ? 'xsi-audio-volume-high' : 'xsi-audio-volume-muted';
            }
        } catch(ex) {}

        // Refresh on menu open
        let origOpen = applet._openMenu.bind(applet);
        applet._openMenu = function() {
            try {
                let path = GLib.build_filenamev([GLib.get_home_dir(), '.config/47industries/sound-state']);
                let [ok2, raw] = GLib.file_get_contents(path);
                let txt = raw.toString();
                let mt = /muted=true/.test(txt);
                let vm = txt.match(/volume=(\d+)/);
                let vl = vm ? parseInt(vm[1]) : 100;
                slider.setValue(vl / 100);
                if (mt) {
                    label.set_text('47 Sounds: Muted');
                    icon.icon_name = 'xsi-audio-volume-muted';
                } else {
                    label.set_text('47 Sounds: ' + vl + '%');
                    icon.icon_name = vl > 0 ? 'xsi-audio-volume-high' : 'xsi-audio-volume-muted';
                }
            } catch(ex) {}
            origOpen();
        };

        result = 'injected';
    } catch(e) {
        result = 'error: ' + e.message;
    }
} else if (applet && applet._47slider) {
    result = 'already injected';
}
result;
" >/dev/null 2>&1
