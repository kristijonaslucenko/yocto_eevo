SUMMARY = "Eevo hardware testing image"
DESCRIPTION = "A small image capable of allowing a device to boot and \
               check for hardware problems."
LICENSE = "MIT"

require eevo-headless-image.bb
include recipes-kernel/linux/mtd_test_packages.inc

IMAGE_INSTALL += " \
    ${MTD_TEST_PACKAGES} \
"
