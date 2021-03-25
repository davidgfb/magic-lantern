#!/usr/bin/env bash

SYSTEM=`uname`
echo "Setting up QEMU on $SYSTEM..."

OPTIONS="--target-list=arm-softmmu --disable-docs --enable-vnc --audio-drv-list="

if python2 -V; then
    OPTIONS="$OPTIONS --python=python2"
fi

if [[ $SYSTEM == "Darwin" ]]; then
    # Mac uses clang and Cocoa by default; it doesn't like SDL
    export CC=${CC:=clang}
    OPTIONS="$OPTIONS --disable-sdl"
else
    # gcc 4 uses gnu90 by default, but we use C99 code
    # passing C99 to g++ gives warning, but QEMU treats all warnings as errors
    # QEMU_CPPFLAGS is derived from QEMU_CFLAGS in ./configure
    export CC=${CC:=gcc --std=gnu99}

    if [[ $DISPLAY != "" ]]; then
        # gtk is recommended, but sdl works too
        OPTIONS="$OPTIONS --enable-gtk"
    fi
fi

if [[ $CC == clang* ]]; then
    # fixme: some warnings about format strings in conditional expressions
    # still needed? could not reproduce on recent systems (tested clang 3.8, 10.x, 12.x)
    #EXTRA_CFLAGS="$EXTRA_CFLAGS -Wno-format-extra-args -Wno-format-zero-length"
    export CXX=${CXX:=clang++}
    if [[ $CXX != clang++* ]]; then
        echo "Warning: not using clang++ (check CXX)"
    fi
fi

if [[ $CC == gcc* ]]; then
    export CXX=${CXX:=g++}
    GCC_VERSION=$($CC -dumpfullversion -dumpversion)
    GPP_VERSION=$($CXX -dumpfullversion -dumpversion)
    GCC_MAJOR=${GCC_VERSION%%.*}
    GPP_MAJOR=${GPP_VERSION%%.*}

    if $CC -v 2>&1 | grep -q clang; then
        echo "This version of gcc is actually clang..."
        # no known warnings on current systems
    else
        if (($GCC_MAJOR >= 6)); then
            # gcc 6 warns about readdir_r
            EXTRA_CFLAGS="$EXTRA_CFLAGS -Wno-error=deprecated-declarations"
        fi
        if (($GCC_MAJOR >= 9)); then
            # gcc 9 warns about unaligned pointer in packed structures and some more
            # gcc 10 also warns about stringop-overflow
            EXTRA_CFLAGS="$EXTRA_CFLAGS -Wno-error=address-of-packed-member -Wno-error=stringop-truncation -Wno-error=stringop-overflow -Wno-error=format-truncation"
        fi
    fi

    if [[ $CXX != g++* ]]; then
        echo "Warning: not using g++ (check CXX)"
    fi
    if [[ "$GCC_VERSION" != "$GPP_VERSION" ]]; then
        # QEMU configure script will take care of this one
        echo "Warning: different gcc/g++ version (gcc $GCC_VERSION, g++ $GPP_VERSION)"
    fi
fi

echo "Using $CC $GCC_VERSION / $CXX $GPP_VERSION with flags: $EXTRA_CFLAGS"
echo "Options: $OPTIONS $@"

./configure $OPTIONS --extra-cflags="$EXTRA_CFLAGS" "$@"
