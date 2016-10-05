#!/bin/sh -e
#
# Copyright (c) 2009-2016 Robert Nelson <robertcnelson@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# Split out, so build_kernel.sh and build_deb.sh can share..

shopt -s nullglob

. ${DIR}/version.sh
if [ -f ${DIR}/system.sh ] ; then
	. ${DIR}/system.sh
fi
git_bin=$(which git)
#git hard requirements:
#git: --no-edit

git="${git_bin} am"
#git_patchset=""
#git_opts

if [ "${RUN_BISECT}" ] ; then
	git="${git_bin} apply"
fi

echo "Starting patch.sh"

#merged_in_4_5="enable"
unset merged_in_4_5
#merged_in_4_6="enable"
unset merged_in_4_6

git_add () {
	${git_bin} add .
	${git_bin} commit -a -m 'testing patchset'
}

start_cleanup () {
	git="${git_bin} am --whitespace=fix"
}

cleanup () {
	if [ "${number}" ] ; then
		if [ "x${wdir}" = "x" ] ; then
			${git_bin} format-patch -${number} -o ${DIR}/patches/
		else
			${git_bin} format-patch -${number} -o ${DIR}/patches/${wdir}/
			unset wdir
		fi
	fi
	exit 2
}

dir () {
	wdir="$1"
	if [ -d "${DIR}/patches/$wdir" ]; then
		echo "dir: $wdir"

		if [ "x${regenerate}" = "xenable" ] ; then
			start_cleanup
		fi

		number=
		for p in "${DIR}/patches/$wdir/"*.patch; do
			${git} "$p"
			number=$(( $number + 1 ))
		done

		if [ "x${regenerate}" = "xenable" ] ; then
			cleanup
		fi
	fi
	unset wdir
}

cherrypick () {
	if [ ! -d ../patches/${cherrypick_dir} ] ; then
		mkdir -p ../patches/${cherrypick_dir}
	fi
	${git_bin} format-patch -1 ${SHA} --start-number ${num} -o ../patches/${cherrypick_dir}
	num=$(($num+1))
}

external_git () {
	git_tag=""
	echo "pulling: ${git_tag}"
	${git_bin} pull --no-edit ${git_patchset} ${git_tag}
}

aufs_fail () {
	echo "aufs4 failed"
	exit 2
}

