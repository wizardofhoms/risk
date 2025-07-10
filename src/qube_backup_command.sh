
fields=("${other_args[@]/#\ }")  # remove leading spaces
fields=("${fields[@]/%\ }")  # remove trailing spaces

fields=("${fields[@]/#\"}")  # remove leading quotes
fields=("${fields[@]/%\"}")  # remove trailing quotes

# Simply pass the arguments down to the other command.
sudo wyng-util-qubes "${fields[@]}"
