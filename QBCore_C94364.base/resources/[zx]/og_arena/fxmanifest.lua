fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'og_arena'
description 'قتال OG: أرينا (مسدس / AK / سنايبر / شوزن) + تيد ام بغرف خاصة — كلها بالسما وبعوالم منفصلة'
version '2.0.0'

shared_script 'config.lua'
client_scripts {
    'client_build.lua',
    'client.lua',
    'client_tdm.lua',
}
server_scripts {
    'server.lua',
    'server_tdm.lua',
}

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}

dependency 'qb-core'
