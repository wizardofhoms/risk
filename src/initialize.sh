
# Connected terminal
typeset -H _TTY

# Remove verbose errors when * don't yield any match in ZSH
setopt +o nomatch

# The generated script makes use of BASH_REMATCH, set compat for ZSH
setopt BASH_REMATCH

# Use colors unless told not to
{ ! option_is_set --no-color } && { autoload -Uz colors && colors }

## Checks ##

# Don't run as root
if [[ $EUID -eq 0 ]]; then
   echo "This script must be run as user"
   exit 2
fi

# Configuration file -------------------------------------------------------------------------------
#
# Working state and configurations
typeset -rg RISK_DIR="${HOME}/.risk"                         # Directory where risk stores its state
typeset -rg RISK_IDENTITIES_DIR="${RISK_DIR}/identities"     # Idendities store their settings here
typeset -rg RISK_IDENTITY_FILE="${RISK_DIR}/.identity"

# Create the risk directory if needed
[[ -e $RISK_DIR ]] || { mkdir -p $RISK_DIR && _info "Creating RISK directory in $RISK_DIR" }
[[ -e $RISK_IDENTITIES_DIR ]] || mkdir -p $RISK_IDENTITIES_DIR

# Write the default configuration if it does not exist.
config_init

# Default filesystem settings from configuration file ----------------------------------------------
typeset -g VAULT_VM=$(config_get VAULT_VM)
typeset -g DEFAULT_NETVM=$(config_get DEFAULT_NETVM)

typeset -gr DOM0_TERMINAL=$(config_get DOM0_TERMINAL)
typeset -gr VM_TERMINAL=$(config_get VM_TERMINAL)

# Working state variables --------------------------------------------------------------------------
typeset -r IDENTITY                 # The identity to use for this single risk execution
typeset -g IDENTITY_DIR             # The directory where to store identity settings
typeset -g IDENTITY_BOOKMARKS_FILE  # The file in mgmt tomb storing user bookmarks.
