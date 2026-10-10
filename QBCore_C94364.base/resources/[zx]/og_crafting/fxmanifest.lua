fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'og_crafting'
author 'OG'
description 'OG - طاولات التصنيع بالمدينة (مستويات 0 - 7)'
version '1.0.0'

shared_script 'config.lua'
client_scripts { 'station.lua', 'client.lua' }
server_script 'server.lua'

ui_page 'html/index.html'
files { 'html/index.html', 'html/style.css', 'html/script.js' }

dependencies { 'qb-core', 'qb-target', 'qb-inventory' }
