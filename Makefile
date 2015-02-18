# Nubis project
#
# Build AMIs using packer

# Variables
RELEASE_FILE=nubis/packer/release.json

# Top level build targets
all: build

build: build-increment

release: release-increment

# Internal build targets
force: ;

release-increment:
	./nubis/bin/release.sh -f $(RELEASE_FILE) -r

build-increment:
	./nubis/bin/release.sh -f $(RELEASE_FILE)

packer: force
	packer build -var-file=nubis/packer/variables.json -var-file=$(RELEASE_FILE) nubis/packer/main.json

clean:
	rm -rf nubis/nubis-puppet
