
_set_identity 

local name autostart_vms already_enabled

name="${args[vm]}"

enable_vm_autostart "$name"
