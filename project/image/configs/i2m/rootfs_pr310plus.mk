IMAGE_INSTALL_DIR:=$(OUTPUTDIR)
-include $(PROJ_ROOT)/../sdk/verify/application/app.mk
-include $(PROJ_ROOT)/release/customer_tailor/$(CUSTOMER_TAILOR)

LIB_DIR_PATH:=$(PROJ_ROOT)/release/$(PRODUCT)/$(CHIP)/common/$(TOOLCHAIN)/$(TOOLCHAIN_VERSION)

.PHONY: rootfs root app
rootfs:root app
root:
	cd rootfs; tar xf rootfs.tar.gz -C $(OUTPUTDIR)
	cp rootfs_add_files/* $(OUTPUTDIR)/rootfs/ -rf
	sed -i 's/\#PermitRootLogin prohibit-password/PermitRootLogin yes/' $(OUTPUTDIR)/rootfs/etc/ssh/sshd_config
	# foe no login
	sed -i 's/console\:\:respawn\:\/sbin\/getty -L  console 0 vt100 \# GENERIC_SERIAL/console::respawn:-\/bin\/sh/' $(OUTPUTDIR)/rootfs/etc/inittab
	#tar xf busybox/$(BUSYBOX).tar.gz -C $(OUTPUTDIR)/rootfs
	tar -xvf libgpiod/$(LIBGPIOD).tar.gz -C $(OUTPUTDIR)/rootfs
	tar xf $(LIB_DIR_PATH)/package/$(LIBC).tar.gz -C $(OUTPUTDIR)/rootfs/lib
	mkdir -p $(miservice$(RESOUCE))/lib
	cp $(LIB_DIR_PATH)/mi_libs/dynamic/* $(miservice$(RESOUCE))/lib/
	cp $(LIB_DIR_PATH)/ex_libs/dynamic/* $(miservice$(RESOUCE))/lib/
	
	mkdir -p $(miservice$(RESOUCE))
	if [ "$(BOARD)" = "010A" ]; then \
		cp -rf $(PROJ_ROOT)/board/ini/* $(miservice$(RESOUCE)) ;\
	else \
		cp -rf $(PROJ_ROOT)/board/ini/LCM $(miservice$(RESOUCE)) ;\
	fi;

	if [ "$(BOARD)" = "010A" ]; then \
		cp -rf $(PROJ_ROOT)/board/$(CHIP)/$(BOARD_NAME)/config/* $(miservice$(RESOUCE)) ; \
	else \
		cp -rf $(PROJ_ROOT)/board/$(CHIP)/$(BOARD_NAME)/config/fbdev.ini  $(miservice$(RESOUCE)) ; \
	fi;

	cp -vf $(PROJ_ROOT)/board/$(CHIP)/mmap/$(MMAP)  $(miservice$(RESOUCE))/mmap.ini
	cp -rvf $(LIB_DIR_PATH)/bin/config_tool/*  $(miservice$(RESOUCE))
	cd  $(miservice$(RESOUCE)); chmod +x config_tool; ln -sf config_tool dump_config; ln -sf config_tool dump_mmap
	if [ "$(BOARD)" = "010A" ]; then \
		cp -rf $(PROJ_ROOT)/board/$(CHIP)/pq  $(miservice$(RESOUCE))/ ; \
		find   $(miservice$(RESOUCE))/pq/ -type f ! -name "Main.bin" -type f ! -name "Main_Ex.bin" -type f ! -name "Bandwidth_RegTable.bin"| xargs rm -rf ; \
	fi;

	if [ $(interface_vdec) = "enable" ]; then \
		cp -rf $(PROJ_ROOT)/board/$(CHIP)/vdec_fw  $(miservice$(RESOUCE))/ ; \
	fi;

	mkdir -p $(OUTPUTDIR)/rootfs/config
	#cp -rf etc/* $(OUTPUTDIR)/rootfs/etc
	if [ "$(appconfigs$(RESOUCE))" != "" ]; then \
		mkdir -p  $(appconfigs$(RESOUCE)); \
		mkdir -p $(OUTPUTDIR)/rootfs/appconfigs;\
	fi;
	
	if [ $(BENCH) = "yes" ]; then \
		cp -rf /home/edie.chen/bench  $(miservice$(RESOUCE)) ; \
		cp  $(miservice$(RESOUCE))/bench/demo.bash  $(miservice$(RESOUCE))/bench.sh ; \
		chmod 755  $(miservice$(RESOUCE))/bench.sh ; \
	fi;

	if [ "$(PHY_TEST)" = "yes" ]; then \
		mkdir  $(miservice$(RESOUCE))/sata_phy ; \
		cp $(LIB_DIR_PATH)/bin/sata_phy/*  $(miservice$(RESOUCE))/sata_phy ; \
	fi;

	mkdir -p $(OUTPUTDIR)/rootfs/lib/modules/
	mkdir -p  $(miservice$(RESOUCE))/modules/$(KERNEL_VERSION)

	touch ${OUTPUTDIR}/rootfs/etc/mdev.conf
	echo mice 0:0 0660 =input/ >> ${OUTPUTDIR}/rootfs/etc/mdev.conf
	echo mouse.* 0:0 0660 =input/ >> ${OUTPUTDIR}/rootfs/etc/mdev.conf
	echo event.* 0:0 0660 =input/ >> ${OUTPUTDIR}/rootfs/etc/mdev.conf
	# for alsa
	#echo pcm.* 0:0 0660 =snd/ >> ${OUTPUTDIR}/rootfs/etc/mdev.conf
	#echo control.* 0:0 0660 =snd/ >> ${OUTPUTDIR}/rootfs/etc/mdev.conf
	#echo timer 0:0 0660 =snd/ >> ${OUTPUTDIR}/rootfs/etc/mdev.conf
	# for usb devs
	echo '$$DEVNAME=bus/usb/([0-9]+)/([0-9]+) 0:0 0660 @/etc/hotplug/usb_devs' >> ${OUTPUTDIR}/rootfs/etc/mdev.conf
	echo sd[a-z][0-9]  0:0  660  @/etc/hotplug/udisk_insert >> ${OUTPUTDIR}/rootfs/etc/mdev.conf
	echo sd[a-z]       0:0  660  \$$/etc/hotplug/udisk_remove >> ${OUTPUTDIR}/rootfs/etc/mdev.conf 	
	echo mmcblk[0-9]p[0-9]  0:0  660  @/etc/hotplug/sdcard_insert >> ${OUTPUTDIR}/rootfs/etc/mdev.conf
	echo mmcblk[0-9]        0:0  660   \$$/etc/hotplug/sdcard_remove >> ${OUTPUTDIR}/rootfs/etc/mdev.conf
	#echo '.* 0:0 660 @/etc/hotplug/test' >> ${OUTPUTDIR}/rootfs/etc/mdev.conf

	echo export PATH=\$$PATH:/config >> ${OUTPUTDIR}/rootfs/etc/init.d/rcS
	echo export TERMINFO=/config/terminfo >> ${OUTPUTDIR}/rootfs/etc/init.d/rcS
	echo export LD_LIBRARY_PATH=\$$LD_LIBRARY_PATH:/config/lib:/config/wifi >> ${OUTPUTDIR}/rootfs/etc/init.d/rcS
	echo export LD_LIBRARY_PATH=\$$LD_LIBRARY_PATH:/config/lib:/config/wifi >> ${OUTPUTDIR}/rootfs/etc/profile
	sed -i '/^mount.*/d' $(OUTPUTDIR)/rootfs/etc/init.d/rcS
	echo mkdir -p /dev/pts >> ${OUTPUTDIR}/rootfs/etc/init.d/rcS
	echo mount -t sysfs none /sys >> $(OUTPUTDIR)/rootfs/etc/init.d/rcS
	echo mount -t tmpfs mdev /dev >> $(OUTPUTDIR)/rootfs/etc/init.d/rcS
	echo mount -t debugfs none /sys/kernel/debug/ >>  $(OUTPUTDIR)/rootfs/etc/init.d/rcS
	echo mdev -s >> $(OUTPUTDIR)/rootfs/etc/init.d/rcS
	cp -rvf $(PROJ_ROOT)/tools/$(TOOLCHAIN)/$(TOOLCHAIN_VERSION)/fw_printenv/* $(OUTPUTDIR)/rootfs/etc/
	echo "$(ENV_CFG)" > $(OUTPUTDIR)/rootfs/etc/fw_env.config
	if [ "$(ENV_CFG1)" != "" ]; then \
		echo "$(ENV_CFG1)" >> $(OUTPUTDIR)/rootfs/etc/fw_env.config ; \
	fi;
	cd $(OUTPUTDIR)/rootfs/etc/;ln -sf fw_printenv fw_setenv
	echo mkdir -p /var/lock >> ${OUTPUTDIR}/rootfs/etc/init.d/rcS
	echo -e $(foreach block, $(USR_MOUNT_BLOCKS), "mount -t $($(block)$(FSTYPE)) $($(block)$(MOUNTPT)) $($(block)$(MOUNTTG))\n") >> $(OUTPUTDIR)/rootfs/etc/init.d/rcS

	#	GPIOs
	echo "" >> $(OUTPUTDIR)/rootfs/etc/init.d/rcS; \
	echo "echo 13 > /sys/class/gpio/export" >> $(OUTPUTDIR)/rootfs/etc/init.d/rcS; \
	echo "echo out > /sys/class/gpio/gpio13/direction" >> $(OUTPUTDIR)/rootfs/etc/init.d/rcS; \
	echo "echo 1 > /sys/class/gpio/gpio13/value" >> $(OUTPUTDIR)/rootfs/etc/init.d/rcS; \
	# echo "echo 14 > /sys/class/gpio/export" >> $(OUTPUTDIR)/rootfs/etc/init.d/rcS; \
	# echo "echo out > /sys/class/gpio/gpio14/direction" >> $(OUTPUTDIR)/rootfs/etc/init.d/rcS; \
	# echo "echo 1 > /sys/class/gpio/gpio14/value" >> $(OUTPUTDIR)/rootfs/etc/init.d/rcS; \
	echo "echo 86 > /sys/class/gpio/export" >> $(OUTPUTDIR)/rootfs/etc/init.d/rcS; \
	echo "echo out > /sys/class/gpio/gpio86/direction" >> $(OUTPUTDIR)/rootfs/etc/init.d/rcS; \
	echo "echo 1 > /sys/class/gpio/gpio86/value" >> $(OUTPUTDIR)/rootfs/etc/init.d/rcS; \
	echo "" >> $(OUTPUTDIR)/rootfs/etc/init.d/rcS; \

	chmod 755 $(LIB_DIR_PATH)/bin/debug/*
	cp -rf $(LIB_DIR_PATH)/bin/debug/*  $(miservice$(RESOUCE))
	rm -rf $(OUTPUTDIR)/customer/pr310_init.sh
	mkdir -p $(OUTPUTDIR)/customer
	touch $(OUTPUTDIR)/customer/pr310_init.sh
	chmod 755 $(OUTPUTDIR)/customer/pr310_init.sh


	# creat insmod ko scrpit
	if [ -f "$(PROJ_ROOT)/kbuild/$(KERNEL_VERSION)/$(CHIP)/configs/$(PRODUCT)/$(BOARD)/$(TOOLCHAIN)/$(TOOLCHAIN_VERSION)/$(FLASH_TYPE)/modules/kernel_mod_list" ]; then \
		cat $(PROJ_ROOT)/kbuild/$(KERNEL_VERSION)/$(CHIP)/configs/$(PRODUCT)/$(BOARD)/$(TOOLCHAIN)/$(TOOLCHAIN_VERSION)/$(FLASH_TYPE)/modules/kernel_mod_list | \
			sed 's#\(.*\).ko#insmod /config/modules/$(KERNEL_VERSION)/\1.ko#' > $(OUTPUTDIR)/customer/pr310_init.sh; \
		cat $(PROJ_ROOT)/kbuild/$(KERNEL_VERSION)/$(CHIP)/configs/$(PRODUCT)/$(BOARD)/$(TOOLCHAIN)/$(TOOLCHAIN_VERSION)/$(FLASH_TYPE)/modules/kernel_mod_list | \
			sed 's#\(.*\).ko\(.*\)#$(PROJ_ROOT)/kbuild/$(KERNEL_VERSION)/$(CHIP)/configs/$(PRODUCT)/$(BOARD)/$(TOOLCHAIN)/$(TOOLCHAIN_VERSION)/$(FLASH_TYPE)/modules/\1.ko#' | \
				xargs -i cp -rvf {}  $(miservice$(RESOUCE))/modules/$(KERNEL_VERSION); \
		echo "#kernel_mod_list" >> $(OUTPUTDIR)/customer/pr310_init.sh; \
	fi;

	if [ -f "$(LIB_DIR_PATH)/modules/$(KERNEL_VERSION)/misc_mod_list" ]; then \
		cat $(LIB_DIR_PATH)/modules/$(KERNEL_VERSION)/misc_mod_list | \
			sed 's#\(.*\).ko#insmod /config/modules/$(KERNEL_VERSION)/\1.ko#' >> $(OUTPUTDIR)/customer/pr310_init.sh; \
		cat $(LIB_DIR_PATH)/modules/$(KERNEL_VERSION)/misc_mod_list | \
			sed 's#\(.*\).ko\(.*\)#$(LIB_DIR_PATH)/modules/$(KERNEL_VERSION)/\1.ko#' | \
				xargs -i cp -rvf {}  $(miservice$(RESOUCE))/modules/$(KERNEL_VERSION); \
		echo "#misc_mod_list" >> $(OUTPUTDIR)/customer/pr310_init.sh; \
	fi;

	if [ -f "$(LIB_DIR_PATH)/modules/$(KERNEL_VERSION)/.mods_depend" ]; then \
		cat $(LIB_DIR_PATH)/modules/$(KERNEL_VERSION)/.mods_depend | \
			sed '2,20s#\(.*\)#insmod /config/modules/$(KERNEL_VERSION)/\1.ko\nif [ $$? -eq 0 ]; then\n	busybox mknod /dev/\1 c $$major $$minor\n	let minor++\nfi\n\n#' >> $(OUTPUTDIR)/customer/pr310_init.sh; \
		cat $(LIB_DIR_PATH)/modules/$(KERNEL_VERSION)/.mods_depend | \
			sed 's#\(.*\)#$(LIB_DIR_PATH)/modules/$(KERNEL_VERSION)/\1.ko#' | \
				xargs -i cp -rvf {}  $(miservice$(RESOUCE))/modules/$(KERNEL_VERSION); \
		echo "#mi module" >> $(OUTPUTDIR)/customer/pr310_init.sh; \
	fi;

	# if [ "$(PROJECT)" = "2D07" ]; then \
	# 	cp ../../kernel/drivers/sstar/gpio_key_sample/gpio_led_heartbeat/gpio_led_heartbeat.ko $(miservice$(RESOUCE))/modules/$(KERNEL_VERSION);\
	# 	echo "insmod /config/modules/4.9.84/gpio_led_heartbeat.ko" >> $(OUTPUTDIR)/customer/pr310_init.sh; \
	# elif [ "$(PROJECT)" = "2D06" ]; then \
	# 	cp ../../kernel/drivers/sstar/gpio_key_sample/gpio_led_heartbeat_2D06/gpio_led_heartbeat.ko $(miservice$(RESOUCE))/modules/$(KERNEL_VERSION);\
	# 	echo "insmod /config/modules/4.9.84/gpio_led_heartbeat.ko" >> $(OUTPUTDIR)/customer/pr310_init.sh; \
	# fi;

	# # for alsa
	# # 1.copy ko
	# cp $(PROJ_ROOT)/../kernel/modules/soundcore.ko $(miservice$(RESOUCE))/modules/$(KERNEL_VERSION)
	# cp $(PROJ_ROOT)/../kernel/modules/snd.ko $(miservice$(RESOUCE))/modules/$(KERNEL_VERSION)
	# cp $(PROJ_ROOT)/../kernel/modules/snd-timer.ko $(miservice$(RESOUCE))/modules/$(KERNEL_VERSION)
	# cp $(PROJ_ROOT)/../kernel/modules/snd-pcm.ko $(miservice$(RESOUCE))/modules/$(KERNEL_VERSION)
	# # 2.insmod ko when boot finish
	# echo "insmod  /config/modules/4.9.84/soundcore.ko" >> $(OUTPUTDIR)/customer/pr310_init.sh
	# echo "insmod  /config/modules/4.9.84/snd.ko" >> $(OUTPUTDIR)/customer/pr310_init.sh
	# echo "insmod  /config/modules/4.9.84/snd-timer.ko" >> $(OUTPUTDIR)/customer/pr310_init.sh
	# echo "insmod  /config/modules/4.9.84/snd-pcm.ko" >> $(OUTPUTDIR)/customer/pr310_init.sh

	if [ -f "$(LIB_DIR_PATH)/modules/$(KERNEL_VERSION)/misc_mod_list_late" ]; then \
		cat $(LIB_DIR_PATH)/modules/$(KERNEL_VERSION)/misc_mod_list_late | sed 's#\(.*\).ko#insmod /config/modules/$(KERNEL_VERSION)/\1.ko#' >> $(OUTPUTDIR)/customer/pr310_init.sh; \
		cat $(LIB_DIR_PATH)/modules/$(KERNEL_VERSION)/misc_mod_list_late | sed 's#\(.*\).ko\(.*\)#$(LIB_DIR_PATH)/modules/$(KERNEL_VERSION)/\1.ko#' | \
			xargs -i cp -rvf {}  $(miservice$(RESOUCE))/modules/$(KERNEL_VERSION); \
		echo "#misc_mod_list_late" >> $(OUTPUTDIR)/customer/pr310_init.sh; \
	fi;

	sed -i 's/mi_common/insmod \/config\/modules\/$(KERNEL_VERSION)\/mi_common.ko\nmajor=\`cat \/proc\/devices \| busybox awk "\\\\$$2==\\""mi"\\" {print \\\\$$1}"\\n`\nminor=0/g' $(OUTPUTDIR)/customer/pr310_init.sh; \
	sed -i '/#mi module/a	major=`cat /proc/devices | busybox awk "\\\\$$2==\\""mi_poll"\\" {print \\\\$$1}"`\nbusybox mknod \/dev\/mi_poll c $$major 0' $(OUTPUTDIR)/customer/pr310_init.sh; \
	if [ $(PHY_TEST) = "yes" ]; then \
		echo -e "\033[41;33;5m !!! Replace "mdrv-sata-host.ko" with "sata_bench_test.ko" !!!\033[0m" ; \
		sed '/mdrv-sata-host/d' $(OUTPUTDIR)/customer/pr310_init.sh >  $(miservice$(RESOUCE))/demotemp.sh ; \
		echo insmod /config/sata_phy/sata_bench_test.ko >>  $(miservice$(RESOUCE))/demotemp.sh ; \
		cp  $(miservice$(RESOUCE))/demotemp.sh $(OUTPUTDIR)/customer/pr310_init.sh ; \
		rm  $(miservice$(RESOUCE))/demotemp.sh ; \
	fi;

	if [ $(interface_wlan) = "enable" ]; then \
		mkdir -p  $(miservice$(RESOUCE))/wifi ; \
		if [ $(FLASH_TYPE) = "spinand" ]; then \
			cp -rf $(LIB_DIR_PATH)/wifi/libs/ap/*   $(miservice$(RESOUCE))/wifi ; \
			cp -rf $(LIB_DIR_PATH)/wifi/bin/ap/*   $(miservice$(RESOUCE))/wifi ; \
		fi;	\
		find $(LIB_DIR_PATH)/wifi/bin/ -maxdepth 1 -type f -exec cp -P {}  $(miservice$(RESOUCE))/wifi \; ;\
		find $(LIB_DIR_PATH)/wifi/bin/ -maxdepth 1 -type l -exec cp -P {}  $(miservice$(RESOUCE))/wifi \; ;\
		find $(LIB_DIR_PATH)/wifi/libs/ -maxdepth 1 -type f -exec cp -P {}  $(miservice$(RESOUCE))/wifi \; ;\
		find $(LIB_DIR_PATH)/wifi/libs/ -maxdepth 1 -type l -exec cp -P {}  $(miservice$(RESOUCE))/wifi \; ;\
		cp -rf $(LIB_DIR_PATH)/wifi/modules/*   $(miservice$(RESOUCE))/wifi ; \
		cp -rf $(LIB_DIR_PATH)/wifi/configs/*   $(miservice$(RESOUCE))/wifi ; \
	fi;
	if [ "$(appconfigs$(RESOUCE))" != "" ]; then \
		if [ -f "$(miservice$(RESOUCE))/wifi/wpa_supplicant.conf" ]; then	\
			mv  $(miservice$(RESOUCE))/wifi/wpa_supplicant.conf $(appconfigs$(RESOUCE));	\
			cp $(OUTPUTDIR)/appconfigs/wpa_supplicant.conf $(appconfigs$(RESOUCE))/wpa_supplicant.conf_bak;	\
		fi;	\
		cp -rf $(PROJ_ROOT)/board/$(CHIP)/$(BOARD_NAME)/config/model/LCM.ini $(appconfigs$(RESOUCE));	\
	fi;
	# Enable MIU protect on CMDQ buffer as default (While List: CPU)
	# [I5] The 1st 1MB of MIU is not for CMDQ buffer
#	echo 'echo set_miu_block3_status 0 0x70 0 0x100000 1 > /proc/mi_modules/mi_sys_mma/miu_protect' >>  $(miservice$(RESOUCE))/pr310_init.sh

#	echo mount -t jffs2 /dev/mtdblock3 /config >> $(OUTPUTDIR)/rootfs/etc/profile
	ln -fs /config/modules/$(KERNEL_VERSION) $(OUTPUTDIR)/rootfs/lib/modules/
	find  $(miservice$(RESOUCE))/modules/$(KERNEL_VERSION) -name "*.ko" | xargs $(TOOLCHAIN_REL)strip  --strip-unneeded;
	#find $(OUTPUTDIR)/rootfs/lib/ -name "*.so*" | xargs $(TOOLCHAIN_REL)strip  --strip-unneeded;
	find $(OUTPUTDIR)/rootfs/lib/ -name "*.so*" -a -name "*[!p][!y]" | xargs $(TOOLCHAIN_REL)strip  --strip-unneeded;
	echo mkdir -p /dev/pts >> $(OUTPUTDIR)/rootfs/etc/init.d/rcS
	echo mount -t devpts devpts /dev/pts >> $(OUTPUTDIR)/rootfs/etc/init.d/rcS
	echo "busybox telnetd&" >> $(OUTPUTDIR)/rootfs/etc/init.d/rcS

	if [ "$(FLASH_WP_RANGE)" != "" ]; then \
		echo "if [ -e  /sys/class/mstar/msys/protect ]; then" >> $(OUTPUTDIR)/rootfs/etc/init.d/rcS ; \
		echo "    echo $(FLASH_WP_RANGE) > /sys/class/mstar/msys/protect" >> $(OUTPUTDIR)/rootfs/etc/init.d/rcS ; \
		echo "fi;" >> $(OUTPUTDIR)/rootfs/etc/init.d/rcS ; \
	fi;

	echo "if [ -e /etc/core.sh ]; then" >> ${OUTPUTDIR}/rootfs/etc/init.d/rcS
	echo '    echo "|/etc/core.sh %p" > /proc/sys/kernel/core_pattern' >> ${OUTPUTDIR}/rootfs/etc/init.d/rcS
	echo "chmod 777 /etc/core.sh" >> ${OUTPUTDIR}/rootfs/etc/init.d/rcS
	echo "fi;" >> ${OUTPUTDIR}/rootfs/etc/init.d/rcS
	
	echo "if [ -e /customer/pr310_init.sh ]; then" >> $(OUTPUTDIR)/rootfs/etc/init.d/rcS
	echo "    /customer/pr310_init.sh" >> $(OUTPUTDIR)/rootfs/etc/init.d/rcS
	echo "fi;" >> $(OUTPUTDIR)/rootfs/etc/init.d/rcS
	echo mdev -s >> $(OUTPUTDIR)/customer/pr310_init.sh
	if [ $(BENCH) = "yes" ]; then \
		echo ./config/bench.sh >> $(OUTPUTDIR)/customer/pr310_init.sh ; \
	fi;
	if [ "$(BOARD)" = "011A" ]; then \
		sed -i 's/mi_sys.ko/mi_sys.ko cmdQBufSize=128 logBufSize=0/g' $(OUTPUTDIR)/customer/pr310_init.sh ;\
	fi;
	if [ $(TOOLCHAIN) = "glibc" ]; then \
		cp -rvf $(PROJ_ROOT)/tools/$(TOOLCHAIN)/$(TOOLCHAIN_VERSION)/htop/terminfo $(OUTPUTDIR)/miservice/config/;	\
		cp -rvf $(PROJ_ROOT)/tools/$(TOOLCHAIN)/$(TOOLCHAIN_VERSION)/htop/htop $(OUTPUTDIR)/customer/;	\
		echo export TERM=vt102 >> $(OUTPUTDIR)/customer/pr310_init.sh;	\
		echo export TERMINFO=/config/terminfo >> $(OUTPUTDIR)/customer/pr310_init.sh;	\
	fi;
	
	
	#if [ -f "$(PROJ_ROOT)/board/ini/pq.ini" ]; then \
	#	cp $(PROJ_ROOT)/board/ini/pq.ini $(OUTPUTDIR)/customer/; \
	#	echo "echo /customer/pq.ini  0x148 > /sys/class/mstar/mdisp/pq" >> $(OUTPUTDIR)/customer/pr310_init.sh; \
	#fi;

	#Start wifi
	if [ $(interface_wlan) = "enable" ]; then \
		echo "/config/wifi/ssw01bInit.sh" >> $(OUTPUTDIR)/customer/pr310_init.sh; \
	fi;

	#echo "echo 1 > /sys/class/mstar/mdisp/bootlogo" >> $(OUTPUTDIR)/customer/pr310_init.sh
	#echo "cd / & ./logo " >> $(OUTPUTDIR)/customer/pr310_init.sh
	echo "cd / " >> $(OUTPUTDIR)/customer/pr310_init.sh
	
	sed -i '/mi_ai\.ko/ s/^/#/' $(OUTPUTDIR)/customer/pr310_init.sh
	sed -i '/mi_ao\.ko/ s/^/#/' $(OUTPUTDIR)/customer/pr310_init.sh
	sed -i '/mi_disp\.ko/ s/^/#/' $(OUTPUTDIR)/customer/pr310_init.sh
	sed -i '/mi_panel\.ko/ s/^/#/' $(OUTPUTDIR)/customer/pr310_init.sh
	sed -i '/mi_alsa\.ko/ s/^/#/' $(OUTPUTDIR)/customer/pr310_init.sh
	sed -i '/fbdev\.ko/ s/^/#/' $(OUTPUTDIR)/customer/pr310_init.sh
	
	mkdir -p $(OUTPUTDIR)/vendor
	mkdir -p $(OUTPUTDIR)/customer
	mkdir -p $(OUTPUTDIR)/rootfs/vendor
	mkdir -p $(OUTPUTDIR)/rootfs/customer