aufs4 () {
	echo "dir: aufs4"
	#regenerate="enable"
	if [ "x${regenerate}" = "xenable" ] ; then
		wget https://raw.githubusercontent.com/sfjro/aufs4-standalone/aufs${KERNEL_REL}/aufs4-kbuild.patch
		patch -p1 < aufs4-kbuild.patch || aufs_fail
		rm -rf aufs4-kbuild.patch
		${git_bin} add .
		${git_bin} commit -a -m 'merge: aufs4-kbuild' -s

		wget https://raw.githubusercontent.com/sfjro/aufs4-standalone/aufs${KERNEL_REL}/aufs4-base.patch
		patch -p1 < aufs4-base.patch || aufs_fail
		rm -rf aufs4-base.patch
		${git_bin} add .
		${git_bin} commit -a -m 'merge: aufs4-base' -s

		wget https://raw.githubusercontent.com/sfjro/aufs4-standalone/aufs${KERNEL_REL}/aufs4-mmap.patch
		patch -p1 < aufs4-mmap.patch || aufs_fail
		rm -rf aufs4-mmap.patch
		${git_bin} add .
		${git_bin} commit -a -m 'merge: aufs4-mmap' -s

		wget https://raw.githubusercontent.com/sfjro/aufs4-standalone/aufs${KERNEL_REL}/aufs4-standalone.patch
		patch -p1 < aufs4-standalone.patch || aufs_fail
		rm -rf aufs4-standalone.patch
		${git_bin} add .
		${git_bin} commit -a -m 'merge: aufs4-standalone' -s

		${git_bin} format-patch -4 -o ../patches/aufs4/
		exit 2
	fi

	${git} "${DIR}/patches/aufs4/0001-merge-aufs4-kbuild.patch"
	${git} "${DIR}/patches/aufs4/0002-merge-aufs4-base.patch"
	${git} "${DIR}/patches/aufs4/0003-merge-aufs4-mmap.patch"
	${git} "${DIR}/patches/aufs4/0004-merge-aufs4-standalone.patch"

	#regenerate="enable"
	if [ "x${regenerate}" = "xenable" ] ; then
		echo "dir: aufs4"

		cd ../
		if [ ! -f ./aufs4-standalone ] ; then
			${git_bin} clone https://github.com/sfjro/aufs4-standalone
			cd ./aufs4-standalone
			${git_bin} checkout origin/aufs${KERNEL_REL} -b tmp
			cd ../
		fi
		cd ./KERNEL/

		cp -v ../aufs4-standalone/Documentation/ABI/testing/*aufs ./Documentation/ABI/testing/
		mkdir -p ./Documentation/filesystems/aufs/
		cp -rv ../aufs4-standalone/Documentation/filesystems/aufs/* ./Documentation/filesystems/aufs/
		mkdir -p ./fs/aufs/
		cp -v ../aufs4-standalone/fs/aufs/* ./fs/aufs/
		cp -v ../aufs4-standalone/include/uapi/linux/aufs_type.h ./include/uapi/linux/

		${git_bin} add .
		${git_bin} commit -a -m 'merge: aufs4' -s
		${git_bin} format-patch -5 -o ../patches/aufs4/

		exit 2
	fi

	#regenerate="enable"
	if [ "x${regenerate}" = "xenable" ] ; then
		start_cleanup
	fi

	${git} "${DIR}/patches/aufs4/0005-merge-aufs4.patch"

	if [ "x${regenerate}" = "xenable" ] ; then
		${git_bin} format-patch -5 -o ../patches/aufs4/
		exit 2
	fi
}

rt_cleanup () {
	echo "rt: needs fixup"
	exit 2
}

rt () {
	echo "dir: rt"
	rt_patch="${KERNEL_REL}${kernel_rt}"
	#regenerate="enable"
	if [ "x${regenerate}" = "xenable" ] ; then
		wget -c https://www.kernel.org/pub/linux/kernel/projects/rt/${KERNEL_REL}/patch-${rt_patch}.patch.xz
		xzcat patch-${rt_patch}.patch.xz | patch -p1 || rt_cleanup
		rm -f patch-${rt_patch}.patch.xz
		rm -f localversion-rt
		${git_bin} add .
		${git_bin} commit -a -m 'merge: CONFIG_PREEMPT_RT Patch Set' -s
		${git_bin} format-patch -1 -o ../patches/rt/

		exit 2
	fi

	${git} "${DIR}/patches/rt/0001-merge-CONFIG_PREEMPT_RT-Patch-Set.patch"
}

#external_git
#aufs4
#rt

reverts () {
	echo "dir: reverts"
	#regenerate="enable"
	if [ "x${regenerate}" = "xenable" ] ; then
		start_cleanup
	fi

	${git} "${DIR}/patches/reverts/0001-Revert-spi-spidev-Warn-loudly-if-instantiated-from-D.patch"

	if [ "x${regenerate}" = "xenable" ] ; then
		number=1
		cleanup
	fi
}

pre_backports () {
	echo "dir: backports/${subsystem}"

	cd ~/linux-src/
	${git_bin} pull --no-edit https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git master
	${git_bin} pull --no-edit https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git master --tags
	${git_bin} pull --no-edit https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git master --tags
	if [ ! "x${backport_tag}" = "x" ] ; then
		${git_bin} checkout ${backport_tag} -b tmp
	fi
	cd -
}

post_backports () {
	if [ ! "x${backport_tag}" = "x" ] ; then
		cd ~/linux-src/
		${git_bin} checkout master -f ; ${git_bin} branch -D tmp
		cd -
	fi

	${git_bin} add .
	${git_bin} commit -a -m "backports: ${subsystem}: from: linux.git" -s
	if [ ! -d ../patches/backports/${subsystem}/ ] ; then
		mkdir -p ../patches/backports/${subsystem}/
	fi
	${git_bin} format-patch -1 -o ../patches/backports/${subsystem}/

	exit 2
}

patch_backports (){
	echo "dir: backports/${subsystem}"
	${git} "${DIR}/patches/backports/${subsystem}/0001-backports-${subsystem}-from-linux.git.patch"
}

backports () {
	backport_tag="v4.x-y"

	subsystem="xyz"
	#regenerate="enable"
	if [ "x${regenerate}" = "xenable" ] ; then
		pre_backports

		cp -v ~/linux-src/x/ ./x/

		post_backports
	fi
	patch_backports
}

ti () {
	is_mainline="enable"
	if [ "x${is_mainline}" = "xenable" ] ; then
		echo "dir: ti/iodelay/"
		#regenerate="enable"
		if [ "x${regenerate}" = "xenable" ] ; then
			start_cleanup
		fi

		${git} "${DIR}/patches/ti/iodelay/0001-pinctrl-bindings-pinctrl-Add-support-for-TI-s-IODela.patch"
		${git} "${DIR}/patches/ti/iodelay/0002-pinctrl-Introduce-TI-IOdelay-configuration-driver.patch"
		${git} "${DIR}/patches/ti/iodelay/0003-ARM-dts-dra7-Add-iodelay-module.patch"

		if [ "x${regenerate}" = "xenable" ] ; then
			number=3
			cleanup
		fi
	fi

	if [ "x${is_mainline}" = "xenable" ] ; then
		echo "dir: ti/ticpufreq/"
		#regenerate="enable"
		if [ "x${regenerate}" = "xenable" ] ; then
			start_cleanup
		fi

		${git} "${DIR}/patches/ti/ticpufreq/0001-Documentation-dt-add-bindings-for-ti-cpufreq.patch"
		${git} "${DIR}/patches/ti/ticpufreq/0002-cpufreq-ti-Add-cpufreq-driver-to-determine-available.patch"

		if [ "x${regenerate}" = "xenable" ] ; then
			wdir="ti/ticpufreq"
			number=2
			cleanup
		fi
	fi
	unset is_mainline

	echo "dir: ti/dtbs"
	#regenerate="enable"
	if [ "x${regenerate}" = "xenable" ] ; then
		start_cleanup
	fi

	${git} "${DIR}/patches/ti/dtbs/0001-sync-with-ti-4.4.patch"

	if [ "x${regenerate}" = "xenable" ] ; then
		number=1
		cleanup
	fi
}

pru_uio () {
	echo "dir: pru_uio"
	#regenerate="enable"
	if [ "x${regenerate}" = "xenable" ] ; then
		start_cleanup
	fi

	${git} "${DIR}/patches/pru_uio/0001-Making-the-uio-pruss-driver-work.patch"

	if [ "x${regenerate}" = "xenable" ] ; then
		number=1
		cleanup
	fi
}

pru_rpmsg () {
	echo "dir: pru_rpmsg"
	#regenerate="enable"
	if [ "x${regenerate}" = "xenable" ] ; then
		start_cleanup
	fi

	#${git} "${DIR}/patches/pru_rpmsg/0001-Fix-remoteproc-to-work-with-the-PRU-GNU-Binutils-por.patch"
#http://git.ti.com/gitweb/?p=ti-linux-kernel/ti-linux-kernel.git;a=commit;h=c2e6cfbcf2aafc77e9c7c8f1a3d45b062bd21876
#	${git} "${DIR}/patches/pru_rpmsg/0002-Add-rpmsg_pru-support.patch"
	${git} "${DIR}/patches/pru_rpmsg/0003-ARM-samples-seccomp-no-m32.patch"

	if [ "x${regenerate}" = "xenable" ] ; then
		number=3
		cleanup
	fi
}

bbb_overlays () {
	echo "dir: bbb_overlays"
	#regenerate="enable"
	if [ "x${regenerate}" = "xenable" ] ; then
		start_cleanup
	fi

	${git} "${DIR}/patches/bbb_overlays/0001-scripts-dtc-Update-to-upstream-version-1.4.1-Overlay.patch"
	${git} "${DIR}/patches/bbb_overlays/0002-gitignore-Ignore-DTB-files.patch"

	if [ "x${regenerate}" = "xenable" ] ; then
	${git} "${DIR}/patches/bbb_overlays/0003-add-PM-firmware.patch"
	${git} "${DIR}/patches/bbb_overlays/0004-ARM-CUSTOM-Build-a-uImage-with-dtb-already-appended.patch"
	fi

	${git} "${DIR}/patches/bbb_overlays/0005-omap-Fix-crash-when-omap-device-is-disabled.patch"
	${git} "${DIR}/patches/bbb_overlays/0006-serial-omap-Fix-port-line-number-without-aliases.patch"
	${git} "${DIR}/patches/bbb_overlays/0007-tty-omap-serial-Fix-up-platform-data-alloc.patch"
	${git} "${DIR}/patches/bbb_overlays/0008-of-Custom-printk-format-specifier-for-device-node.patch"
	${git} "${DIR}/patches/bbb_overlays/0009-of-overlay-kobjectify-overlay-objects.patch"
	${git} "${DIR}/patches/bbb_overlays/0010-of-overlay-global-sysfs-enable-attribute.patch"
	${git} "${DIR}/patches/bbb_overlays/0011-Documentation-ABI-overlays-global-attributes.patch"
	${git} "${DIR}/patches/bbb_overlays/0012-Documentation-document-of_overlay_disable-parameter.patch"
	${git} "${DIR}/patches/bbb_overlays/0013-of-overlay-add-per-overlay-sysfs-attributes.patch"
	${git} "${DIR}/patches/bbb_overlays/0014-Documentation-ABI-overlays-per-overlay-docs.patch"
	${git} "${DIR}/patches/bbb_overlays/0015-of-dynamic-Add-__of_node_dupv.patch"
	${git} "${DIR}/patches/bbb_overlays/0016-of-changesets-Introduce-changeset-helper-methods.patch"
	${git} "${DIR}/patches/bbb_overlays/0017-of-changeset-Add-of_changeset_node_move-method.patch"
	${git} "${DIR}/patches/bbb_overlays/0018-of-unittest-changeset-helpers.patch"
	${git} "${DIR}/patches/bbb_overlays/0019-OF-DT-Overlay-configfs-interface-v7.patch"
	${git} "${DIR}/patches/bbb_overlays/0020-ARM-DT-Enable-symbols-when-CONFIG_OF_OVERLAY-is-used.patch"
	${git} "${DIR}/patches/bbb_overlays/0021-misc-Beaglebone-capemanager.patch"
	${git} "${DIR}/patches/bbb_overlays/0022-doc-misc-Beaglebone-capemanager-documentation.patch"
	${git} "${DIR}/patches/bbb_overlays/0023-doc-dt-beaglebone-cape-manager-bindings.patch"
	${git} "${DIR}/patches/bbb_overlays/0024-doc-ABI-bone_capemgr-sysfs-API.patch"
	${git} "${DIR}/patches/bbb_overlays/0025-MAINTAINERS-Beaglebone-capemanager-maintainer.patch"
	${git} "${DIR}/patches/bbb_overlays/0026-arm-dts-Enable-beaglebone-cape-manager.patch"
	${git} "${DIR}/patches/bbb_overlays/0027-of-overlay-Implement-target-index-support.patch"
	${git} "${DIR}/patches/bbb_overlays/0028-of-unittest-Add-indirect-overlay-target-test.patch"
	${git} "${DIR}/patches/bbb_overlays/0029-doc-dt-Document-the-indirect-overlay-method.patch"
	${git} "${DIR}/patches/bbb_overlays/0030-of-overlay-Introduce-target-root-capability.patch"
	${git} "${DIR}/patches/bbb_overlays/0031-of-unittest-Unit-tests-for-target-root-overlays.patch"
	${git} "${DIR}/patches/bbb_overlays/0032-doc-dt-Document-the-target-root-overlay-method.patch"
	${git} "${DIR}/patches/bbb_overlays/0033-RFC-Device-overlay-manager-PCI-USB-DT.patch"
	${git} "${DIR}/patches/bbb_overlays/0034-of-rename-_node_sysfs-to-_node_post.patch"
	${git} "${DIR}/patches/bbb_overlays/0035-of-Support-hashtable-lookups-for-phandles.patch"
	${git} "${DIR}/patches/bbb_overlays/0036-of-unittest-hashed-phandles-unitest.patch"
	${git} "${DIR}/patches/bbb_overlays/0037-of-overlay-Pick-up-label-symbols-from-overlays.patch"
	${git} "${DIR}/patches/bbb_overlays/0038-of-Portable-Device-Tree-connector.patch"

	if [ "x${regenerate}" = "xenable" ] ; then
	${git} "${DIR}/patches/bbb_overlays/0039-boneblack-defconfig.patch"
	fi

	if [ "x${regenerate}" = "xenable" ] ; then
		wdir="bbb_overlays"
		number=39
		cleanup
	fi
}

dtb_makefile_append () {
	sed -i -e 's:am335x-boneblack.dtb \\:am335x-boneblack.dtb \\\n\t'$device' \\:g' arch/arm/boot/dts/Makefile
}

beaglebone () {
	echo "dir: beaglebone/dts"
	#regenerate="enable"
	if [ "x${regenerate}" = "xenable" ] ; then
		start_cleanup
	fi

	${git} "${DIR}/patches/beaglebone/dts/0001-dts-am335x-bone-common-fixup-leds-to-match-3.8.patch"
	${git} "${DIR}/patches/beaglebone/dts/0002-arm-dts-am335x-bone-common-add-collision-and-carrier.patch"
	${git} "${DIR}/patches/beaglebone/dts/0003-am335x-bone-common-disable-default-clkout2_pin.patch"
	${git} "${DIR}/patches/beaglebone/dts/0004-tps65217-Enable-KEY_POWER-press-on-AC-loss-PWR_BUT.patch"

	if [ "x${regenerate}" = "xenable" ] ; then
		wdir="beaglebone/dts"
		number=4
		cleanup
	fi

	#echo "dir: beaglebone/tps65217"
	##regenerate="enable"
	#if [ "x${regenerate}" = "xenable" ] ; then
	#	start_cleanup
	#fi

	#${git} "${DIR}/patches/beaglebone/tps65217/0001-mfd-tps65217-Add-support-for-IRQs.patch"
	#${git} "${DIR}/patches/beaglebone/tps65217/0002-power_supply-tps65217-charger-Fix-NULL-deref-during-.patch"
	#${git} "${DIR}/patches/beaglebone/tps65217/0003-power_supply-tps65217-charger-Add-support-for-IRQs.patch"
	#${git} "${DIR}/patches/beaglebone/tps65217/0004-mfd-tps65217-Add-power-button-as-subdevice.patch"
	#${git} "${DIR}/patches/beaglebone/tps65217/0005-Input-Add-tps65217-power-button-driver.patch"
	#${git} "${DIR}/patches/beaglebone/tps65217/0006-rtc-omap-Support-ext_wakeup-configuration.patch"

	#if [ "x${regenerate}" = "xenable" ] ; then
	#	wdir="beaglebone/tps65217"
	#	number=6
	#	cleanup
	#fi

	dir 'beaglebone/pinmux-helper'

	echo "dir: beaglebone/overlays"
	#regenerate="enable"
	if [ "x${regenerate}" = "xenable" ] ; then
		start_cleanup
	fi

	${git} "${DIR}/patches/beaglebone/overlays/0001-am335x-overlays.patch"

	if [ "x${regenerate}" = "xenable" ] ; then
		number=1
		cleanup
	fi

	echo "dir: beaglebone/abbbi"
	#regenerate="enable"
	if [ "x${regenerate}" = "xenable" ] ; then
		start_cleanup
	fi

	${git} "${DIR}/patches/beaglebone/abbbi/0001-gpu-drm-i2c-add-alternative-adv7511-driver-with-audi.patch"
	${git} "${DIR}/patches/beaglebone/abbbi/0002-gpu-drm-i2c-adihdmi-componentize-driver-and-huge-ref.patch"
	${git} "${DIR}/patches/beaglebone/abbbi/0003-ARM-dts-add-Arrow-BeagleBone-Black-Industrial-dts.patch"
	${git} "${DIR}/patches/beaglebone/abbbi/0004-drm-adihdmi-Drop-dummy-save-restore-hooks.patch"
	${git} "${DIR}/patches/beaglebone/abbbi/0005-drm-adihdmi-Pass-name-to-drm_encoder_init.patch"
	${git} "${DIR}/patches/beaglebone/abbbi/0006-adihdmi_drv-reg_default-reg_sequence.patch"

	if [ "x${regenerate}" = "xenable" ] ; then
		number=6
		cleanup
	fi

	echo "dir: beaglebone/am335x_olimex_som"
	#regenerate="enable"
	if [ "x${regenerate}" = "xenable" ] ; then
		start_cleanup
	fi

	${git} "${DIR}/patches/beaglebone/am335x_olimex_som/0001-ARM-dts-Add-support-for-Olimex-AM3352-SOM.patch"

	if [ "x${regenerate}" = "xenable" ] ; then
		number=1
		cleanup
	fi

	echo "dir: beaglebone/bbgw"
	#regenerate="enable"
	if [ "x${regenerate}" = "xenable" ] ; then
		start_cleanup
	fi

	${git} "${DIR}/patches/beaglebone/bbgw/0001-add-beaglebone-green-wireless.patch"
	${git} "${DIR}/patches/beaglebone/bbgw/0002-bbgw-wlan0-fixes.patch"

	if [ "x${regenerate}" = "xenable" ] ; then
		number=2
		cleanup
	fi

	echo "dir: beaglebone/sancloud"
	#regenerate="enable"
	if [ "x${regenerate}" = "xenable" ] ; then
		start_cleanup
	fi

	${git} "${DIR}/patches/beaglebone/sancloud/0001-add-am335x-sancloud-bbe.patch"
	${git} "${DIR}/patches/beaglebone/sancloud/0002-am335x-sancloud-bbe-update-lps331ap-mpu6050-irq-pins.patch"

	if [ "x${regenerate}" = "xenable" ] ; then
		number=2
		cleanup
	fi

	echo "dir: beaglebone/tre"
	#regenerate="enable"
	if [ "x${regenerate}" = "xenable" ] ; then
		start_cleanup
	fi

	${git} "${DIR}/patches/beaglebone/tre/0001-add-am335x-arduino-tre.dts.patch"

	if [ "x${regenerate}" = "xenable" ] ; then
		number=1
		cleanup
	fi

	#echo "dir: beaglebone/CTAG"
	#regenerate="enable"
	#if [ "x${regenerate}" = "xenable" ] ; then
	#	start_cleanup
	#fi

	#${git} "${DIR}/patches/beaglebone/CTAG/0001-Added-driver-and-device-tree-for-CTAG-face2-4-Audio-.patch"
	#${git} "${DIR}/patches/beaglebone/CTAG/0002-Added-support-for-higher-sampling-rates-in-AD193X-dr.patch"
	#${git} "${DIR}/patches/beaglebone/CTAG/0003-Added-support-for-AD193X-and-CTAG-face2-4-Audio-Card.patch"
	#${git} "${DIR}/patches/beaglebone/CTAG/0004-Modified-ASOC-platform-driver-for-McASP-to-use-async.patch"
	#${git} "${DIR}/patches/beaglebone/CTAG/0005-Changed-descriptions-in-files-belonging-to-CTAG-face.patch"
	#${git} "${DIR}/patches/beaglebone/CTAG/0006-add-black-version-of-ctag-face-pass-uboot-cape-ctag-.patch"

	#if [ "x${regenerate}" = "xenable" ] ; then
	#	number=6
	#	cleanup
	#fi

	echo "dir: beaglebone/capes"
	#regenerate="enable"
	if [ "x${regenerate}" = "xenable" ] ; then
		start_cleanup
	fi

	${git} "${DIR}/patches/beaglebone/capes/0001-cape-Argus-UPS-cape-support.patch"
	${git} "${DIR}/patches/beaglebone/capes/0002-ARM-dts-am335x-boneblack-enable-wl1835mod-cape-suppo.patch"
	${git} "${DIR}/patches/beaglebone/capes/0003-add-am335x-boneblack-bbbmini.dts.patch"
	${git} "${DIR}/patches/beaglebone/capes/0004-add-lcd-am335x-boneblack-bbb-exp-c.dtb-am335x-bonebl.patch"
	${git} "${DIR}/patches/beaglebone/capes/0005-bb-audio-cape.patch"

	#Replicape use am335x-boneblack-overlay.dtb???

	if [ "x${regenerate}" = "xenable" ] ; then
		number=5
		cleanup
	fi

	echo "dir: beaglebone/jtag"
	#regenerate="enable"
	if [ "x${regenerate}" = "xenable" ] ; then
		start_cleanup
	fi

	${git} "${DIR}/patches/beaglebone/jtag/0001-add-jtag-clock-pinmux.patch"

	if [ "x${regenerate}" = "xenable" ] ; then
		number=1
		cleanup
	fi

	echo "dir: beaglebone/tilcdc"
	#regenerate="enable"
	if [ "x${regenerate}" = "xenable" ] ; then
		start_cleanup
	fi

	${git} "${DIR}/patches/beaglebone/tilcdc/0001-drm-tilcdc-Write-to-LCDC_END_OF_INT_IND_REG-at-the-e.patch"
	${git} "${DIR}/patches/beaglebone/tilcdc/0002-drm-tilcdc-Move-waiting-of-LCDC_FRAME_DONE-IRQ-into-.patch"
	${git} "${DIR}/patches/beaglebone/tilcdc/0003-drm-tilcdc-Recover-from-sync-lost-error-flood-by-res.patch"

	if [ "x${regenerate}" = "xenable" ] ; then
		wdir="beaglebone/tilcdc"
		number=3
		cleanup
	fi

	#This has to be last...
	echo "dir: beaglebone/dtbs"
	#regenerate="enable"
	if [ "x${regenerate}" = "xenable" ] ; then
		patch -p1 < "${DIR}/patches/beaglebone/dtbs/0001-sync-am335x-peripheral-pinmux.patch"
		exit 2
	fi

	#regenerate="enable"
	if [ "x${regenerate}" = "xenable" ] ; then
		start_cleanup
	fi

	${git} "${DIR}/patches/beaglebone/dtbs/0001-sync-am335x-peripheral-pinmux.patch"

	if [ "x${regenerate}" = "xenable" ] ; then
		number=1
		cleanup
	fi

	####
	#dtb makefile
	echo "dir: beaglebone/generated"
	#regenerate="enable"
	if [ "x${regenerate}" = "xenable" ] ; then

		device="am335x-boneblack-emmc-overlay.dtb" ; dtb_makefile_append
		device="am335x-boneblack-hdmi-overlay.dtb" ; dtb_makefile_append
		device="am335x-boneblack-nhdmi-overlay.dtb" ; dtb_makefile_append
		device="am335x-boneblack-overlay.dtb" ; dtb_makefile_append
		device="am335x-bonegreen-overlay.dtb" ; dtb_makefile_append

		device="am335x-abbbi.dtb" ; dtb_makefile_append

		device="am335x-olimex-som.dtb" ; dtb_makefile_append

		device="am335x-bonegreen-wireless.dtb" ; dtb_makefile_append

		device="am335x-arduino-tre.dtb" ; dtb_makefile_append

		device="am335x-bone-cape-bone-argus.dtb" ; dtb_makefile_append
		device="am335x-boneblack-cape-bone-argus.dtb" ; dtb_makefile_append
		device="am335x-boneblack-wl1835mod.dtb" ; dtb_makefile_append
		device="am335x-boneblack-bbbmini.dtb" ; dtb_makefile_append
		device="am335x-boneblack-bbb-exp-c.dtb" ; dtb_makefile_append
		device="am335x-boneblack-bbb-exp-r.dtb" ; dtb_makefile_append
		device="am335x-boneblack-audio.dtb" ; dtb_makefile_append

		device="am335x-sancloud-bbe.dtb" ; dtb_makefile_append

		#device="am335x-boneblack-ctag-face.dtb" ; dtb_makefile_append
		#device="am335x-bonegreen-ctag-face.dtb" ; dtb_makefile_append

		git commit -a -m 'auto generated: capes: add dtbs to makefile' -s
		git format-patch -1 -o ../patches/beaglebone/generated/
		exit 2
	else
		${git} "${DIR}/patches/beaglebone/generated/0001-auto-generated-capes-add-dtbs-to-makefile.patch"
	fi

	echo "dir: beaglebone/phy"
	#regenerate="enable"
	if [ "x${regenerate}" = "xenable" ] ; then
		start_cleanup
	fi

	${git} "${DIR}/patches/beaglebone/phy/0001-cpsw-search-for-phy.patch"

	if [ "x${regenerate}" = "xenable" ] ; then
		number=1
		cleanup
	fi

	echo "dir: beaglebone/firmware"
	#regenerate="enable"
	if [ "x${regenerate}" = "xenable" ] ; then
		start_cleanup
	fi

	#http://git.ti.com/gitweb/?p=ti-cm3-pm-firmware/amx3-cm3.git;a=summary
	#git clone git://git.ti.com/ti-cm3-pm-firmware/amx3-cm3.git
	#cd amx3-cm3/
	#git checkout origin/ti-v4.1.y -b tmp

	#commit 730f0695ca2dda65abcff5763e8f108517bc0d43
	#Author: Dave Gerlach <d-gerlach@ti.com>
	#Date:   Wed Mar 4 21:34:54 2015 -0600
	#
	#    CM3: Bump firmware release to 0x191
	#    
	#    This version, 0x191, includes the following changes:
	#         - Add trace output on boot for kernel remoteproc driver
	#         - Fix resouce table as RSC_INTMEM is no longer used in kernel
	#         - Add header dependency checking
	#    
	#    Signed-off-by: Dave Gerlach <d-gerlach@ti.com>

	#cp -v bin/am* /opt/github/linux-dev/KERNEL/firmware/

	#git add -f ./firmware/am*

	${git} "${DIR}/patches/beaglebone/firmware/0001-add-am33x-firmware.patch"

	if [ "x${regenerate}" = "xenable" ] ; then
		number=1
		cleanup
	fi
}

quieter () {
	echo "dir: quieter"
	#regenerate="enable"
	if [ "x${regenerate}" = "xenable" ] ; then
		start_cleanup
	fi

	#quiet some hide obvious things...
	${git} "${DIR}/patches/quieter/0001-quiet-8250_omap.c-use-pr_info-over-pr_err.patch"

	if [ "x${regenerate}" = "xenable" ] ; then
		number=1
		cleanup
	fi
}

more_fixes () {
	echo "dir: more_fixes"
	#regenerate="enable"
	if [ "x${regenerate}" = "xenable" ] ; then
		start_cleanup
	fi

	${git} "${DIR}/patches/more_fixes/0001-slab-gcc5-fixes.patch"

	if [ "x${regenerate}" = "xenable" ] ; then
		number=1
		cleanup
	fi
}

###
reverts
#backports
dir 'fixes'
ti
pru_uio
pru_rpmsg
dir 'gpio'
bbb_overlays
beaglebone
quieter
more_fixes
dir 'local'

packaging () {
	echo "dir: packaging"
	#regenerate="enable"
	if [ "x${regenerate}" = "xenable" ] ; then
		cp -v "${DIR}/3rdparty/packaging/builddeb" "${DIR}/KERNEL/scripts/package"
		${git_bin} commit -a -m 'packaging: sync builddeb changes' -s
		${git_bin} format-patch -1 -o "${DIR}/patches/packaging"
		exit 2
	else
		${git} "${DIR}/patches/packaging/0001-packaging-sync-builddeb-changes.patch"
	fi
}

packaging
echo "patch.sh ran successfully"
