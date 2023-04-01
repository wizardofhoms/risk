
# crypt.filename takes a filename as input, and uses the currently
# set identity to produce an random name to use as a file/directory name.
function crypt.filename ()
{
    local encryption_key_cmd="echo '$1' | spectre -q -n -s 0 -F n -t n -u '$1' file_encryption_key"
    encryption_key="$(qvm-run --pass-io "$VAULT_VM" "$encryption_key_cmd")"

    local encrypted_identity_command="echo '$encryption_key' | spectre -q -n -s 0 -F n -t n -u $IDENTITY $1"

    # -q            Quiet: just output the password/filename
    # -n            Don't append a newline to the password output
    # -s 0          Read passphrase from stdinput (fd 0)
    # -F n          No config file output
    # -t n          Output a nine characters name, without symbols
    # -u ${user}    User for which to produce the password/name
    print "$(qvm-run --pass-io "$VAULT_VM" "$encrypted_identity_command")"
}
