#!/bin/bash
# 47 OS - Nuclear theme enforcement
sleep 2
gsettings set org.cinnamon.theme name 'WhiteSur-Dark'
gsettings set org.cinnamon.desktop.interface gtk-theme 'WhiteSur-Dark'
gsettings set org.cinnamon.desktop.interface icon-theme 'WhiteSur-dark'
gsettings set org.cinnamon.desktop.interface cursor-theme 'WhiteSur-cursors'
gsettings set org.cinnamon.desktop.interface font-name 'SF Pro Display 10'
gsettings set org.cinnamon.desktop.wm.preferences theme 'WhiteSur-Dark'
gsettings set org.cinnamon.desktop.wm.preferences titlebar-font 'SF Pro Display Bold 10'
gsettings set org.cinnamon.desktop.wm.preferences button-layout ':minimize,maximize,close'
gsettings set org.cinnamon.desktop.background picture-uri 'file:///usr/share/backgrounds/sequoia-sunrise.jpg'
gsettings set org.cinnamon.desktop.background picture-options 'zoom'
gsettings set org.gnome.desktop.interface gtk-theme 'WhiteSur-Dark' 2>/dev/null
gsettings set org.gnome.desktop.interface icon-theme 'WhiteSur-dark' 2>/dev/null
gsettings set org.gnome.desktop.interface cursor-theme 'WhiteSur-cursors' 2>/dev/null
gsettings set org.cinnamon panels-enabled "['1:0:top']"
gsettings set org.cinnamon panels-height "['1:28']"
gsettings set org.nemo.desktop computer-icon-visible false
gsettings set org.nemo.desktop home-icon-visible false
gsettings set org.nemo.desktop network-icon-visible false
gsettings set org.nemo.desktop trash-icon-visible false
gsettings set org.nemo.desktop volumes-visible false
gsettings set org.cinnamon app-menu-icon-name '47os-logo'
