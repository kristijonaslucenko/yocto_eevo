#
# Documentation:
#
# This bbclass uses some public variables to create a sdcard image including
# bootloader, device trees, kernel and rootfs. The variables are (still
# incomplete):
#
# - KERNEL_DEVICETREE
#   It's defined in the machine configuration and contains a list of device
#   trees with suffix ".dtb". For example:
#       "imx6q-phytec-pbab01.dtb imx6q-phytec-pbab01-cam0.dtb".
#   The first device tree is special, because it's written to the file 'oftree'
#   on the sdcard which is used as the default device tree by the bootloader.
#   NOTE: The variable may be empty if the kernel doesn't use device trees.
#   See also poky/meta/recipes-kernel/linux/linux-dtb.inc


inherit image_types

PREFERRED_PROVIDER_virtual/bootloader ??= "u-boot"

# Default type of rootfs filesystem.
SDCARD_ROOTFS_TYPE ?= "ext4"

# Location of root filesystem which is written to the sdcard.
SDCARD_ROOTFS = "${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.${SDCARD_ROOTFS_TYPE}"

# The sdcard requires the rootfs filesystem to be built before using
# it so we must make this dependency explicit.
IMAGE_TYPEDEP_sdcard = "${SDCARD_ROOTFS_TYPE}"

# Handle u-boot suffixes
UBOOT_SUFFIX ?= "bin"
UBOOT_PADDING ?= "0"
UBOOT_SUFFIX_SDCARD ?= "${UBOOT_SUFFIX}"

#
# Handles i.MX mxs bootstream generation
#
MXSBOOT_NAND_ARGS ?= ""

# IMX Bootlets Linux bootstream
IMAGE_DEPENDS_linux.sb = "elftosb-native:do_populate_sysroot \
                          imx-bootlets:do_deploy \
                          virtual/kernel:do_deploy"
IMAGE_LINK_NAME_linux.sb = ""
IMAGE_CMD_linux.sb () {
	kernel_bin="`readlink ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE}-${MACHINE}.bin`"
	kernel_dtb="`readlink ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE}-${MACHINE}.dtb || true`"
	linux_bd_file=imx-bootlets-linux.bd-${MACHINE}
	if [ `basename $kernel_bin .bin` = `basename $kernel_dtb .dtb` ]; then
		# When using device tree we build a zImage with the dtb
		# appended on the end of the image
		linux_bd_file=imx-bootlets-linux.bd-dtb-${MACHINE}
		cat $kernel_bin $kernel_dtb \
		    > $kernel_bin-dtb
		rm -f ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE}-${MACHINE}.bin-dtb
		ln -s $kernel_bin-dtb ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE}-${MACHINE}.bin-dtb
	fi

	# Ensure the file is generated
	rm -f ${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.linux.sb
	(cd ${DEPLOY_DIR_IMAGE}; elftosb -z -c $linux_bd_file -o ${IMAGE_NAME}.linux.sb)

	# Remove the appended file as it is only used here
	rm -f ${DEPLOY_DIR_IMAGE}/$kernel_bin-dtb
}

# IMX Bootlets barebox bootstream
IMAGE_DEPENDS_barebox.mxsboot-sdcard = "elftosb-native:do_populate_sysroot \
                                        u-boot-mxsboot-native:do_populate_sysroot \
                                        imx-bootlets:do_deploy \
                                        barebox:do_deploy"
IMAGE_CMD_barebox.mxsboot-sdcard () {
	barebox_bd_file=imx-bootlets-barebox_ivt.bd-${MACHINE}

	# Ensure the files are generated
	(cd ${DEPLOY_DIR_IMAGE}; rm -f ${IMAGE_NAME}.barebox.sb ${IMAGE_NAME}.barebox.mxsboot-sdcard; \
	 elftosb -f mx28 -z -c $barebox_bd_file -o ${IMAGE_NAME}.barebox.sb; \
	 mxsboot sd ${IMAGE_NAME}.barebox.sb ${IMAGE_NAME}.barebox.mxsboot-sdcard)
}

# U-Boot mxsboot generation to SD-Card
UBOOT_SUFFIX_SDCARD_mxs ?= "mxsboot-sdcard"
IMAGE_DEPENDS_uboot.mxsboot-sdcard = "u-boot-mxsboot-native:do_populate_sysroot \
                                      u-boot:do_deploy"
