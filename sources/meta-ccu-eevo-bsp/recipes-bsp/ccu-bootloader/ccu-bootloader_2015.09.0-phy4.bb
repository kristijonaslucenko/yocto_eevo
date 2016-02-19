require barebox.inc
inherit git_auth

SRC_URI_append = " \
    file://0001-Makefile-add-TARGETCC.patch \
"
FILESEXTRAPATHS_prepend := "${THISDIR}/defconfigs:${THISDIR}/defconfigs/features:"
FILESEXTRAPATHS_prepend := "${THISDIR}/ccu-bootloader/features:"
FILESEXTRAPATHS_prepend := "${THISDIR}/env-2015.09.0-phy4:"

SRC_URI = "git://github.com/${USER}/ccu-bootloader.git;branch=v2015.09.0-phy"

SRC_URI_append = " \
    file://commonenv \
    file://boardenv \
    file://machineenv \
    file://targettools.cfg \
"
S = "${WORKDIR}/git"

PR = "${INC_PR}.0"

# NOTE: Keep version in filename in sync with commit id and barebox-ipl!

# SRCREV is the commit id of the phy4 tag in ccu-bootloader rep
SRCREV = "0f034be57e539212af84dfd53e70faadac40e6f3"

COMPATIBLE_MACHINE = "ccu-eevo"

