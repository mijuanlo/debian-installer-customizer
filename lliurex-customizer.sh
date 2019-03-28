#!/bin/bash 
# BEGIN CUSTOMIZATIONS

# DEBUG FLAG INCREASES VERBOSITY
DEBUG=0
# WHICH DISTRIBUTION MUST I PICK UP UDEBS
DISTRIBUTION_UDEBS=bionic
# WHICH DISTRIBUTION MUST I PICK UP THE INSTALLER SOURCE CODE
DISTRIBUTION_INSTALLER=disco
# WHICH KERNEL USE FOR X86
KERNEL_X86="4.15.0-20"
# WHICH KERNEL USE FOR AMD64
KERNEL_AMD64="4.15.0-20"
# MAIN REPO TO GET SOURCES
REPO=http://ubuntu.cica.es/ubuntu
# REPO FROM UDEBS
REPO_UDEBS=$REPO
# REPO FOR GET THE DISTRIBUTED KERNEL & INITRD BUILT BY UBUNTU
REPO_UPSTREAM_INSTALLER=$REPO/dists/$DISTRIBUTION_UDEBS-updates
# REPO FOR GET THE DISTRIBUTED INSTALLER
REPO_INSTALLER=$REPO
# PACKAGES NEEDED TO COMPLETE BUILD PROCESS
INSTALL_EXTRA_PACKAGES="libtextwrap1"
# ALLOW TO CLEAN OR MANTAIN USED COMPILATION FILES
CLEAN_TMPFILES=1
# AUTOREBUILD INITRD TO BLACKLIST SOME MODULES OR APPEND MISSING MODULES FROM DISTRIBUTED INITRD BOOT IMAGE
AUTOREBUILD=0
# REMOVE UDEBS FROM INSTALLER
# BLACKLIST_UDEBS="cdebconf|cdrom-|iso-scan|load-"
BLACKLIST_UDEBS=""
# REPO COMPONENTS WHERE NEEDED UDEBS ARE INTO PACKAGE REPOSITORY
UDEBS_FROM_COMPONENTS="main/debian-installer,universe/debian-installer"

# END CUSTOMIZATIONS

NC='\033[0m'
R='\033[0;31m'
B='\033[0;34m'
G='\033[0;32m'
Y='\033[1;33m'

msg(){
    f=$(date +'%H:%M:%S')
    echo -e "${Y}$f:--> $@       (${FUNCNAME[1]})${NC}"
}
errmsg(){
    f=$(date +'%H:%M:%S')
    echo -e "${R}$f:--> $@       (${FUNCNAME[1]})${NC}"
}
run(){
# CHECK DEBUG
    if [ "x$DEBUG" = "x1" ]; then
	"$@"
    else
	"$@" > /dev/null 2> /dev/null
    fi
}

run_safe(){
# CHECK DEBUG
    if [ "x$DEBUG" = "x1" ]; then
	"$@"
	RET=$?
    else
	"$@" > /dev/null 2> /dev/null
	RET=$?
    fi
    if [ "$RET" != "0" ]; then
	errmsg Error!
	salida
    fi 
}

