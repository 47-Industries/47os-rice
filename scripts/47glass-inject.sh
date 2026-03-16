#!/usr/bin/env bash
# 47 Industries - Apply translucent styles to all panel popups
sleep 3
for i in $(seq 1 20); do
    result=$(dbus-send --session --dest=org.Cinnamon --type=method_call --print-reply /org/Cinnamon org.Cinnamon.Eval string:"
let panel = imports.ui.main.panel;
let boxes = [panel._leftBox, panel._centerBox, panel._rightBox];
for (let b = 0; b < boxes.length; b++) {
    let children = boxes[b].get_children();
    for (let i = 0; i < children.length; i++) {
        let d = children[i]._delegate;
        if (d && d._uuid === 'brightness@custom' && d.menu) { 'ready'; }
    }
}
'waiting';
" 2>/dev/null | grep -o '"ready\|"waiting')
    if [[ "$result" == *"ready"* ]]; then break; fi
    sleep 1
done
dbus-send --session --dest=org.Cinnamon --type=method_call --print-reply /org/Cinnamon org.Cinnamon.Eval string:"
let panel = imports.ui.main.panel;
let boxes = [panel._leftBox, panel._centerBox, panel._rightBox];
let skip = ['menu@cinnamon.org'];
let GLib = imports.gi.GLib;
let tState = 'off';
try {
    let [ok, raw] = GLib.file_get_contents(GLib.build_filenamev([GLib.get_home_dir(), '.config', '47industries', 'transparency-state']));
    tState = raw.toString().trim();
} catch(e) {}
if (tState === 'on') {
    let style = 'background-color: rgba(15, 15, 15, 0.15); border: 1px solid rgba(255,255,255,0.1); border-radius: 12px; border-image: none;';
    let innerStyle = 'background-color: transparent; border-image: none;';
    for (let b = 0; b < boxes.length; b++) {
        let children = boxes[b].get_children();
        for (let i = 0; i < children.length; i++) {
            let d = children[i]._delegate;
            if (d && d._uuid && d.menu && skip.indexOf(d._uuid) === -1) {
                d.menu.actor.set_style(style);
                let mc = d.menu.actor.get_children();
                for (let j = 0; j < mc.length; j++) { mc[j].set_style(innerStyle); }
            }
        }
    }
}
'done';
" >/dev/null 2>&1
