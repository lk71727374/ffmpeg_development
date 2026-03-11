#!/bin/sh

# X264=/home/lk/x264/x264
X264=/home/lk/temp/x264-master
V4L2=/home/lk/v4l-utils/v4l-utils
# V4L2=/home/lk/temp/v4l-utils
ALSA=/home/lk/alsa-lib/alsa-lib-master
FFmpeg=/home/lk/ffmpeg/ffmpeg_development
KERNEL=/home/lk/os/linux
VPU=/home/lk/os/external/vpu
ROOTFS=/home/lk/os/rootfs

export LINUX_OUTPUT
export FFMPEG_OUTPUT
export OUTPUT=/home/lk/output

# export LD_LIBRARY_PATH=/home/lk/ffmpeg/ffmpeg_modified/build/lib:/home/lk/v4l-utils/v4l-utils/build/lib:/home/lk/x264/x264/build/lib:$LD_LIBRARY_PATH

x264_build() {
    if [ "$1" != "x86_64" ] && [ "$1" != "aarch64" ]
    then
        echo "x264 build parameter error!" > /dev/tty
        return 1
    fi

    cd $X264 && make distclean
    rm -rf build && mkdir build

    local arch=$1
    local PREFIX=$(pwd)/build && export PREFIX

    case "$arch" in
        x86_64)
        echo "build x86_64 x264 start ..."
        ./configure \
            --prefix=$PREFIX \
            --enable-shared \
            --disable-static \
            --enable-pic \
            --extra-cflags="-w" \
            --disable-cli
        ;;
        aarch64)
        echo "build aarch64 x264 start ..."
        ./configure \
            --host=aarch64-linux-gnu \
            --cross-prefix=aarch64-linux-gnu- \
            --prefix=$PREFIX \
            --enable-shared \
            --disable-static \
            --extra-cflags="-w" \
            --enable-pic \
            --disable-cli
        ;;
    esac

    make -j$(nproc)
    make install
    echo "build $1 x264 end ..."
}

v4l2_build() {
    # set rules for configure
    if [ "$1" != "x86_64" ] && [ "$1" != "aarch64" ]
    then
        echo "v4l2 build parameter error!" > /dev/tty
        return 1;
    fi

    cd $V4L2 && make distclean
    rm -rf build && mkdir build

    local arch=$1
    local PREFIX=$(pwd)/build && export PREFIX
    local SYSROOT=$(pwd)/build/temp && export SYSROOT
    local CFLAGS="-fcommon -w" && export CFLAGS
    local CXXFLAGS="-fcommon -w" && export CXXFLAGS

    case "$1" in
        x86_64)
        echo "build x86_64 v4l-utils start ..."
        ./configure \
            --prefix=$PREFIX \
            --exec-prefix=$PREFIX/bin \
            --libdir=$PREFIX/lib \
            --includedir=$PREFIX/include \
            --with-sysroot=$SYSROOT \
            --with-udevdir=$SYSROOT/lib/udev \
            --enable-shared \
            --enable-static \
            --enable-v4l-utils \
            --disable-qv4l2 \
            --disable-qvidcap \
            --disable-bpf \
            --disable-doxygen-doc
        ;;
        aarch64)
        echo "build aarch64 v4l-utils start ..."
        export CROSS_COMPILE=aarch64-linux-gnu-
        ./configure \
            --host=aarch64-linux-gnu \
            --build=x86_64-linux-gnu \
            --prefix=$PREFIX \
            --exec-prefix=$PREFIX/bin \
            --libdir=$PREFIX/lib \
            --includedir=$PREFIX/include \
            --with-sysroot=$SYSROOT \
            --with-udevdir=$SYSROOT/lib/udev \
            --enable-shared \
            --enable-static \
            --enable-v4l-utils \
            --disable-qv4l2 \
            --disable-qvidcap \
            --disable-bpf \
            --disable-doxygen-doc
        ;;
    esac

    make -j$(nproc)
    make install
    echo "build $1 v4l-utils end ..."
}

