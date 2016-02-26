#
# This file was derived from the 'Hello World!' example recipe in the
# Yocto Project Development Manual.
#

DESCRIPTION = "Simple helloworld application"
SECTION = "testing"
DEPENDS = ""
# LICENSE = "MIT"
# LIC_FILES_CHKSUM = "file://LICENSE;md5=96af5705d6f64a88e035781ef00e98a8"

FILESEXTRAPATHS_prepend := "${THISDIR}/serial-test:"

LICENSE = "GPL-2.0"
LIC_FILES_CHKSUM = "file://COPYING;md5=838c366f69b72c5df05c96dff79b35f2"

USER = "kristijonaslucenko"

PR = "r0"

SRC_URI = "file://linux-serial-test.c"

S = "${WORKDIR}"

do_compile() {
	${CC} linux-serial-test.c -o serial-test
}

do_install() {
	install -d ${D}${bindir}
	install -m 0755 serial-test ${D}${bindir}
}
