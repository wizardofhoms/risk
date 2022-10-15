
`R.I.S.K.S` (Relatively Insecure System for Keys and Secrets) is a tool suite for creating, using and managing
different online identities, centered around cryptographic autentication (GPG), communication (SSH) and website
secrets (pass), with an emphasis on seggregating and isolating these identities, as well as their secrets.

The original idea and associated script can be found in the [risks-scripts](https://github.com/19hundreds/risks-scripts) repository, along with the associated [tutorials](https://19hundreds.github.io/risks-workflow).
However, the concepts used by the tools (both original and this new version) are numerous. Consequently, the workflows
in the original version and tutorials are quite hard to follow, grasp and perform correctly. 
Therefore, one of the main purposes of this new version is to condense the original functionality into easy-to-use
commands, with added functionality and checks, better security and isolation between identities, enhanced logging, 
exhaustive completions, and more.

# Summary

This repository provides a CLI (`risk`) to be used in dom0. This script depends on the vault `risks` CLI (provided [here](https://github.com/wizardofhoms/risks)),
for working correctly, since it also relies on identities that are used and managed in a vault VM.

The functionality scope of the CLI provided here is significantly different and wider than the vault `risks`, in that it
tries to expand the principles provided by the latter, e.g grossly: strong isolation of identities (here at the network level),
easy use of them and of their associated tools (browsing VMs, VPN gateways, etc).

In addition, it provides a few helper commands to use with the vault functionality, such as mounting/umounting 
hush/backup devices, opening identies, create new ones along with some associated infrastructure (VMs), and more.

# Security principles and features

Since the CLI tool provided here differs from the vault CLI tool, its security principles and features differ 
as well, although they are meant to expand on the same ideas of easy but secure use of separate identities.

- Easy creating, management and use of various VMs tied to, and used by, a given identity.
- Functionality and workflows bundled into a single CLI.
- Strong isolation of identites and their associated VMs, such as network gateways (TOR, VPN, etc)
- Slight integration of vault functionality where it enhances the dom0 workflows.
- Efficient and concise worklow logging, with detailed errors and verbose logging options.
- Structured codebase for easier review and development, while preserving usability.

# Table of Contents

- [Summary](#summary)
- [Security principles and features](#security-principles-and-features)
- [Table of Contents](#table-of-contents)
- [Typical usage example](#typical-usage-example)
- [Installation](#installation)
    - [Notes](#notes)
    - [Installing required packages](#installing-required-packages)
    - [Installing risk](#installing-risk)
    - [Initial setup](#initial-setup)
- [Development](#development)
    - [Installing bashly](#installing-bashly)
    - [Development workflow](#development-workflow)
- [Additional usage workflows](#additional-usage-workflows)
- [Command-line API](#command-line-api)

# Typical usage example

# Installation

## Notes
## Installing required packages 
## Installing risk
## Initial setup

# Development

## Installing bashly
## Development workflow

# Additional usage workflows

# Command-line API

