fx_version 'cerulean'
game 'gta5'

author '3bedeIQ'
description 'Custom Clean Target System'
version '1.0.0'

dependencies {
    'PolyZone'
}

ui_page 'html/index.html'

shared_scripts {
    'config.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

server_scripts {
    'server.lua'
}

client_scripts {
    '@PolyZone/client.lua',
    '@PolyZone/BoxZone.lua',
    '@PolyZone/EntityZone.lua',
    '@PolyZone/CircleZone.lua',
    '@PolyZone/ComboZone.lua',
    'client.lua'
}