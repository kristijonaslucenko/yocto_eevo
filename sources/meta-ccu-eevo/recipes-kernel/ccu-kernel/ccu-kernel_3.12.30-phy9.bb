# Copyright (C) 2016 Eevo Aps,
# Author: Kristijonas

DESCRIPTION =   "Linux Kernel provided and supported by PHYTEC based on TIs \
                Kernel for AM335x Family Boards. It includes support for \
                many IPs such as GPU, VPU and IPU."

include linux-common.inc
inherit git_auth

FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}/features:"

SRC_URI = "git://github.com/${USER}/ccu-kernel.git;branch=v3.12.30-phy"

SRC_URI_append = " \
    ${@bb.utils.contains('DISTRO_FEATURES', 'ipv6', 'file://ipv6.cfg', '', d)} \
    ${@bb.utils.contains('DISTRO_FEATURES', 'systemd', 'file://systemd.cfg', '', d)} \
"
# As of Version 5 of the TI sgx graphic stack, the opengl modules need all of the
# TI kernel Graphics drivers even the legacy da8xx driver
# SRC_URI_append  = " ${@bb.utils.contains('DISTRO_FEATURES', 'opengl', 'file://da8xx-fb.cfg', '', d)}"
# SRC_URI[vardeps] += "DISTRO_FEATURES"
S = "${WORKDIR}/git"

PR = "${INC_PR}.0"

# NOTE: Keep version in filename in sync with commit id!
SRCREV = "03f565ed7131f319a041e314aeb7d161aad4b52c"

COMPATIBLE_MACHINE = "ccu-eevo"

