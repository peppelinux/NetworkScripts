#!/bin/bash

export OPENWRT_APPS=(luci olsrd) # peervpn)
export CORE_NUMBER=9
#export OPENWRT_VERSION="12.09/"
#export OPENWRT_VERSION="" # trunk

#echo "$2"

if [[ $# -eq 1  ]]; 
then
    echo "Directory not found. Please enter the openwrt source folder name if you want to create new one: "
    read TARGET_DIR
else
    TARGET_DIR="$2"
fi

echo "I'm working on $TARGET_DIR"

case "$1" in
    
    download)
        echo "cloning openwrt git"

        if [[ -d "$2" ]]
        then
            echo "already downloaded there. Please clean it first or change directory !"
            exit 1
        fi        
        
        git clone git://git.openwrt.org/12.09/openwrt.git
        
        echo "rename openwrt dir with prefix" $DIR_PREFIX
        
        mv openwrt $TARGET_DIR
        echo "$TARGET_DIR"
        cd $TARGET_DIR
        
        cp -p ../$0  .
        
        scripts/feeds update -a
        
        echo "."        
        ;;

    configure)
        echo "configure..."    
        cd $TARGET_DIR

        scripts/feeds update -a
        make defconfig
        
        for i in "${OPENWRT_APPS[@]}"; do scripts/feeds install -d -y $i; echo $i "installed"; done

        make defconfig
        
        # questo è un pò troppo hardcodato per i miei gusti ma se i nostri modelli son pochi che ben venga
        # certo si può trovare/fare di meglio :)
        mv .config .config.orig
        
        # prima passata
        sed "s/CONFIG_TARGET_ar71xx_generic_Default=y/# CONFIG_TARGET_ar71xx_generic_Default=y/g" .config.orig |
        sed "s/# CONFIG_TARGET_ar71xx_generic_TLWR841 is not set/CONFIG_TARGET_ar71xx_generic_TLWR841=y/g"     |
        #sed "s/# CONFIG_PACKAGE_peervpn is not set/CONFIG_PACKAGE_peervpn=y/g"    |
        sed "s/# CONFIG_PACKAGE_kmod-gre is not set/CONFIG_PACKAGE_kmod-gre=y/g"  |
        sed "s/# CONFIG_PACKAGE_luci is not set/CONFIG_PACKAGE_luci=y/g"          |
        sed "s/# CONFIG_PACKAGE_olsrd is not set/CONFIG_PACKAGE_olsrd=y/g"        |
        sed "s/# CONFIG_PACKAGE_luci-app-olsr is not set/CONFIG_PACKAGE_luci-app-olsr=y/g"        |
        sed "s/# CONFIG_PACKAGE_tc is not set/CONFIG_PACKAGE_tc=y/g"        |
        #sed "s/# CONFIG_PACKAGE_tcpdump-mini is not set/CONFIG_PACKAGE_tcpdump-mini=y/g"        |
        sed "s/# CONFIG_PACKAGE_luci-app-olsr is not set/CONFIG_PACKAGE_luci-app-olsr=y/g" > .config
        
        make defconfig
        
        mv .config .config.orig.1
        
        # seconda passata
        sed "s/# CONFIG_PACKAGE_luci-app-olsr-services is not set/CONFIG_PACKAGE_luci-app-olsr-services=y/g"  .config.orig.1 > .config
        make defconfig
        echo "."
        ;;
    
    clean)
        echo "clean"
        cd $TARGET_DIR

        mv dl dl.back
        mv feeds feeds_back

        make distclean
        
        mv dl.back dl
        mv feeds_back feeds

        echo "."        
        ;;
    
    make)
        cd $TARGET_DIR
            
        make V=99 -j $CORE_NUMBER
        ;;
    
    all)
        $0 download
        $0 configure
        $0 make
        ;;
    
    *)
        echo "Usage: $0 download|configure|make|clean|all"
        exit 1

esac
exit 0
