inherit git_auth
require barebox-ipl.inc

FILESEXTRAPATHS_prepend := "${THISDIR}/ccu-bootloader/features:"

SRC_URI = "git://github.com/${USER}/ccu-bootloader.git;branch=v2015.09.0-phy"

S = "${WORKDIR}/git"

PR = "${INC_PR}.0"

SRCREV = "0f034be57e539212af84dfd53e70faadac40e6f3"

SRC_URI_append = " file://noafiboard.cfg"

COMPATIBLE_MACHINE = "ccu-eevo"

SRC_URI_append_ccu-eevo = " file://netboot.cfg"


do_deploy_append () {
    # deploy spi boot images
    spiimg=$(echo ${BAREBOX_IPL_BIN} | sed 's/.img/.spi.img/')
    if [ -e ${B}/$spiimg ] ; then
        install -m 0644 ${B}/$spiimg ${DEPLOYDIR}/${BAREBOX_IPL_IMAGE_BASE_NAME}.img.spi
        ln -sf ${BAREBOX_IPL_IMAGE_BASE_NAME}.img.spi ${DEPLOYDIR}/${BAREBOX_IPL_BIN_SYMLINK}.spi
    fi

    # deploy peripheral boot images (without GP header)
    perimg=$(echo ${BAREBOX_IPL_BIN} | sed 's/barebox/start/;s/-/_/g;s/mlo/sram/;s/img/pblx/')
    install -m 0644 ${B}/$perimg ${DEPLOYDIR}/${BAREBOX_IPL_IMAGE_BASE_NAME}.img.per
    ln -sf ${BAREBOX_IPL_IMAGE_BASE_NAME}.img.per ${DEPLOYDIR}/${BAREBOX_IPL_BIN_SYMLINK}.per
}
