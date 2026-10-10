fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ar_ops'
description 'مكتب الدوام بالعين: تسجيل دخول/خروج + استلام مركز العمليات ونائبه'
version '1.0.0'

shared_script 'config.lua'
client_script 'client.lua'
server_script 'server.lua'

files { 'desks.json' }

dependencies { 'qb-core', 'qb-target' }
