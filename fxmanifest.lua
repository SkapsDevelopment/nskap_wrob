fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'not.skap'
version '1.0.1'

shared_script '@ox_lib/init.lua'
shared_script 'config.lua'
client_script 'client.lua'
server_script 'server.lua'

dependencies {
    'es_extended',
    'ox_lib',
    'ox_target',
    'ox_inventory'
}