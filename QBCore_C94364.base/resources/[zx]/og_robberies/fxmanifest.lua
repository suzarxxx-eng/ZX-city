fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'og'
description 'Secret robberies - no blips, blue UI, ESX / QBCore'
version '1.0.0'

shared_scripts {
    'config.lua',
    'bridge.lua',
}

client_script 'client.lua'
server_script 'server.lua'

ui_page 'html/index.html'
files { 'html/index.html' }