alsa_build() {
    if [ "$1" != "x86_64" ] && [ "$1" != "aarch64" ]
    then
        echo "alsa build parameter error!" > /dev/tty
        return 1;
    fi

    cd $ALSA && make distclean
    rm -rf build && mkdir build
    # alsa lib need run ./gitcomplie before ./configure
    # Notes: --with-configdir
    case "$1" in
        aarch64)
            echo "build aarch64 alsa-lib start ..."
            ./configure \
                --host=aarch64-linux-gnu \
                --prefix=/home/lk/alsa-lib/alsa-lib-master/build \
                --disable-python \
                --enable-shared \
        ;;
        x86_64)
            echo "build x86_64 alsa-lib start ..."
            ./configure \
                --prefix=/home/lk/alsa-lib/alsa-lib-master/build \
                --disable-python \
                --enable-shared \
        ;;
    esac

    make -j$(nproc)
    make install
    echo "build $1 alsa-lib end ..."
}

ffmpeg_build() {
    if [ "$1" != "x86_64" ] && [ "$1" != "aarch64" ]
    then
        echo "ffmpeg build parameter error!" > /dev/tty
        return 1;
    fi

    cd $FFmpeg && make distclean
    rm -rf build && mkdir build build/x264 build/v4l2 build/alsa build/alsa/config

    local arch=$1
    local x264=$(pwd)/build/x264
    local v4l2=$(pwd)/build/v4l2
    local alsa=$(pwd)/build/alsa

    # move outputs of x264 and v4l2 projects to ffmpeg
    x264_build $arch > build.log && echo "build $arch x264 complete!" > /dev/tty
    mv $X264/build/lib $X264/build/include $x264/
    v4l2_build $arch > build.log 2>&1 && echo "build $arch v4l-utils complete!" > /dev/tty
    mv $V4L2/build/lib $V4L2/build/include $v4l2/
    alsa_build $arch > build.log 2>&1 && echo "build $arch alsa-lib complete!" > /dev/tty
    mv $ALSA/build/lib $ALSA/build/include $alsa/
    mv $ALSA/build/share/alsa/* $alsa/config

    cd $FFmpeg
    find $x264/lib/pkgconfig -name "*.pc" | xargs sed -i "s|$X264/build|$x264|g" # modify .pc so that pkg-config can find libx264 libv4l2 and libasound2 
    find $v4l2/lib/pkgconfig -name "*.pc" | xargs sed -i "s|$V4L2/build|$v4l2|g"
    find $alsa/lib/pkgconfig -name "*.pc" | xargs sed -i "s|$ALSA/build|$alsa|g"

    local PREFIX=$(pwd)/build && export PREFIX
    local PKG_CONFIG_PATH=$x264/lib/pkgconfig:$v4l2/lib/pkgconfig:$alsa/lib/pkgconfig:$PKG_CONFIG_PATH && export PKG_CONFIG_PATH
    case "$arch" in
        aarch64)
        echo "build aarch64 ffmpeg start ..."
        ./configure --enable-cross-compile \
                    --target-os=linux \
                    --arch=arm64 \
                    --prefix=$PREFIX \
                    --cross-prefix=aarch64-linux-gnu- \
                    --disable-asm \
                    --enable-parsers \
                    --disable-debug \
                    --enable-shared \
                    --disable-static \
                    --enable-pic \
                    --enable-ffmpeg \
                    --enable-gpl \
                    --enable-libx264 \
                    --enable-libv4l2 \
                    --enable-v4l2-m2m \
                    --pkg-config=$(which pkg-config) \
                    --extra-cflags="-I$x264/include -I$v4l2/include -I$alsa/include -w" \
                    --extra-ldflags="-L$x264/lib -lx264 -L$v4l2/lib -lv4l2 -L$alsa/lib -lasound -Wl,-rpath-link=$v4l2/lib" \
                    --enable-decoder=h264 \
                    --enable-encoder=libx264 \
                    --enable-indev=v4l2 \
                    --enable-outdev=v4l2 \
                    --enable-indev=alsa \
                    --enable-outdev=alsa \
                    --enable-encoder=h264_v4l2m2m \
                    --enable-decoder=h264_v4l2m2m \
                    --disable-stripping \
                    --disable-doc \
                    --enable-small
        ;;
        x86_64)
        echo "build x86_64 ffmpeg start ..."
        ./configure --target-os=linux \
                    --arch=x86_64 \
                    --prefix=$PREFIX \
                    --disable-asm \
                    --enable-parsers \
                    --enable-debug \
                    --disable-optimizations \
                    --enable-shared \
                    --disable-static \
                    --enable-gpl \
                    --enable-libx264 \
                    --enable-libv4l2 \
                    --enable-v4l2-m2m \
                    --pkg-config=$(which pkg-config) \
                    --extra-cflags="-I$x264/include -I$v4l2/include -I$alsa/include -w" \
                    --extra-ldflags="-L$x264/lib -lx264 -L$v4l2/lib -lv4l2 -L$alsa/lib -lasound -Wl,-rpath-link=$v4l2/lib" \
                    --enable-decoder=h264 \
                    --enable-encoder=libx264 \
                    --enable-indev=v4l2 \
                    --enable-outdev=v4l2 \
                    --enable-encoder=h264_v4l2m2m \
                    --enable-decoder=h264_v4l2m2m \
                    --enable-pic \
                    --enable-ffmpeg \
                    --disable-stripping \
                    --disable-doc \
                    --enable-small
        ;;
    esac

    make -j$(nproc)
    make install
    echo "build $1 ffmpeg end ..." && export FFMPEG_OUTPUT=$FFmpeg/build
}

kernel_build() {
    if [ "$1" != "" ] && [ "$1" != "vpu" ]
    then
        echo "linux build parameter error!" > /dev/tty
        return 1;
    fi

    cd $KERNEL && make distclean
    rm -rf build && mkdir build
    local build=$(pwd)/build

    # Image
    make flyc_m200_defconfig ARCH=arm64
    make Image CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 -j$(nproc)
    mv arch/arm64/boot/Image $build && echo "build Image successful" > /dev/tty

    # DTS
    make flyc/m200-fpga.dtb CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64
    make flyc/m200-palladium.dtb CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64
    mv arch/arm64/boot/dts/flyc/*.dtb $build && echo "build m200-fpga.dtb m200-palladium.dtb successful" > /dev/tty

    # modules
    make modules CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 -j$(nproc) && echo "build modules successful" > /dev/tty

    if [ "$1" = "vpu" ]
    then
        cd $VPU
        sh clean.sh
        sh build.sh
        mv bin/aarch64-linux-gnu/amvx.ko $build && echo "build vpu successful" > /dev/tty
    fi

    export LINUX_OUTPUT=$build && cp $build/Image $build/*.dtb $OUTPUT 
}

rootfs_build() {
    if [ "$1" != "ffmpeg" ] && [ "$1" != "vpu" ] && [ "$1" != "all" ] && [ "$1" != "clean" ]
    then
        echo "rootfs build parameter error!" > /dev/tty
        return 1;
    fi

    if [ "$FFMPEG_OUTPUT" = "" ]
    then
        export FFMPEG_OUTPUT=$FFmpeg/build
    fi

    if [ "$LINUX_OUTPUT" = "" ]
    then
        export LINUX_OUTPUT=$KERNEL/build
    fi

    case "$1" in
        ffmpeg)
            echo "ffmpeg_build_output: $FFMPEG_OUTPUT" > /dev/tty
            cd $ROOTFS/prebuild/buildroot_flyc.mini/rootfs.tmp

            chmod a+x $FFMPEG_OUTPUT/bin/* && cp $FFMPEG_OUTPUT/bin/* ./bin
            find $FFMPEG_OUTPUT/lib -name "lib*so*"  -exec cp -d {} ./lib \;
            find $FFMPEG_OUTPUT/v4l2/lib \( -name "*v4l2.so*" -o -name "*libv4lconvert.so*" \) -exec cp -d {} ./lib \;
            find $FFMPEG_OUTPUT/x264/lib -name "*x264.so*" -exec cp -d {} ./lib \;
            find $FFMPEG_OUTPUT/alsa/lib -name "*asound.so*" -exec cp -d {} ./lib \;

            # alsa external share file
            rm -rf ./usr/share/alsa && mkdir ./usr/share/alsa && cp -r $FFMPEG_OUTPUT/alsa/config/* ./usr/share/alsa

            cd ..
            sh mk.sh > build.log && echo "build rootfs ffmpeg complete!" > /dev/tty
        ;;
        vpu)
            echo "vpu_build_output: $LINUX_OUTPUT" > /dev/tty
            cd $ROOTFS/prebuild/buildroot_flyc.mini/rootfs.tmp

            cp $LINUX_OUTPUT/*.ko ./root

            cd ..
            sh mk.sh > build.log && echo "build rootfs vpu complete!" > /dev/tty
        ;;
        clean)
            echo "rootfs clean: $ROOTFS/prebuild/buildroot_flyc.mini/rootfs.tmp" > /dev/tty
            cd $ROOTFS/prebuild/buildroot_flyc.mini/rootfs.tmp

            rm ./bin/ff*
            rm ./root/*.ko
            find ./lib \( -name "libav*.so*" -o -name "*libsw*.so*" \) -exec rm {} \;
            find ./lib \( -name "*v4l2.so*" -o -name "*libv4lconvert.so*" \) -exec rm {} \;
            find ./lib -name "*x264.so*" -exec rm {} \;
            find ./lib -name "*asound.so*" -exec rm {} \;
            rm -rf ./usr/share/alsa

            cd ..
            sh mk.sh > build.log && echo "rootfs clean complete!" > /dev/tty
        ;;
        all)
            echo "ffmpeg_build_output: $FFMPEG_OUTPUT" > /dev/tty && echo "vpu_build_output: $LINUX_OUTPUT" > /dev/tty
            cd $ROOTFS/prebuild/buildroot_flyc.mini/rootfs.tmp

            chmod a+x $FFMPEG_OUTPUT/bin/* && cp $FFMPEG_OUTPUT/bin/* ./bin
            find $FFMPEG_OUTPUT/lib -name "lib*so*"  -exec cp -d {} ./lib \;
            find $FFMPEG_OUTPUT/v4l2/lib \( -name "*v4l2.so*" -o -name "*libv4lconvert.so*" \) -exec cp -d {} ./lib \;
            find $FFMPEG_OUTPUT/x264/lib -name "*x264.so*" -exec cp -d {} ./lib \;
            find $FFMPEG_OUTPUT/alsa/lib -name "*asound.so*" -exec cp -d {} ./lib \;
            cp $LINUX_OUTPUT/*.ko ./root

            # alsa external share file
            rm -rf ./usr/share/alsa && mkdir ./usr/share/alsa && cp -r /usr/share/alsa/* ./usr/share/alsa

            cd ..
            sh mk.sh > build.log && echo "build rootfs all complete!" > /dev/tty
        ;;
    esac

    cd $ROOTFS/prebuild/buildroot_flyc.mini && cp initrd_flyc_mini.cpio* $OUTPUT
}

case "$1" in
    ffmpeg)
        if [ "$2" = "" ]
        then
        ffmpeg_build aarch64 > build.log && echo "build aarch64 ffmpeg complete!"
        else
        ffmpeg_build $2 > build.log && echo "build $2 ffmpeg complete!" >> /dev/tty
        fi
    ;;
    linux)
        kernel_build $2 > build.log && echo "build linux Image dtb $2 complete!" >> /dev/tty
    ;;
    rootfs)
        rootfs_build $2 > build.log
    ;;
    all)
        ffmpeg_build aarch64 > build.log && echo "build aarch64 ffmpeg complete!"
        kernel_build vpu > build.log && echo "build linux Image dtb $2 complete!" >> /dev/tty
        rootfs_build all > build.log && echo "build rootfs complete!" >> /dev/tty
    ;;
    --help)
        echo "Usage: sh build.sh [parameter] ..."
        echo "       sh build.sh ffmpeg           build ffmpeg with v4l2 and x264, current ffmpeg project path: $FFmpeg, need to change env depending on ffmpeg code path"
        echo "       sh build.sh linux            build linux Image and DTB, current linux kernel code path: $KERNEL, need to change env depending on linux kernel code path"
        echo "       sh build.sh linux vpu        build linux kernel Image 、DTB and vpu, current vpu code path: $VPU, need to change env depending on vpu code path"
        echo "       sh build.sh rootfs ffmpeg    cpio the rootfs with ffmpeg output, current rootfs path: $ROOTFS, ensure the ffmpeg build is complete"
        echo "       sh build.sh roots vpu        cpio the rootfs with vpu output, current rootfs path: $ROOTFS, ensure the vpu build is complete"
        echo "       sh build.sh roots all        cpio the rootfs with ffmpeg and vpu output, current rootfs path: $ROOTFS, ensure the ffmpeg and vpu build is complete"
        echo "       sh build.sh roots clean      clean ffmpeg and vpu outputs in the rootfs, current rootfs path: $ROOTFS, "
        echo "       sh build.sh all              build linux and so on, cpio the rootfs with the outputs"
    ;;
esac


