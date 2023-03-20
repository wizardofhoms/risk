
# does the vm exist?
validate_vm_exists () {
    vm=""
    for item in $(qvm-ls | grep -v dom0 | awk '{print $1}' | grep "${1}")
    do
        if [ "${item}" == "${1}" ]; then
            vm=${1}
        fi
    done
    if [ ${#vm} -eq 0 ]; then
        echo "No vm with name ${1} exists or can not be used. Aborted."
        return
    fi
}

# Checks that the vault VM obeys a few requirements, like no network
validate_valid_vaultvm () {
    vm=""
    for item in $(qvm-ls | grep -v dom0 | awk '{print $1}' | grep "${1}")
    do
        if [ "${item}" == "${1}" ]; then
            vm=${1}
        fi
    done
    if [ ${#vm} -eq 0 ]; then
        echo "No vm with name ${1} exists or can not be used. Aborted."
        return
    fi

    netvm=$(qvm-prefs "${vm}" | grep "netvm" | awk '{print $3}')
    if [ "${netvm}" != "None" ]; then
        echo "${vm} might be connected to the internet. Aborted."
        echo "Check: qvm-prefs ${vm} | grep netvm"
    fi
}

# validate_netvm fails if the specified VM does not provide network.
validate_netvm ()
{
    local netvm="${1}"

    if [[ $(qvm-prefs "${netvm}" provides_network) == False ]]; then
        echo "Qube ${netvm} is specified as netvm, but does not provide network."
    fi
}
