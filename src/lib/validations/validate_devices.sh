
validate_device () {
    local block="$1"

    # And check not already attached to another qube
    ovm=$(qvm-block list | grep "${block}" | awk {'print $4'} | cut -d" " -f1)

    if [[ ${#ovm} -gt 0 ]]; then
        echo -e "Block ${SDCARD_BLOCK} is currently attached to ${ovm}."
        echo "Please umount it properly from there and rerun this program."
        return
    fi
}
