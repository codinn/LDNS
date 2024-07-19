#!/bin/sh

set -euo pipefail

if [ $# == 0 ]; then
    echo "Usage: `basename $0` full|compact"
    exit 1
fi

if [ ! -d build/bin ]; then
    echo "Please run build-ldns.sh first!"
    exit 1
fi

BUILD_TYPE=$1
FWNAME=ldns
FWROOT=build/frameworks
LIBNAME=ldns
ARGS=

if [ $BUILD_TYPE == "full" ]; then
    ALL_SYSTEMS=("iPhoneOS" "iPhoneSimulator" "AppleTVOS" "AppleTVSimulator" "MacOSX" "Catalyst" "WatchOS" "WatchSimulator" "XROS" "XRSimulator")
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
	SYSDISTS=(build/bin/${SYS}*)
	LIPO_LIBS=

	mkdir -p $SYSDIR
    for DIST in ${SYSDISTS[@]}; do
    	LIPO_LIBS+=" $DIST/lib/libldns.a"
        ditto "$DIST/include" "$SYSDIR/include"
    done

	lipo ${LIPO_LIBS} -create -output $SYSDIR/libldns.a
	ARGS+=" -library $SYSDIR/libldns.a -headers $SYSDIR/include/"
done

echo "Creating xcframework"
xcodebuild -create-xcframework $ARGS -output "$FWROOT/$FWNAME.xcframework"

echo "Packing …"
ditto -c -k --keepParent "$FWROOT/$FWNAME.xcframework" "$FWROOT/$FWNAME.xcframework.zip"
echo "Computing checksum …"
swift package compute-checksum $FWROOT/$FWNAME.xcframework.zip
echo "Done"
