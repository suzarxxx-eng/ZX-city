fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ar_gunfx'
description 'تغويش بسيط للشاشة + صدى وصفير رصاص وقت إطلاق النار'
version '1.1.0'

shared_script 'config.lua'
client_scripts { 'client.lua', 'sound.lua' }

ui_page 'html/index.html'
files { 'html/index.html', 'html/sound.js' }
