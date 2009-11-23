#!/bin/sh
#
# This script creates a floppy image set from a linux bzImage and can merge
# a cmdline and/or one or more initramfs.
# The total size can not exceed 15M because INT 15H function 87H limitations.
#
# (C) 2009 Pascal Bellard - GNU General Public License v3.

usage()
{
cat <<EOT
Usage: $0 bzImage [--prefix image_prefix] [--cmdline 'args']
       [--format 1440|1680|1720|2880 ] [--initrd initrdfile]...

Example:
$0 /boot/vmlinuz-2.6.30.6 --cmdline 'rw lang=fr_FR kmap=fr-latin1 laptop autologin' --initrd /boot/rootfs.gz --initrd ./myconfig.gz
EOT
exit 1
}

KERNEL=""
INITRD=""
CMDLINE=""
PREFIX="floppy"
FORMAT="1440"
while [ -n "$1" ]; do
	case "$1" in
	--cmdline) CMDLINE="$2"; shift;;
	--initrd)  INITRD="$INITRD $2"; shift;;
	--prefix)  PREFIX="$2"; shift;;
	--format)  FORMAT="$2"; shift;;
	*) KERNEL="$1";;
	esac
	shift
done
[ -n "$KERNEL" -a -f "$KERNEL" ] || usage

# write a 32 bits data
# usage: storelong offset data32 file
storelong()
{
	printf "00000  %02X %02X %02X %02X \n" \
		$(( $2 & 255 )) $(( ($2>>8) & 255 )) \
		$(( ($2>>16) & 255 )) $(( ($2>>24) & 255 )) | \
	hexdump -R | dd bs=1 conv=notrunc of=$3 seek=$(( $1 )) 2> /dev/null
}

# read a 32 bits data
# usage: getlong offset file
getlong()
{
	dd if=$2 bs=1 skip=$(( $1 )) count=4 2> /dev/null | \
		hexdump -e '"" 1/4 "%d" "\n"'
}

floppyset()
{
	# bzImage offsets
	SetupSzOfs=497
	SyssizeOfs=500
	CodeAdrOfs=0x214
	RamfsAdrOfs=0x218
	RamfsLenOfs=0x21C
	ArgPtrOfs=0x228

	# boot+setup address
	SetupBase=0x90000

	stacktop=0x9E00

	bs=/tmp/bs$$

	# Get and patch boot sector
	dd if=$KERNEL bs=512 count=1 of=$bs 2> /dev/null
	uudecode <<EOT | dd of=$bs conv=notrunc 2> /dev/null
begin-base64 644 -
v/Sd/GgAkAcxyQYXify7eACO2cU3sQbzpY7ZiSeMRwKg8X2YQAYfxkX4P/qX
mEEx2+hAAb4AAoBMEYDHRCQAnAN0DuhmAb4oAjkcci9HixxW6EIBX4s16FIB
sCDNELAIzRBOmM0WPAh0BJiJBK07NXTx6CsBPAp14Yh8/rkYAGoA4vyJ5rAP
v/QB/k0csQW0k4lEHLABiUQUmYlUEIlUGGYx20PT40tmAx1m0+toABAHv4AA
KfuccwIB31NWMdvo1ABeuQCAtIf+RBzNFVudd9yhGgJIvxwCsQk4RBxysDHA
zRPqAAAgkLBGKMi+twHovABd6yOA+RNyBDjBd2iA/gJyBDjmd2mA/VBzc2AG
UlFTlrQCULkGAFGxBMHFBLAPIegEkCcUQCfodQDi7rAgzRBZ4rSYzRNhMfat
ka2SrVAoyHcCsAGYOfhyAon4UFK0As0TWpVeWHKcKfcB8cHmCQHzOMF1JojI
/saxATjmdRyI9P7FtgA8E3USgP1Qcg21AGC+ugHoJACYzRZhowQAUlFmjwYA
AAn/dZ4WB7AxLAO0DrsHAM0QPA1088OwDejv/6wIwHX4w1g6AEluc2VydCBu
ZXh0IGZsb3BweSBhbmQgcHJlc3MgYW55IGtleSB0byBjb250aW51ZS4HDQA=
====
EOT

	# Get setup
	setupsz=$(getlong $SetupSzOfs $bs)
	setupszb=$(( $setupsz & 255 ))
	dd if=$KERNEL bs=512 skip=1 count=$setupszb 2> /dev/null >> $bs

	# Store cmdline after setup
	if [ -n "$CMDLINE" ]; then
		echo -n "$CMDLINE" | dd bs=512 count=1 conv=sync 2> /dev/null >> $bs
		storelong ArgPtrOfs $(( $SetupBase + $stacktop )) $bs
	fi

	# Compute initramfs size
	initrdlen=0
	padding=0
	for i in $( echo $INITRD | sed 's/,/ /' ); do
		[ -s "$i" ] || continue
		initrdlen=$(( $initrdlen + $padding ))
		padding=$(stat -c %s $i)
		initrdlen=$(( $initrdlen + $padding ))
		padding=$(( 4096 - ($padding & 4095) ))
		[ $padding -eq 4096 ] && padding=0
	done
	Ksize=$(( $(getlong $SyssizeOfs $bs)*16 ))
	Kpad=$(( (($Ksize+4095)/4096)*4096 - Ksize ))
	if [ $initrdlen -ne 0 ]; then
		Kbase=$(getlong $CodeAdrOfs $bs)
		storelong $RamfsAdrOfs \
			$(( (0x1000000 - $initrdlen) & 0xFFFF0000 )) $bs
		storelong $RamfsLenOfs $initrdlen $bs
	fi

	# Output boot sector + setup + cmdline
	dd if=$bs 2> /dev/null

	# Output kernel code
	dd if=$KERNEL bs=512 skip=$(( $setupszb + 1 )) 2> /dev/null

	# Pad to next sector
	Kpad=$(( 512 - ($(stat -c %s $KERNEL) & 511) ))
	[ $Kpad -eq 512 ] || dd if=/dev/zero bs=1 count=$Kpad 2> /dev/null

	# Output initramfs
	padding=0
	for i in $( echo $INITRD | sed 's/,/ /' ); do
		[ -s "$i" ] || continue
		[ $padding -ne 0 ] && dd if=/dev/zero bs=1 count=$padding
		dd if=$i 2> /dev/null
		padding=$(( 4096 - ($(stat -c %s $i) & 4095) ))
		[ $padding -eq 4096 ] && padding=0
	done

	# Cleanup
	rm -f $bs
}

floppyset | split -b ${FORMAT}k /dev/stdin floppy$$
i=1
ls floppy$$* | while read file ; do
	output=$PREFIX.$(printf "%03d" $i)
	cat $file /dev/zero | dd bs=1k count=$FORMAT conv=sync of=$output 2> /dev/null
	echo $output
	rm -f $file
	i=$(( $i + 1 ))
done
