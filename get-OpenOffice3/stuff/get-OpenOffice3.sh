#!/bin/sh
# get-OpenOffice3, install everything for OpenOffice.org exept KDE/Gnome integration and testsuite.
#
# (C) 2008 SliTaz - GNU General Public License v3.
#
# Author : Eric Joseph-Alexandre <erjo@slitaz.org>

PACKAGE="OpenOffice"
VERSION="3.0.0"
URL="http://www.openoffice.org"

if [ "$LANG" = "fr_FR" ]; then
	TARBALL="OOo_${VERSION}_LinuxIntel_install_fr.tar.gz"
	WGET_URL="ftp://ftp.proxad.net/mirrors/ftp.openoffice.org/localized/fr/${VERSION}/${TARBALL}"
else
	TARBALL="OOo_${VERSION}_LinuxIntel_install_en-US.tar.gz"
	WGET_URL="ftp://ftp.proxad.net/mirrors/ftp.openoffice.org/stable/${VERSION}/${TARBALL}"
fi 

TEMP_DIR="/home/slitaz/build/$PACKAGE.$$"
SOURCE_DIR="/home/slitaz/src"
EXCLUDE="kde|gnome|test"
LOG="/tmp/$(basename $0 .sh).log"

# Status function with color (supported by Ash).
status()
{
	local CHECK=$?
	echo -en "\\033[70G[ "
	if [ $CHECK = 0 ]; then
		echo -en "\\033[1;33mOK"
	else
		echo -en "\\033[1;31mFailed"
	fi
	echo -e "\\033[0;39m ]"
	return $CHECK
}

# Check if user is root to install, or remove packages.
check_root()
{
	if test $(id -u) != 0 ; then
		echo -e "\nYou must be root to run `basename $0` with this option."
		echo -e "Please use 'su' and root password to become super-user.\n"
		exit 0
	fi
}

check_if_installed()
{
	 # Avoid reinstall
	 if [ -d /var/lib/tazpkg/installed/$PACKAGE ];then
	 	return 0
	 else
	 	return 1
	 fi
}

#We need to bee root
check_root

#check if package already installed
if (check_if_installed $PACKAGE); then
	echo "$PACKAGE is already installed."
	echo -n "Would you like to remove and reinstall this package [y/n]? "
	read answer
	case "$answer" in
	y|Y)
		tazpkg remove $PACKAGE ;;
	*)
		exit 0 ;;
	esac
		
fi


# Check if we have the tarball before.
if [ ! -f $SOURCE_DIR/$TARBALL ]; then
	echo "Downloading OppenOffice.org tarball (it's time to have a break)... "
	#Check if $SOURCE_DIR exist
	test -d $SOURCE_DIR || mkdir -p $SOURCE_DIR
	# Get the file.
	wget -c $WGET_URL -O $SOURCE_DIR/$TARBALL
	status
fi



# Creates TEM_DIR and extract tarball
mkdir -p $TEMP_DIR
echo -n "Extract files from archive..."
tar xvzf $SOURCE_DIR/$TARBALL -C $TEMP_DIR > $LOG 2>&1 || \
 (echo "Failed to extract $TARBALL" ; exit 1)
status

cd $TEMP_DIR/*/RPMS

# Extract everything from RPMS
for i in *.rpm
do
	if (! echo $i | egrep -qi $EXCLUDE); then
		rpm2cpio $i | cpio -id >> $LOG 2>&1
	fi
done
rpm2cpio desktop-integration/*freedesktop*.rpm | cpio -id >> $LOG 2>&1
	
# Make the package
mkdir -p $PACKAGE-$VERSION/fs/usr/lib/openoffice  \
  $PACKAGE-$VERSION/fs/usr/share
 
cp -a opt/openoffice* $PACKAGE-$VERSION/fs/usr/lib/openoffice
cp -a usr/share/mime $PACKAGE-$VERSION/fs/usr/share
cp -a usr/share/icons $PACKAGE-$VERSION/fs/usr/share
cp -a usr/bin $PACKAGE-$VERSION/fs/usr

# relocalized OOo libexec directory
sed -i 's#/opt/#/usr/lib/openoffice/#'  $PACKAGE-$VERSION/fs/usr/openoffice*

# Create receipt
cat > $PACKAGE-$VERSION/receipt <<EOT
# SliTaz package receipt.

PACKAGE="$PACKAGE"
VERSION="$VERSION"
CATEGORY="office"
SHORT_DESC="Productivity suite."
DEPENDS=""
WEB_SITE="$URL"

post_install()
{
	cd /usr/share/applications
	ln -s /usr/lib/openoffice/openoffice.org3/share/xdg/base.desktop openoffice.org3-base.desktop 
	ln -s /usr/lib/openoffice/openoffice.org3/share/xdg/impress.desktop openoffice.org3-impress.desktop
	ln -s /usr/lib/openoffice/openoffice.org3/share/xdg/writer.desktop openoffice.org3-writer.desktop
	ln -s /usr/lib/openoffice/openoffice.org3/share/xdg/calc.desktop openoffice.org3-calc.desktop
	ln -s /usr/lib/openoffice/openoffice.org3/share/xdg/math.desktop openoffice.org3-math.desktop
	ln -s /usr/lib/openoffice/openoffice.org3/share/xdg/draw.desktop openoffice.org3-draw.desktop
	ln -s /usr/lib/openoffice/openoffice.org3/share/xdg/printeradmin.desktop openoffice.org3-printeradmin.desktop
	
	cd /usr/bin
	ln -sf /usr/lib/openoffice/openoffice.org3/program/soffice
}

post_remove()
{
	rm -f /usr/share/applications/openoffice.org3-*
}

EOT

# Pack
tazpkg pack $PACKAGE-$VERSION

# Install pseudo package
tazpkg install $PACKAGE-$VERSION.tazpkg

# Clean
rm -rf $TEMP_DIR
rm -rf $PACKAGE-$VERSION
