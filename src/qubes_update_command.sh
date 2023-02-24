local vms="${args['vms']}"

get_all_qubes() {
    local all_qubes
    while read VM_NAME ; do
        all_qubes+=("${VM_NAME}")
    done < <(qvm-ls --raw-list | sort)

    echo "${all_qubes[@]}"
}

local all_qubes
read -ra all_qubes < "$(get_all_qubes)"

get_all_templates() {
    local templates=() 
    while read line ; do
        IFS="|" read -r name class < "${qube}"
        if [[ "$class" == "TemplateVM" ]]; then
            templates+=( "$name" )
        fi
    done < ("$(qvm-ls --raw-data --fields name,class|sort)")

    echo "${templates[@]}"
}

local targets
read -ra all_templates < "$(get_all_templates)"

for template in "${all_templates[@]}"; do
    if [[ "$template" =~ .*"$*".* ]]; then
        echo $template
    fi
done
