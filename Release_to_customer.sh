#!/bin/bash

# PR300 Fixed Specifications:
# Chip ssd202
# Flash type nand
# Flash size 256M
# No GUI
# No Doublenet

while getopts "q:k:b:" opt; do
	case $opt in
	b)
		ignoreb=$OPTARG
		;;
	k)
		ignorek=$OPTARG
		;;
	q)
		fastboot=$OPTARG
		;;
	\?)
		echo "Invalid option: -$OPTARG" >&2
		;;
	esac
done

DATE=$(date +%m%d)
RELEASEDIR=$(pwd)
export ARCH=arm
export PROJECT=PR300Plus

if [ ! -f project/image/rootfs/rootfs.tar.gz ]; then
	cat project/image/rootfs/rootfs_route.tar.gz.* >project/image/rootfs/rootfs.tar.gz
fi

# Flash size 256M
cp project/image/configs/i2m/spinand.ubifs.p2.partition.config_PR310 project/image/configs/i2m/spinand.ubifs.p2.partition.config -f
cp project/image/configs/i2m/spinand.ramfs-squashfs.p2.partition.config_256M project/image/configs/i2m/spinand.ramfs-squashfs.p2.partition.config

if [ "${ignoreb}" = 1 ]; then
	echo Jump Uboot build
else
	# build uboot
	cd ${RELEASEDIR}/boot
	declare -x ARCH="arm"
	declare -x CROSS_COMPILE="arm-linux-gnueabihf-"
	make infinity2m_pr310plus_defconfig
	#make clean
	make -j8
fi

if [ -d ../project/board/i2m/boot/spinand/uboot ]; then
	cp u-boot_spinand.xz.img.bin ../project/board/i2m/boot/spinand/uboot
fi

if [ "${ignorek}" = 1 ]; then
	echo Jump Kernel build
else
	#build kernel
	cd ${RELEASEDIR}/kernel
	declare -x ARCH="arm"
	declare -x CROSS_COMPILE="arm-linux-gnueabihf-"
	if [ "${fastboot}" = "fastboot" ]; then
		make infinity2m_spinand_ssc011a_s01a_fastboot_defconfig
	else
		make infinity2m_pr310plus_defconfig
	fi
	#make clean
	make -j8
fi

#build project
cd ${RELEASEDIR}/project
# Chip ssd202
if [ "${fastboot}" = "fastboot" ]; then
	./setup_config.sh ./configs/nvr/i2m/8.2.1/spinand.ram-glibc-squashfs.011a.128
else
	./setup_config.sh ./configs/nvr/i2m/8.2.1/spinand_pr310.glibc.011a.128
fi

cd ${RELEASEDIR}/project/kbuild/4.9.84
if [ "${fastboot}" = "fastboot" ]; then
	echo fast release
	./release.sh -k ${RELEASEDIR}/kernel -b 011A-fastboot -p nvr -f spinand -c i2m -l glibc -v 8.2.1
else
	./release.sh -k ${RELEASEDIR}/kernel -b 011A -p nvr -f spinand -c i2m -l glibc -v 8.2.1
fi

cd ${RELEASEDIR}/project
make clean
make image-nocheck

#install Image
cd ${RELEASEDIR}
rm -rf ${RELEASEDIR}/images
cp ${RELEASEDIR}/project/image/output/images . -rf

cp ${RELEASEDIR}/project/image/output/images /mnt/c/Users/gguzman/Desktop -rf