IMAGE_CMD_uboot.mxsboot-sdcard = "mxsboot sd ${DEPLOY_DIR_IMAGE}/u-boot-${MACHINE}.${UBOOT_SUFFIX} \
                                             ${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.uboot.mxsboot-sdcard"

IMAGE_DEPENDS_uboot.mxsboot-nand = "u-boot-mxsboot-native:do_populate_sysroot \
                                      u-boot:do_deploy"
IMAGE_CMD_uboot.mxsboot-nand = "mxsboot ${MXSBOOT_NAND_ARGS} nand \
                                             ${DEPLOY_DIR_IMAGE}/u-boot-${MACHINE}.${UBOOT_SUFFIX} \
                                             ${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.uboot.mxsboot-nand"

# Boot partition volume id
BOOTDD_VOLUME_ID ?= "Boot ${MACHINE}"

# Boot partition size [in KiB]
BOOT_SPACE ?= "8192"

# Barebox environment size [in KiB]
BAREBOX_ENV_SPACE ?= "512"

# Set alignment to 4MB [in KiB]
IMAGE_ROOTFS_ALIGNMENT = "4096"

IMAGE_DEPENDS_sdcard = "parted-native:do_populate_sysroot \
                        dosfstools-native:do_populate_sysroot \
                        mtools-native:do_populate_sysroot \
                        virtual/kernel:do_deploy \
                        virtual/bootloader:do_deploy \
"

SDCARD = "${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.sdcard"

SDCARD_GENERATION_COMMAND_mxs = "generate_mxs_sdcard"
SDCARD_GENERATION_COMMAND_mx25 = "generate_imx_sdcard"
SDCARD_GENERATION_COMMAND_mx5 = "generate_imx_sdcard"
SDCARD_GENERATION_COMMAND_mx6 = "generate_imx_sdcard"
SDCARD_GENERATION_COMMAND_vf60 = "generate_imx_sdcard"


# Copy all dtb files in KERNEL_DEVICETREE onto the sdcard image and use the
# first device tree in KERNEL_DEVICETREE as the 'oftree' file which will be
# used as the default device tree by the bootloader.
copy_kernel_device_trees () {
	BOOT_IMAGE=$1

	if test -n "${KERNEL_DEVICETREE}"; then
		DEVICETREE_DEFAULT=""
		for DTS_FILE in ${KERNEL_DEVICETREE}; do
			[ -n "${DEVICETREE_DEFAULT}"] && DEVICETREE_DEFAULT="${DTS_FILE}"
			mcopy -i ${BOOT_IMAGE} -s ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE}-${DTS_FILE} ::${DTS_FILE}
		done

		mcopy -i ${BOOT_IMAGE} -s ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE}-${DEVICETREE_DEFAULT} ::oftree

		# Create README
		README=${WORKDIR}/README.sdcard.txt
		cat > ${README} <<EOF
This directory maybe contains multiple device tree files (suffix dtb).  So a
single sd-card image can be used on multiple board configurations.

By default the device tree in the file 'oftree' is loaded. The file is a plain
copy of the device tree '${DEVICETREE_DEFAULT}'.  If you want to use another
device tree, either rename the file to 'oftree' or change the variable
'global.bootm.oftree' in the barebox environment file '/env/boot/mmc' (Don't
forget to execute 'saveenv').

If you want to change the default device tree for the sd-card in the yocto
image creation process, place the default device tree at the beginning of the
variable KERNEL_DEVICETREE in the machine configuration.
EOF
		mcopy -i ${BOOT_IMAGE} -s ${README} ::/README.txt
	fi
}

