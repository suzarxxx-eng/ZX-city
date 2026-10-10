fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nx_hud'
description '3D-style HUD: status rings, vehicle speedometer, duty counter, U-menu customization'
version '1.0.0'

shared_script 'config.lua'
client_script 'client/main.lua'
server_script 'server/main.lua'

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}
