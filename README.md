Mozilla Nubis CI
====================

To build the image, first, you need to run the pre-build steps:

$> make -C nubis build

Then, you can just run packer

$> packer build -var release=$USER-123 nubis/packer/main.json