#
# Create an image that can by written onto a SD card using dd for use
# with i.MX SoC family
#
# External variables needed:
#   ${SDCARD_ROOTFS}                         - the rootfs image to incorporate
#   ${PREFERRED_PROVIDER_virtual/bootloader} - bootloader to use {u-boot, barebox}
#
# The disk layout used is:
#
#    0                      -> IMAGE_ROOTFS_ALIGNMENT         - reserved to bootloader (not partitioned)
#    IMAGE_ROOTFS_ALIGNMENT -> BOOT_SPACE                     - kernel and other data
#    BOOT_SPACE             -> SDIMG_SIZE                     - rootfs
#
#                                                     Default Free space = 1.3x
#                                                     Use IMAGE_OVERHEAD_FACTOR to add more space
#                                                     <--------->
#            4MiB               8MiB           SDIMG_ROOTFS                    4MiB
# <-----------------------> <----------> <----------------------> <------------------------------>
#  ------------------------ ------------ ------------------------ -------------------------------
# | IMAGE_ROOTFS_ALIGNMENT | BOOT_SPACE | ROOTFS_SIZE            |     IMAGE_ROOTFS_ALIGNMENT    |
#  ------------------------ ------------ ------------------------ -------------------------------
# ^                        ^            ^                        ^                               ^
# |                        |            |                        |                               |
# 0                      4096     4MiB +  8MiB       4MiB +  8Mib + SDIMG_ROOTFS   4MiB +  8MiB + SDIMG_ROOTFS + 4MiB
generate_imx_sdcard () {
	# Create partition table
	parted -s ${SDCARD} mklabel msdos
	parted -s ${SDCARD} unit KiB mkpart primary fat32 ${IMAGE_ROOTFS_ALIGNMENT} $(expr ${IMAGE_ROOTFS_ALIGNMENT} \+ ${BOOT_SPACE_ALIGNED})
	parted -s ${SDCARD} unit KiB mkpart primary $(expr  ${IMAGE_ROOTFS_ALIGNMENT} \+ ${BOOT_SPACE_ALIGNED}) $(expr ${IMAGE_ROOTFS_ALIGNMENT} \+ ${BOOT_SPACE_ALIGNED} \+ $ROOTFS_SIZE)
	parted ${SDCARD} print

	# Burn bootloader
	case "${PREFERRED_PROVIDER_virtual/bootloader}" in
		imx-bootlets)
		bberror "The imx-bootlets is not supported for i.MX based machines"
		exit 1
		;;
		u-boot)
		if [ -n "${SPL_BINARY}" ]; then
			dd if=${DEPLOY_DIR_IMAGE}/${SPL_BINARY} of=${SDCARD} conv=notrunc seek=2 bs=512
			dd if=${DEPLOY_DIR_IMAGE}/u-boot-${MACHINE}.${UBOOT_SUFFIX_SDCARD} of=${SDCARD} conv=notrunc seek=42 bs=1K
		else
			dd if=${DEPLOY_DIR_IMAGE}/u-boot-${MACHINE}.${UBOOT_SUFFIX_SDCARD} of=${SDCARD} conv=notrunc seek=2 skip=${UBOOT_PADDING} bs=512
		fi
		;;
		barebox)
		dd if=${DEPLOY_DIR_IMAGE}/barebox.bin of=${SDCARD} conv=notrunc seek=1 skip=1 bs=512
#		dd if=${DEPLOY_DIR_IMAGE}/bareboxenv.bin of=${SDCARD} conv=notrunc seek=1 bs=512k
		;;
		"")
		;;
		*)
		bberror "Unknown PREFERRED_PROVIDER_virtual/bootloader value"
		exit 1
		;;
	esac

	# Create boot partition image
	BOOT_BLOCKS=$(LC_ALL=C parted -s ${SDCARD} unit b print \
	                  | awk '/ 1 / { print substr($4, 1, length($4 -1)) / 1024 }')
	mkfs.vfat -n "${BOOTDD_VOLUME_ID}" -S 512 -C ${WORKDIR}/boot.img $BOOT_BLOCKS
	mcopy -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE}-${MACHINE}.bin ::/${KERNEL_IMAGETYPE}

	# Copy boot scripts
	for item in ${BOOT_SCRIPTS}; do
		src=`echo $item | awk -F':' '{ print $1 }'`
		dst=`echo $item | awk -F':' '{ print $2 }'`

		mcopy -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/$src ::/$dst
	done

	# Copy device tree file
	copy_kernel_device_trees "${WORKDIR}/boot.img"

	# Burn Partition
	dd if=${WORKDIR}/boot.img of=${SDCARD} conv=notrunc,fsync seek=1 bs=$(expr ${IMAGE_ROOTFS_ALIGNMENT} \* 1024)
	dd if=${SDCARD_ROOTFS} of=${SDCARD} conv=notrunc,fsync seek=1 bs=$(expr ${BOOT_SPACE_ALIGNED} \* 1024 + ${IMAGE_ROOTFS_ALIGNMENT} \* 1024)
}

