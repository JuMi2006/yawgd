#!/bin/sh
#
#
# This file is part of yawgd.
#
# ebusd is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ebusd is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ebusd. If not, see http://www.gnu.org/licenses/.
#

BUILD_DIR=/tmp
VERSION='1.0'

cd $BUILD_DIR
printf ">>> Build directory $BUILD_DIR create $BUILD_DIR/ebusd_build\n"
mkdir yawgd-build
cd yawgd-build

printf ">>> Checkout sources\n"
git clone https://github.com/JuMi2006/yawgd.git
cd yawgd

printf ">>> Remove hidden files\n"
find $PWD -name .svn -print0 | xargs -0 rm -r
find $PWD -name .gitignore -print0 | xargs -0 rm -r

printf ">>> Create Debian package related files\n"
mkdir trunk
mkdir trunk/DEBIAN
mkdir trunk/etc
mkdir trunk/usr

cp -R etc/* trunk/etc
cp -R usr/* trunk/usr

printf ">>> ../DEBIAN/control\n"
#ARCH=`dpkg --print-architecture`
ARCH="all"
echo "Package: yawgd
Version: $VERSION
Section: net
Priority: required
Architecture: $ARCH
Maintainer: Mirko Hirsch <mirko.hirsch@gmx.de>
Depends: liblog-log4perl-perl, libproc-pid-file-perl (>= 1.25), libfile-touch-perl, librrds-perl, libmath-round-perl, libmath-round-perl, libconfig-std-perl, libproc-daemon-perl
Description: Daemon for EIB/KNX/(eBus)\n" > trunk/DEBIAN/control

printf ">>> ../DEBIAN/dirs\n"
echo "usr/sbin
usr/lib/perl5
etc/yawgd
etc/yawgd/plugin
etc/yawgd/tools
etc/default
etc/init.d
etc/logrotate.d" > trunk/DEBIAN/dirs

printf ">>> ../DEBIAN/postinst\n"
echo "#! /bin/sh -e
update-rc.d yawgd defaults
/etc/init.d/yawgd restart" > trunk/DEBIAN/postinst
chmod +x trunk/DEBIAN/postinst

mkdir yawgd-$VERSION
cp -R trunk/* yawgd-$VERSION
dpkg -b yawgd-$VERSION

printf ">>> Move Package to $BUILD_DIR\n"
mv yawgd-$VERSION.deb $BUILD_DIR/yawgd-${VERSION}_${ARCH}.deb

printf ">>> Remove Files\n"
cd $BUILD_DIR
rm -R yawgd-build

printf ">>> Debian Package created at $BUILD_DIR/yawgd-${VERSION}_${ARCH}.deb\n"
