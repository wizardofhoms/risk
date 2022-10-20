
`R.I.S.K.S` (Relatively Insecure System for Keys and Secrets) is a tool suite for creating, using and managing
different online identities, centered around cryptographic autentication (GPG), communication (SSH) and password
secrets (pass) and QubesOS, with an emphasis on seggregating and isolating these identities and their data.

The original idea and associated script can be found in the [risks-scripts](https://github.com/19hundreds/risks-scripts) repository, along with the associated [tutorials](https://19hundreds.github.io/risks-workflow).

# Summary

This repository provides a CLI (`risk`) to be used in dom0. This script depends on the vault `risks` CLI (provided [here](https://github.com/wizardofhoms/risks)),
for working correctly, since it also relies on identities that are used and managed in a vault VM.

The functionality scope of the CLI provided here is significantly different and wider than the vault `risks`, in that it
tries to expand the principles provided by the latter, e.g grossly: strong isolation of identities (here at the network level),
easy use of them and of their associated tools (browsing VMs, VPN gateways, etc).

- Easy creation, management and use of various VMs tied to, and used by, a given identity.
- Strong isolation of identites and their associated VMs, such as network gateways (TOR, VPN, etc)
- Slight integration of vault functionality where it enhances the dom0 workflows.
- Efficient and concise worklow logging, with detailed errors and verbose logging options.
- Structured codebase for easier review and development, while preserving usability.
- Functionality and workflows bundled into a single CLI.
 
In addition, it provides a few helper commands to use with the vault functionality, such as mounting/umounting 
hush/backup devices, opening identies, create new ones along with some associated infrastructure (VMs), and more.