#
# Create an image that can by written onto a SD card using dd for use
# with i.MXS SoC family
#
# External variables needed:
#   ${SDCARD_ROOTFS}    - the rootfs image to incorporate
#   ${PREFERRED_PROVIDER_virtual/bootloader} - bootloader to use {imx-bootlets, u-boot}
#
generate_mxs_sdcard () {
	# Create partition table
	parted -s ${SDCARD} mklabel msdos

	case "${PREFERRED_PROVIDER_virtual/bootloader}" in
		imx-bootlets)
		# The disk layout used is:
		#
		#    0                      -> 1024                           - Unused (not partitioned)
		#    1024                   -> BOOT_SPACE                     - kernel and other data (bootstream)
		#    BOOT_SPACE             -> SDIMG_SIZE                     - rootfs
		#
		#                                     Default Free space = 1.3x
		#                                     Use IMAGE_OVERHEAD_FACTOR to add more space
		#                                     <--------->
		#    1024        8MiB          SDIMG_ROOTFS                    4MiB
		# <-------> <----------> <----------------------> <------------------------------>
		#  --------------------- ------------------------ -------------------------------
		# | Unused | BOOT_SPACE | ROOTFS_SIZE            |     IMAGE_ROOTFS_ALIGNMENT    |
		#  --------------------- ------------------------ -------------------------------
		# ^        ^            ^                        ^                               ^
		# |        |            |                        |                               |
		# 0      1024      1024 + 8MiB       1024 + 8Mib + SDIMG_ROOTFS      1024 + 8MiB + SDIMG_ROOTFS + 4MiB
		parted -s ${SDCARD} unit KiB mkpart primary 1024 $(expr ${IMAGE_ROOTFS_ALIGNMENT} \+ ${BOOT_SPACE_ALIGNED})
		parted -s ${SDCARD} unit KiB mkpart primary $(expr ${IMAGE_ROOTFS_ALIGNMENT} \+ ${BOOT_SPACE_ALIGNED}) $(expr ${IMAGE_ROOTFS_ALIGNMENT} \+ ${BOOT_SPACE_ALIGNED} \+ $ROOTFS_SIZE)

		# Empty 4 bytes from boot partition
		dd if=/dev/zero of=${SDCARD} conv=notrunc seek=2048 count=4

		# Write the bootstream in (2048 + 4) bytes
		dd if=${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.linux.sb of=${SDCARD} conv=notrunc seek=1 seek=2052
		;;
		u-boot)
		# The disk layout used is:
		#
		#    1M - 2M                  - reserved to bootloader and other data
		#    2M - BOOT_SPACE          - kernel
		#    BOOT_SPACE - SDCARD_SIZE - rootfs
		#
		# The disk layout used is:
		#
		#    1M                     -> 2M                             - reserved to bootloader and other data
		#    2M                     -> BOOT_SPACE                     - kernel and other data
		#    BOOT_SPACE             -> SDIMG_SIZE                     - rootfs
		#
		#                                                        Default Free space = 1.3x
		#                                                        Use IMAGE_OVERHEAD_FACTOR to add more space
		#                                                        <--------->
		#            4MiB                8MiB             SDIMG_ROOTFS                    4MiB
		# <-----------------------> <-------------> <----------------------> <------------------------------>
		#  ---------------------------------------- ------------------------ -------------------------------
		# |      |      |                          |ROOTFS_SIZE             |     IMAGE_ROOTFS_ALIGNMENT    |
		#  ---------------------------------------- ------------------------ -------------------------------
		# ^      ^      ^          ^               ^                        ^                               ^
		# |      |      |          |               |                        |                               |
		# 0     1M     2M         4M        4MiB + BOOTSPACE   4MiB + BOOTSPACE + SDIMG_ROOTFS   4MiB + BOOTSPACE + SDIMG_ROOTFS + 4MiB
		#
		parted -s ${SDCARD} unit KiB mkpart primary 1024 2048
		parted -s ${SDCARD} unit KiB mkpart primary 2048 $(expr ${IMAGE_ROOTFS_ALIGNMENT} \+ ${BOOT_SPACE_ALIGNED})
		parted -s ${SDCARD} unit KiB mkpart primary $(expr  ${IMAGE_ROOTFS_ALIGNMENT} \+ ${BOOT_SPACE_ALIGNED}) $(expr ${IMAGE_ROOTFS_ALIGNMENT} \+ ${BOOT_SPACE_ALIGNED} \+ $ROOTFS_SIZE)

		dd if=${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.uboot.mxsboot-sdcard of=${SDCARD} conv=notrunc seek=1 skip=${UBOOT_PADDING} bs=$(expr 1024 \* 1024)
		BOOT_BLOCKS=$(LC_ALL=C parted -s ${SDCARD} unit b print \
	        | awk '/ 2 / { print substr($4, 1, length($4 -1)) / 1024 }')

		mkfs.vfat -n "${BOOTDD_VOLUME_ID}" -S 512 -C ${WORKDIR}/boot.img $BOOT_BLOCKS
		mcopy -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE}-${MACHINE}.bin ::/${KERNEL_IMAGETYPE}
		copy_kernel_device_trees "${WORKDIR}/boot.img"

		dd if=${WORKDIR}/boot.img of=${SDCARD} conv=notrunc seek=2 bs=$(expr 1024 \* 1024)
		;;
		barebox)
		# BAREBOX_ENV_SPACE is taken on BOOT_SPACE_ALIGNED but it doesn't really matter as long as the rootfs is aligned
		parted -s ${SDCARD} unit KiB mkpart primary 1024 $(expr ${IMAGE_ROOTFS_ALIGNMENT} \+ ${BOOT_SPACE_ALIGNED} - ${BAREBOX_ENV_SPACE})
		parted -s ${SDCARD} unit KiB mkpart primary $(expr ${IMAGE_ROOTFS_ALIGNMENT} \+ ${BOOT_SPACE_ALIGNED} - ${BAREBOX_ENV_SPACE}) $(expr ${IMAGE_ROOTFS_ALIGNMENT} \+ ${BOOT_SPACE_ALIGNED})
		parted -s ${SDCARD} unit KiB mkpart primary $(expr ${IMAGE_ROOTFS_ALIGNMENT} \+ ${BOOT_SPACE_ALIGNED}) $(expr ${IMAGE_ROOTFS_ALIGNMENT} \+ ${BOOT_SPACE_ALIGNED} \+ $ROOTFS_SIZE)

		dd if=${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.barebox.mxsboot-sdcard of=${SDCARD} conv=notrunc seek=1 bs=$(expr 1024 \* 1024)
#		dd if=${DEPLOY_DIR_IMAGE}/bareboxenv-${MACHINE}.bin of=${SDCARD} conv=notrunc seek=$(expr ${IMAGE_ROOTFS_ALIGNMENT} \+ ${BOOT_SPACE_ALIGNED} - ${BAREBOX_ENV_SPACE}) bs=1024
		;;
		*)
		bberror "Unknown PREFERRED_PROVIDER_virtual/bootloader value"
		exit 1
		;;
	esac

	# Change partition type for mxs processor family
	bbnote "Setting partition type to 0x53 as required for mxs' SoC family."
	echo -n S | dd of=${SDCARD} bs=1 count=1 seek=450 conv=notrunc

	parted ${SDCARD} print

	dd if=${SDCARD_ROOTFS} of=${SDCARD} conv=notrunc,fsync seek=1 bs=$(expr ${BOOT_SPACE_ALIGNED} \* 1024 + ${IMAGE_ROOTFS_ALIGNMENT} \* 1024)
}

IMAGE_CMD_sdcard () {
	if [ -z "${SDCARD_ROOTFS}" ]; then
		bberror "SDCARD_ROOTFS is undefined. To use sdcard image from Freescale's BSP it needs to be defined."
		exit 1
	fi

	# Align boot partition and calculate total SD card image size
	BOOT_SPACE_ALIGNED=$(expr ${BOOT_SPACE} + ${IMAGE_ROOTFS_ALIGNMENT} - 1)
	BOOT_SPACE_ALIGNED=$(expr ${BOOT_SPACE_ALIGNED} - ${BOOT_SPACE_ALIGNED} % ${IMAGE_ROOTFS_ALIGNMENT})
	SDCARD_SIZE=$(expr ${IMAGE_ROOTFS_ALIGNMENT} + ${BOOT_SPACE_ALIGNED} + $ROOTFS_SIZE + ${IMAGE_ROOTFS_ALIGNMENT})

	# Initialize a sparse file
	dd if=/dev/zero of=${SDCARD} bs=1 count=0 seek=$(expr 1024 \* ${SDCARD_SIZE})

	${SDCARD_GENERATION_COMMAND}
}