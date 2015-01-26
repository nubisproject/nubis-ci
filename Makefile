# Nubis project
#
# Build AMIs using packer

# Variables
RELEASE_FILE=nubis/packer/release.json

# Top level build targets
all: build

build: build-increment nubis-puppet

release: release-increment nubis-puppet

# Internal build targets
force: ;

nubis-puppet: force
	cd nubis && librarian-puppet clean
	cd nubis && rm -f Puppetfile.lock
	cd nubis && librarian-puppet install --path=nubis-puppet
	tar --exclude='nubis-puppet/.*' -C nubis -zpcf nubis/nubis-puppet.tar.gz nubis-puppet

release-increment:
	./nubis/bin/release.sh -f $(RELEASE_FILE) -r

build-increment:
	./nubis/bin/release.sh -f $(RELEASE_FILE)

packer: force
	packer build -var-file=nubis/packer/variables.json -var-file=$(RELEASE_FILE) nubis/packer/main.json

clean:
	rm -rf nubis/nubis-puppet
