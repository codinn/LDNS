#!/bin/sh

#  Automatic build environments script for Apple platforms
#
#  Created by Yang Yubo on 2020.11.25.
#  Copyright 2020 Yang Yubo. All rights reserved.
# 
#  Based on work of [openssl-apple](https://github.com/keeshux/openssl-apple)
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

# Validate Xcode Developer path
DEVELOPER=$(xcode-select -print-path)
if [ ! -d "${DEVELOPER}" ]; then
  echo "Xcode path is not set correctly ${DEVELOPER} does not exist"
  echo "run"
  echo "sudo xcode-select -switch <Xcode path>"
  echo "for default installation:"
  echo "sudo xcode-select -switch /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

case "${DEVELOPER}" in
  *\ * )
    echo "Your Xcode path contains whitespaces, which is not supported."
    exit 1
  ;;
esac

function generate_apple_envs() {
  TARGET=$1
  # Extract ARCH from TARGET (part after last dash)
  ARCH=$(echo "${TARGET}" | sed -E 's|^.*\-([^\-]+)$|\1|g')

  SDK_CFLAGS=
  CONFIG_HOST=

  # Determine relevant SDK version and platform
  if [[ "${TARGET}" == macos* ]]; then
    ## Apple macOS
    if [ -z ${MACOS_MIN_SDK_VERSION+x} ]; then
      MACOS_MIN_SDK_VERSION="10.13"
    fi

    if [ ! -n "${MACOS_SDKVERSION}" ]; then
      MACOS_SDKVERSION=$(xcrun -sdk macosx --show-sdk-version)
    fi

    # Truncate to minor version
    MINOR_VERSION=(${MACOS_SDKVERSION//./ })
    MACOS_SDKVERSION="${MINOR_VERSION[0]}.${MINOR_VERSION[1]}"

    SDKVERSION="${MACOS_SDKVERSION}"
    PLATFORM="MacOSX"
    if [[ "${TARGET}" == "macos64-arm64" ]]; then
      MACOS_MIN_SDK_VERSION="11.0"
      CONFIG_HOST="arm-apple-darwin"
    else
      CONFIG_HOST="x86_64-apple-darwin"
    fi
    MIN_SDK_VERSION=${MACOS_MIN_SDK_VERSION}

    # CFLAGS
    SDK_CFLAGS="-mmacosx-version-min=${MACOS_MIN_SDK_VERSION}"

  elif [[ "${TARGET}" == mac-catalyst-* ]]; then

    # Catalyst
    if [ -z ${CATALYST_MIN_SDK_VERSION+x} ]; then
      CATALYST_MIN_SDK_VERSION="10.15"
    fi

    if [ ! -n "${CATALYST_SDKVERSION}" ]; then
      CATALYST_SDKVERSION=$(xcrun -sdk macosx --show-sdk-version)
    fi

    # Truncate to minor version
    MINOR_VERSION=(${CATALYST_SDKVERSION//./ })
    CATALYST_SDKVERSION="${MINOR_VERSION[0]}.${MINOR_VERSION[1]}"

    SDKVERSION="${CATALYST_SDKVERSION}"
    PLATFORM="MacOSX"
    MIN_SDK_VERSION=${CATALYST_MIN_SDK_VERSION}

    # CFLAGS
    if [[ "${TARGET}" == "mac-catalyst-x86_64" ]]; then
      # Catalyst (x86_64)
      SDK_CFLAGS="-target x86_64-apple-ios13.0-macabi -mios-version-min=13.0"
      CONFIG_HOST="x86_64-apple-darwin"
    else
      # Catalyst (arm64)
      SDK_CFLAGS="-target arm64-apple-ios13.0-macabi -mios-version-min=13.0"
      CONFIG_HOST="arm-apple-darwin"
    fi

  elif [[ "${TARGET}" == watchos* ]]; then
    # watchOS cross
    if [ -z ${WATCHOS_MIN_SDK_VERSION+x} ]; then
      WATCHOS_MIN_SDK_VERSION="4.0"
    fi

    if [ ! -n "${WATCHOS_SDKVERSION}" ]; then
      WATCHOS_SDKVERSION=$(xcrun -sdk watchos --show-sdk-version)
    fi
    SDKVERSION="${WATCHOS_SDKVERSION}"
    if [[ "${TARGET}" == "watchos-sim-cross"* ]]; then
      PLATFORM="WatchSimulator"
      CONFIG_HOST="x86_64-apple-darwin"
    elif [[ "${TARGET}" == "watchos"* ]]; then
      PLATFORM="WatchOS"
      CONFIG_HOST="arm-apple-darwin"
    fi
    MIN_SDK_VERSION=${WATCHOS_MIN_SDK_VERSION}
    
    # CFLAGS
    SDK_CFLAGS="-mwatchos-version-min=${WATCHOS_MIN_SDK_VERSION}"

  elif [[ "${TARGET}" == tvos* ]]; then
    # tvOS cross
    if [ -z ${TVOS_MIN_SDK_VERSION+x} ]; then
      TVOS_MIN_SDK_VERSION="12.0"
    fi

    if [ ! -n "${TVOS_SDKVERSION}" ]; then
      TVOS_SDKVERSION=$(xcrun -sdk appletvos --show-sdk-version)
    fi
    SDKVERSION="${TVOS_SDKVERSION}"
    if [[ "${TARGET}" == "tvos-sim-cross-"* ]]; then
      PLATFORM="AppleTVSimulator"
      CONFIG_HOST="x86_64-apple-darwin"
    elif [[ "${TARGET}" == "tvos64-cross-"* ]]; then
      PLATFORM="AppleTVOS"
      CONFIG_HOST="arm-apple-darwin"
    fi
    MIN_SDK_VERSION=${TVOS_MIN_SDK_VERSION}
    
    # CFLAGS
    SDK_CFLAGS="-mtvos-version-min=${TVOS_MIN_SDK_VERSION}"

  else
    ## Apple iOS
    if [ -z ${IOS_MIN_SDK_VERSION+x} ]; then
      IOS_MIN_SDK_VERSION="12.0"
    fi

    if [ ! -n "${IOS_SDKVERSION}" ]; then
      IOS_SDKVERSION=$(xcrun -sdk iphoneos --show-sdk-version)
    fi
    SDKVERSION="${IOS_SDKVERSION}"
    if [[ "${TARGET}" == "ios-sim-cross-"* ]]; then
      PLATFORM="iPhoneSimulator"
      CONFIG_HOST="x86_64-apple-darwin"
    else
      PLATFORM="iPhoneOS"
      CONFIG_HOST="arm-apple-darwin"
    fi
    MIN_SDK_VERSION=${IOS_MIN_SDK_VERSION}

    # CFLAGS
    SDK_CFLAGS="-mios-version-min=${IOS_MIN_SDK_VERSION}"

    # Simulator (arm64)
    if [[ "${TARGET}" == "ios-sim-cross-arm64" ]]; then
      SDK_CFLAGS="${SDK_CFLAGS} -target arm64-apple-ios13.0-simulator -mios-version-min=13.0"
    fi
  fi

  # Cross compile references, see Configurations/10-main.conf
  local CROSS_COMPILE="${DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr/bin/"
  local CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
  local CROSS_SDK="${PLATFORM}${SDKVERSION}.sdk"

  # Prepare TARGETDIR and SOURCEDIR
  PLATFORM="${PLATFORM}"
  if [[ "${TARGET}" == "mac-catalyst-"* ]]; then
    PLATFORM="Catalyst"
  fi

  SDK_CFLAGS="-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -fno-common -fembed-bitcode -arch ${ARCH} ${SDK_CFLAGS}"
}

# Default (=full) set of targets
DEFAULTTARGETS=`cat <<TARGETS
ios-sim-cross-x86_64 ios-sim-cross-arm64 ios64-cross-arm64 ios64-cross-arm64e
macos64-x86_64 macos64-arm64
mac-catalyst-x86_64 mac-catalyst-arm64
watchos-cross-armv7k watchos-cross-arm64_32 watchos-sim-cross-x86_64
tvos-sim-cross-x86_64 tvos64-cross-arm64
TARGETS`

# Set default for TARGETS if not specified
if [ ! -n "${TARGETS}" ]; then
  TARGETS="${DEFAULTTARGETS}"
fi

if [ "$0" = "$BASH_SOURCE" ]; then
  ## Run standalone
  echo ------------------------- CFLAGS -------------------------
  for TARGET in ${TARGETS}
  do
    echo ${TARGET}:
    echo -------------------------
    generate_apple_envs "${TARGET}"
    echo ${SDK_CFLAGS}
    echo
  done
else
  ## Sourced
  for TARGET in ${TARGETS}
  do
    echo ${TARGET}:
    echo -------------------------
    generate_apple_envs "${TARGET}"
    echo SDK_CFLAGS: ${SDK_CFLAGS}
    echo -------------------------

    prepare_target_source_dirs
    
    # Run Configure
    run_configure

    # Run make
    run_make

    # Run make install
    run_make_install

    # Remove source dir, add references to library files to relevant arrays
    # Keep reference to first build target for include file
    finish_build_loop
  done
fi