backup_sources(){
# BACKUP ORIGINAL SOURCES
run pushd $INIT_DIR
msg "Doing sources.list & sources.list.d backup"
run mkdir tmp_sources_list
run mv /etc/apt/sources.list tmp_sources_list/ 
run mkdir tmp_sources_list_d
run mv /etc/apt/sources.list.d/* tmp_sources_list_d/
run popd
}

restore_sources(){
run pushd $INIT_DIR
# RESTORE ORIGINAL SOURCES
msg "Restoring sources.list & sources.list.d backup"
run mv tmp_sources_list/sources.list /etc/apt/sources.list
run rmdir tmp_sources_list
run mv tmp_sources_list_d/* /etc/apt/sources.list.d/
run rmdir tmp_sources_list_d
run popd
}

abort_actions(){
    echo
    restore_sources
    if [ "x$CLEAN_TMPFILES" = "x1" ]; then
	run rm -rf $INIT_DIR/tmp
    fi
}
salida(){
    abort_actions
    exit 1
}
trap salida SIGINT

initial_actions(){
msg "Doing initial checks"
# CHECK RUNNING USER
ME=$(whoami)
if [ "x$ME" != "xroot" ]; then
    errmsg "I need run as root"
    salida
fi

# CHECK ARCH
INIT_DIR=$(pwd)
ARCH=$(arch)

case "$ARCH" in
    *86)
	SRC_ARCH="fuentes_x86"
	ARCHNAME="i386"
	KERNEL=$KERNEL_X86
	;;

    *_64)
	SRC_ARCH="fuentes_amd64"
	ARCHNAME="amd64"
	KERNEL=$KERNEL_AMD64
	;;

    x*)
	msg "Not implemented"
	salida
	;;
esac 


}

get_original_netinstaller(){
    msg "Getting original netinstaller"
    DEST="$INIT_DIR/netinstall_${ARCHNAME}_${KERNEL}"
    run mkdir -p $DEST

    for arq in {amd64,i386}; do
	    UPSTREAM_INSTALLER=$REPO_UPSTREAM_INSTALLER/main/installer-$arq/current/images
	    UPSTREAM_INSTALLER_FLAVOUR=$UPSTREAM_INSTALLER/netboot/ubuntu-installer/$arq
	    
	    if [ ! -f $DEST/distro-udeb-orig-$arq.list ]; then
		run_safe wget -q $UPSTREAM_INSTALLER/udeb.list -O $DEST/distro-udeb-orig-$arq.list
	    fi
	    if [ ! -f $DEST/distro-linux-$arq ]; then
		run_safe wget -q $UPSTREAM_INSTALLER_FLAVOUR/linux -O $DEST/distro-linux-$arq
	    fi
	    if [ ! -f $DEST/distro-initrd-$arq.gz ]; then
		run_safe wget -q $UPSTREAM_INSTALLER_FLAVOUR/initrd.gz -O $DEST/distro-initrd-$arq.gz
	    fi
    done

}

put_sources_installer(){
# PUT SOURCES TO GET INSTALLER
echo "deb-src $REPO_INSTALLER ${DISTRIBUTION_INSTALLER} main universe multiverse" > /etc/apt/sources.list
echo "deb-src $REPO_INSTALLER ${DISTRIBUTION_INSTALLER}-updates main universe multiverse" >> /etc/apt/sources.list
echo "deb-src $REPO_INSTALLER ${DISTRIBUTION_INSTALLER}-security main universe multiverse" >> /etc/apt/sources.list
echo "deb $REPO_INSTALLER ${DISTRIBUTION_INSTALLER} main universe multiverse" >> /etc/apt/sources.list
echo "deb $REPO_INSTALLER ${DISTRIBUTION_INSTALLER}-updates main universe multiverse" >> /etc/apt/sources.list
echo "deb $REPO_INSTALLER ${DISTRIBUTION_INSTALLER}-security main universe multiverse" >> /etc/apt/sources.list

run_safe apt-get -q update
}

get_installer(){
# GET INSTALLER
msg "Getting installer source"
run mkdir $SRC_ARCH
run pushd $SRC_ARCH
run_safe apt-get -y source debian-installer
run popd
}

get_installer_dependences(){
msg "Installing installer dependences"
# GET BUILD DEPENDENCES
run_safe apt-get -y build-dep debian-installer
}

put_sources_udebs(){
msg "Setting sources.list for udebs"
# PUT SOURCES TO GET UDEBS
echo "deb $REPO_UDEBS ${DISTRIBUTION_UDEBS} main universe multiverse $UDEBS_INTO_COMPONENTS" > /etc/apt/sources.list
echo "deb $REPO_UDEBS ${DISTRIBUTION_UDEBS}-updates main universe multiverse $UDEBS_INTO_COMPONENTS" >> /etc/apt/sources.list
echo "deb $REPO_UDEBS ${DISTRIBUTION_UDEBS}-security main universe multiverse $UDEBS_INTO_COMPONENTS" >> /etc/apt/sources.list

run_safe apt-get -q update
}

install_extra_packages(){
# INSTALL EXTRA PACKAGES
if [ ! -z "$INSTALL_EXTRA_PACKAGES" ]; then
    msg "Installing extra packages"
    run_safe apt-get -y install $INSTALL_EXTRA_PACKAGES
fi
}

patch_netinstall(){
# PATCH NETINSTALL
DIR_INSTALLER=$(find ./$SRC_ARCH -maxdepth 1 -type d -name 'debian-installer*' -print |cut -d '/' -f3|uniq)
msg "Patching installer... "
run pushd $SRC_ARCH/$DIR_INSTALLER
reg="^$ARCHNAME.*"
run_safe run-parts -v --regex=$reg -a $ARCHNAME -a $KERNEL -a $DISTRIBUTION_UDEBS -a $DISTRIBUTION_INSTALLER -a $UDEBS_FROM_COMPONENTS -a $REPO $INIT_DIR/patches/
reg="^common.*"
run_safe run-parts -v --regex=$reg -a $ARCHNAME -a $KERNEL -a $DISTRIBUTION_UDEBS -a $DISTRIBUTION_INSTALLER -a $UDEBS_FROM_COMPONENTS -a $REPO $INIT_DIR/patches/
run popd
}

build_installer(){
# BUILD PROCESS
msg "Building installer"
run pushd ./$SRC_ARCH/$DIR_INSTALLER
run_safe dpkg-buildpackage -us -uc
run popd
}

customize_initrd(){

if [ -z "$INIT_DIR" -o -z "$SRC_ARCH" ]; then 
    echo errores
    exit 1
fi
# CUSTOMIZE IMAGE WITH RESOURCES
msg "Customizing installer with resources"

# LOCATE PACKAGE
PKG=""
PKG=$(find $SRC_ARCH -type f -name 'debian-installer-images*.tar.gz')
if [ -z "$PKG" ]; then
    echo ERROR
    salida
fi

# CREATE WORKDIR
TMP_DIR=$INIT_DIR/tmp
run mkdir -p $TMP_DIR
run cp $PKG $TMP_DIR
run pushd $TMP_DIR

# UNPACK PACKAGE
run_safe tar xvfz $(basename $PKG)

# FIND initrd
RD=$(find ./ -name initrd.gz)
RD_DIR=$(dirname $RD)

# COPY ORIGINAL RESOURCES 
msg "Copying original initrd & udebs"
run cp $RD $DEST/orig-initrd.lz

udeb_list=$(find ./ -name udeb.list)
run_safe cp $udeb_list $DEST/

udeb_archive=$(find $INIT_DIR/$SRC_ARCH -type d -name 'apt.udeb')
run_safe cp -R $udeb_archive/cache/archives $DEST/udebs
run rm -rf $DEST/udebs/partial

msg "Extracting initrd"
run mkdir -p mntrd
run pushd mntrd
gunzip -c $TMP_DIR/$RD |cpio -id 2> /dev/null

msg "Customizing with resources"
for x in $INIT_DIR/resources/*.png ; do
    N=$(basename $x)
    run_safe cp $INIT_DIR/resources/$N usr/share/graphics/$N
done
msg "Rebuilding initrd"
find ./ | cpio --verbose -H newc -o > $TMP_DIR/initrd 2>/dev/null

run popd

run_safe gzip -9 $TMP_DIR/initrd
run_safe mv $TMP_DIR/initrd.gz $DEST/initrd.lz

run_safe cp $RD_DIR/linux $DEST/linux

run popd 

}

check_udebs(){
    msg "Checking udebs included"
    cat $DEST/distro-udeb-orig-$ARCHNAME.list |cut  -d' ' -f1|perl -pe 's%(.+?)-([0-9\-\.])+-generic-di%\1%'|sort|uniq > $TMP_DIR/udeb-orig-filtered.list
    cat $DEST/udeb.list |cut  -d' ' -f1|perl -pe 's%(.+?)-([0-9\-\.])+-generic-di%\1%'|sort|uniq > $TMP_DIR/udeb-filtered.list

    comm -23 $TMP_DIR/udeb-orig-filtered.list $TMP_DIR/udeb-filtered.list > $TMP_DIR/udeb-not-included.list

    rebuild=0
    if [ "x$AUTOREBUILD" != "x1" ]; then
    echo "List udebs not included in this build and included into original installer"
    if [ -n "$BLACKLIST_UDEBS" ];then
	cat  $TMP_DIR/udeb-not-included.list |sed -r "s%(.+)-modules\$%\1-modules-$KERNEL-generic-di%g"|egrep -v "$BLACKLIST_UDEBS"
    else
	cat  $TMP_DIR/udeb-not-included.list
    fi
    while true; do
    read -p "Do you wish to retry build including this udebs? " yn
	case $yn in
    	    [Yy]* ) rebuild=1; break;;
    	    [Nn]* ) break;;
    	    * ) echo "Please answer yes or no.";;
	esac
    done

    else
	rebuild=1
    fi

    if [ "x$rebuild" = "x1" ]; then
        if [ -z "$BLACKLIST_UDEBS" ]; then
            msg "No modules blacklisted"
        else
	    msg "Blacklisting modules: $BLACKLIST_UDEBS"
	fi
	file_to_append=$(find $SRC_ARCH -type f -name 'gtk-common')
	if [ -n "$BLACKLIST_UDEBS" ];then
	    cat $TMP_DIR/udeb-not-included.list |sed -r "s%(.+)-modules\$%\1-modules-$KERNEL-generic-di%g" |egrep -v "$BLACKLIST_UDEBS" >> $file_to_append
	else
	    cat $TMP_DIR/udeb-not-included.list |sed -r "s%(.+)-modules\$%\1-modules-$KERNEL-generic-di%g" >> $file_to_append
	fi
	msg "Rebuilding"
	build
    fi
}

clean_environment(){
    if [ -z "$TMP_DIR" ]; then
	return
    fi
    if [ "x$CLEAN_TMPFILES" = "x1" ];then
	run rm -rf $TMP_DIR
	run rm -rf ./$SRC_ARCH
    fi
}

build(){
    patch_netinstall
    build_installer
    customize_initrd
}
######################### MAIN PROGRAM ##########################

initial_actions
get_original_netinstaller
backup_sources
put_sources_installer
get_installer
get_installer_dependences
put_sources_udebs
install_extra_packages
build
check_udebs
restore_sources
clean_environment

echo "Done!"