const fs=require('fs'),path=require('path');
const SRC=process.argv[2], ROOT=process.argv[3];
let code=fs.readFileSync(SRC,'utf8');
// Point the applet at our synthetic tree instead of /sys/class/power_supply
code=code.replace('const BATTERY_PATH = "/sys/class/power_supply";','const BATTERY_PATH = "'+ROOT+'";');
const calls=[];
class FakeApplet{
  constructor(){this._applet_icon={set_style(){}};this._applet_label={set_style(){}};}
  set_applet_icon_symbolic_name(n){calls.push(['icon',n]);}
  set_applet_label(l){calls.push(['label',l]);}
  set_applet_tooltip(t){calls.push(['tooltip',t]);}
}
global.imports={
  ui:{applet:{TextIconApplet:FakeApplet,IconApplet:FakeApplet,AppletPopupMenu:class{constructor(){this.isOpen=false;}removeAll(){}addMenuItem(){}toggle(){}}},
      popupMenu:{PopupMenuManager:class{addMenu(){}},
                 PopupMenuItem:class{constructor(){this.label={set_style(){}};}connect(){}},
                 PopupIconMenuItem:class{constructor(){this.label={set_style(){}};}connect(){}},
                 PopupSwitchMenuItem:class{constructor(){this.label={set_style(){}};}connect(){}},
                 PopupSeparatorMenuItem:class{}}},
  gi:{St:{IconType:{SYMBOLIC:0}},
      GLib:{file_get_contents(p){try{return [true,fs.readFileSync(p)];}catch(e){return [false,null];}},
            get_home_dir(){return ROOT+'/home';}},
      Gio:{File:{new_for_path(p){return {enumerate_children(){const names=fs.existsSync(p)?fs.readdirSync(p):[];let i=0;
              return {next_file(){ if(i>=names.length) return null; const n=names[i++]; return {get_name(){return n;}};}};}};}},
           FileQueryInfoFlags:{NONE:0}}},
  mainloop:{timeout_add_seconds(){return 1;},timeout_add(){return 1;},source_remove(){}},
  misc:{util:{spawnCommandLine(){}}},
  byteArray:{toString(b){return b.toString();}}
};
global.TextDecoder=global.TextDecoder||require('util').TextDecoder;
const mod={exports:{}};
new Function('module','exports','require',code+'\nmodule.exports={main};')(mod,mod.exports,require);
const a=mod.exports.main({}, 0, 28, 1);
console.log('found battery:', a._battery);
const info=a._getBatteryInfo();
console.log('info:', JSON.stringify(info));
a._update();
console.log('paint calls:', JSON.stringify(calls.slice(-3)));
a._buildMenu();
console.log('menu built OK');
