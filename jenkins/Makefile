all: install-puppet-modules

install-puppet-modules:
	# Should be converted to puppet librarian (and not fail when its already there)
	puppet module install rtyler-jenkins --version 1.3.0 --target-dir puppet-modules || true

packer: install-puppet-modules
	packer build -var-file=packer/variables.json -var release=gozer-21 packer/main.json
