## Dom0 RISK Makefile ##

SHELL=/bin/bash
VERSION = $(shell git describe --abbrev=0 --tags --always)

default:
	# First generate the risk script from our source
	bashly generate
	
	# Remove set -e from the generated script
	# since we handle our errors ourselves
	sed -i 's/set -e//g' risk

release:
	# Update the version line string
	sed -i 's#^.*\bversion\b.*$$#version: $(VERSION)#' src/bashly.yml
	
	# Change settings from dev to prod
	# (strips a bit of code from the final script)
	sed -i 's#^.*\benv\b.*$$#env: production#' settings.yml
	
	# First generate the risk script from our source
	bashly generate
	
	# Remove set -e from the generated script
	# since we handle our errors ourselves
	sed -i 's/set -e//g' risk
	
	# And reset the settings from prod to dev
	sed -i 's#^.*\benv\b.*$$#env: development#' settings.yml
