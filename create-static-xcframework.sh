#!/bin/sh

set -euo pipefail

if [ $# == 0 ]; then
    echo "Usage: `basename $0` full|compact"
    exit 1
fi

if [ ! -d lib ]; then
    echo "Please run build-libssl.sh first!"
    exit 1
fi

BUILD_TYPE=$1
FWNAME=openssl-apple
FWROOT=frameworks
LIBNAME=openssl
ARGS=
XCFRAMEWORK_DEPS=

if [ $BUILD_TYPE == "full" ]; then
    ALL_SYSTEMS=("iPhoneOS" "iPhoneSimulator" "AppleTVOS" "AppleTVSimulator" "MacOSX" "Catalyst" "WatchOS" "WatchSimulator")
else
    ALL_SYSTEMS=("iPhoneOS" "iPhoneSimulator" "MacOSX")
fi

if [ -d $FWROOT ]; then
    echo "Removing previous $FWNAME.xcframework and intermediate files"
    rm -rf $FWROOT
fi

for SYS in ${ALL_SYSTEMS[@]}; do
    echo "Creating universal static libraries for $SYS"
    SYSDIR="$FWROOT/$SYS"
	SYSDISTS=(bin/${SYS}*)
	LIPO_LIBS=
    LIPO_SSL_LIBS=
    LIPO_CRYPTO_LIBS=

	mkdir -p $SYSDIR
    for DIST in ${SYSDISTS[@]}; do
    	libtool -static -o $DIST/lib/libopenssl.a $DIST/lib/libcrypto.a $DIST/lib/libssl.a
    	LIPO_LIBS+=" $DIST/lib/libopenssl.a"
        LIPO_SSL_LIBS+=" $DIST/lib/libssl.a"
        LIPO_CRYPTO_LIBS+=" $DIST/lib/libcrypto.a"
    done

    lipo ${LIPO_SSL_LIBS} -create -output $SYSDIR/libssl.a
    lipo ${LIPO_CRYPTO_LIBS} -create -output $SYSDIR/libcrypto.a
	lipo ${LIPO_LIBS} -create -output $SYSDIR/libopenssl.a
	ARGS+=" -library $SYSDIR/libopenssl.a -headers include/"
	XCFRAMEWORK_DEPS+=" $SYSDIR/libopenssl.a"
done

echo "Creating xcframework"
xcodebuild -create-xcframework $ARGS -output "$FWROOT/$FWNAME.xcframework"

echo "Packing and computing checksum"
zip -rq "$FWROOT/$FWNAME.xcframework.zip" "$FWROOT/$FWNAME.xcframework"
swift package compute-checksum $FWROOT/$FWNAME.xcframework.zip
