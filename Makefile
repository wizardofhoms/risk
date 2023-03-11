## Dom0 RISK Makefile ##

SHELL=/bin/bash
VERSION = $(shell git describe --abbrev=0 --tags --always)

default:
	# Remove all trailing spaces from src code.
	sed -i 's/[ \t]*$$//' **/*.sh

	# First generate the risk script from our source
	bashly generate

	# Move the initialize call from its current position to within 
	# the run function, so that flags are accessible immediately.
	sed -i 'N;$$!P;D' risk
	sed -i '/parse_requirements "$${/a \ \ initialize' risk
	
release:
	# Update the version line string
	sed -i 's#^.*\bversion\b.*$$#version: $(VERSION)#' src/bashly.yml
	
	# Change settings from dev to prod
	# (strips a bit of code from the final script)
	sed -i 's#^.*\benv\b.*$$#env: production#' settings.yml
	
	# Remove all trailing spaces from src code.
	sed -i 's/[ \t]*$$//' **/*.sh

	# First generate the risk script from our source
	bashly generate
	
	# Move the initialize call from its current position to within 
	# the run function, so that flags are accessible immediately.
	sed -i 'N;$$!P;D' risks
	sed -i '/parse_requirements "$${/a \ \ initialize' risks

	# And reset the settings from prod to dev
	sed -i 's#^.*\benv\b.*$$#env: development#' settings.yml

	# Signatures
	qubes-gpg-client-wrapper --detach-sign risq > risq.gpg
	sha256sum risq > risq.sha
