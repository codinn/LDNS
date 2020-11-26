#!/bin/sh

#  Automatic build script for ldns
#  for Apple devices.
#
#  Created by Felix Schulze on 16.12.10.
#  Copyright 2010-2017 Felix Schulze. All rights reserved.
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

# -u  Attempt to use undefined variable outputs error message, and forces an exit
set -u

# SCRIPT DEFAULTS

# Default version in case no version is specified
DEFAULTVERSION="1.7.1"

# Init optional env variables (use available variable or default to empty string)
CURL_OPTIONS="${CURL_OPTIONS:-}"
CONFIG_OPTIONS="${CONFIG_OPTIONS:-}"

echo_help()
{
  echo "Usage: $0 [options...]"
  echo "Generic options"
  echo "     --cleanup                     Clean up build directories (bin, include/ldns, lib, src) before starting build"
  echo " -h, --help                        Print help (this message)"
  echo "     --ios-sdk=SDKVERSION          Override iOS SDK version"
  echo "     --macos-sdk=SDKVERSION        Override macOS SDK version"
  echo "     --catalyst-sdk=SDKVERSION     Override macOS SDK version for Catalyst"
  echo "     --watchos-sdk=SDKVERSION      Override watchOS SDK version"
  echo "     --tvos-sdk=SDKVERSION         Override tvOS SDK version"
  echo "     --min-ios-sdk=SDKVERSION      Set minimum iOS SDK version"
  echo "     --min-macos-sdk=SDKVERSION    Set minimum macOS SDK version"
  echo "     --min-watchos-sdk=SDKVERSION  Set minimum watchOS SDK version"
  echo "     --min-tvos-sdk=SDKVERSION     Set minimum tvOS SDK version"
  echo "     --noparallel                  Disable running make with parallel jobs (make -j)"
  echo " -v, --verbose                     Enable verbose logging"
  echo "     --verbose-on-error            Dump last 500 lines from log file if an error occurs (for Travis builds)"
  echo "     --version=VERSION             LDNS version to build (defaults to ${DEFAULTVERSION})"
  echo "     --targets=\"TARGET TARGET ...\" Space-separated list of build targets"
  echo "                                     Options: ${DEFAULTTARGETS}"
  echo
  echo "For custom configure options, set variable CONFIG_OPTIONS"
  echo "For custom cURL options, set variable CURL_OPTIONS"
  echo "  Example: CURL_OPTIONS=\"--proxy 192.168.1.1:8080\" ./build-ldns.sh"
}

spinner()
{
  local pid=$!
  local delay=0.75
  local spinstr='|/-\'
  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    local temp=${spinstr#?}
    printf "  [%c]" "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b"
  done

  wait $pid
  return $?
}

# Prepare target and source dir in build loop
prepare_target_source_dirs()
{
  # Prepare target dir
  TARGETDIR="${CURRENTPATH}/build/bin/${PLATFORM}${SDKVERSION}-${ARCH}.sdk"
  mkdir -p "${TARGETDIR}"
  LOG="${TARGETDIR}/build-ldns-${VERSION}.log"

  echo "Building ldns-${VERSION} for (${TARGET}): ${PLATFORM} ${SDKVERSION} [min ${MIN_SDK_VERSION}] ${ARCH}..."
  echo "  Logfile: ${LOG}"

  # Prepare source dir
  SOURCEDIR="${CURRENTPATH}/build/src/${PLATFORM}-${ARCH}"
  mkdir -p "${SOURCEDIR}"
  # tar zxf "${CURRENTPATH}/${LDNS_ARCHIVE_FILE_NAME}" -C "${SOURCEDIR}"
  cp -R ${CURRENTPATH}/ldns ${SOURCEDIR}
  cd "${SOURCEDIR}/ldns"
  chmod u+x ./configure
}

# Check for error status
check_status()
{
  local STATUS=$1
  local COMMAND=$2

  if [ "${STATUS}" != 0 ]; then
    if [[ "${LOG_VERBOSE}" != "verbose"* ]]; then
      echo "Problem during ${COMMAND} - Please check ${LOG}"
    fi

    # Dump last 500 lines from log file for verbose-on-error
    if [ "${LOG_VERBOSE}" == "verbose-on-error" ]; then
      echo "Problem during ${COMMAND} - Dumping last 500 lines from log file"
      echo
      tail -n 500 "${LOG}"
    fi

    exit 1
  fi
}

# Run Configure in build loop
run_configure()
{
  ## Determine config options
  # Add build target, --prefix and prevent async (references to getcontext(),
  # setcontext() and makecontext() result in App Store rejections) and creation
  # of shared libraries (default since 1.1.0)
  local SSL_PATH="${CURRENTPATH}/build/openssl/${PLATFORM}${SDKVERSION}-${ARCH}.sdk"
  local LOCAL_CONFIG_OPTIONS="--host=${CONFIG_HOST} --prefix=${TARGETDIR} --without-xcode-sdk --disable-shared --without-drill --disable-gost --without-examples --without-pyldns --with-ssl=${SSL_PATH} ${CONFIG_OPTIONS}"

  echo "  Configure..."
  set +e
  if [ "${LOG_VERBOSE}" == "verbose" ]; then
    CFLAGS="${SDK_CFLAGS}"./configure ${LOCAL_CONFIG_OPTIONS} | tee "${LOG}"
  else
    (CFLAGS="${SDK_CFLAGS}" ./configure ${LOCAL_CONFIG_OPTIONS} > "${LOG}" 2>&1) & spinner
  fi

  # Check for error status
  check_status $? "Configure"
}

# Run make in build loop
run_make()
{
  echo "  Make (using ${BUILD_THREADS} thread(s))..."
  if [ "${LOG_VERBOSE}" == "verbose" ]; then
    make -j "${BUILD_THREADS}" | tee -a "${LOG}"
  else
    (make -j "${BUILD_THREADS}" >> "${LOG}" 2>&1) & spinner
  fi

  # Check for error status
  check_status $? "make"
}

# Run make install in build loop
run_make_install()
{
  set -e
  if [ "${LOG_VERBOSE}" == "verbose" ]; then
    make install | tee -a "${LOG}"
  else
    make install >> "${LOG}" 2>&1
  fi

  # Check for error status
  check_status $? "make install"
}

# Cleanup and bookkeeping at end of build loop
finish_build_loop()
{
  # Return to ${CURRENTPATH} and remove source dir
  cd "${CURRENTPATH}"
  rm -r "${SOURCEDIR}"

  # Add references to library files to relevant arrays
  if [[ "${PLATFORM}" == iPhone* ]]; then
    LIBLDNS_IOS+=("${TARGETDIR}/lib/libldns.a")
    if [[ "${PLATFORM}" == iPhoneSimulator* ]]; then
      LDNSCONF_SUFFIX="ios_sim_${ARCH}"
    else
      LDNSCONF_SUFFIX="ios_${ARCH}"
    fi
  elif [[ "${PLATFORM}" == Watch* ]]; then
    LIBLDNS_WATCHOS+=("${TARGETDIR}/lib/libldns.a")
    if [[ "${PLATFORM}" == WatchSimulator* ]]; then
      LDNSCONF_SUFFIX="watchos_sim_${ARCH}"
    else
      LDNSCONF_SUFFIX="watchos_${ARCH}"
    fi
  elif [[ "${PLATFORM}" == AppleTV* ]]; then
    LIBLDNS_TVOS+=("${TARGETDIR}/lib/libldns.a")
    if [[ "${PLATFORM}" == AppleTVSimulator* ]]; then
      LDNSCONF_SUFFIX="tvos_sim_${ARCH}"
    else
      LDNSCONF_SUFFIX="tvos_${ARCH}"
    fi
  elif [[ "${PLATFORM}" == Catalyst* ]]; then
    LIBLDNS_CATALYST+=("${TARGETDIR}/lib/libldns.a")
    LDNSCONF_SUFFIX="catalyst_${ARCH}"
  else
    LIBLDNS_MACOS+=("${TARGETDIR}/lib/libldns.a")
    LDNSCONF_SUFFIX="macos_${ARCH}"
  fi

  # Copy common.h to bin directory and add to array
  LDNSCONF="common_${LDNSCONF_SUFFIX}.h"
  cp "${TARGETDIR}/include/ldns/common.h" "${CURRENTPATH}/build/bin/${LDNSCONF}"
  LDNSCONF_ALL+=("${LDNSCONF}")

  # Keep reference to first build target for include file
  if [ -z "${INCLUDE_DIR}" ]; then
    INCLUDE_DIR="${TARGETDIR}/include/ldns"
  fi
}

# Init optional command line vars
ARCHS=""
CLEANUP=""
IOS_SDKVERSION=""
MACOS_SDKVERSION=""
CATALYST_SDKVERSION=""
WATCHOS_SDKVERSION=""
TVOS_SDKVERSION=""
LOG_VERBOSE=""
PARALLEL=""
TARGETS=""
VERSION=""

# Process command line arguments
for i in "$@"
do
case $i in
  --cleanup)
    CLEANUP="true"
    ;;
  -h|--help)
    echo_help
    exit
    ;;
  --ios-sdk=*)
    IOS_SDKVERSION="${i#*=}"
    shift
    ;;
  --macos-sdk=*)
    MACOS_SDKVERSION="${i#*=}"
    shift
    ;;
  --catalyst-sdk=*)
    CATALYST_SDKVERSION="${i#*=}"
    shift
    ;;
  --watchos-sdk=*)
    WATCHOS_SDKVERSION="${i#*=}"
    shift
    ;;
  --tvos-sdk=*)
    TVOS_SDKVERSION="${i#*=}"
    shift
    ;;
  --min-ios-sdk=*)
    IOS_MIN_SDK_VERSION="${i#*=}"
    shift
    ;;
  --min-macos-sdk=*)
    MACOS_MIN_SDK_VERSION="${i#*=}"
    shift
    ;;
  --min-watchos-sdk=*)
    WATCHOS_MIN_SDK_VERSION="${i#*=}"
    shift
    ;;
  --min-tvos-sdk=*)
    TVOS_MIN_SDK_VERSION="${i#*=}"
    shift
    ;;
  --noparallel)
    PARALLEL="false"
    ;;
  --targets=*)
    TARGETS="${i#*=}"
    shift
    ;;
  -v|--verbose)
    LOG_VERBOSE="verbose"
    ;;
  --verbose-on-error)
    LOG_VERBOSE="verbose-on-error"
    ;;
  --version=*)
    VERSION="${i#*=}"
    shift
    ;;
  *)
    echo "Unknown argument: ${i}"
    ;;
esac
done

# Don't mix version and branch
if [ -z "${VERSION}" ]; then
  VERSION="${DEFAULTVERSION}"
fi

# Determine number of cores for (parallel) build
BUILD_THREADS=1
if [ "${PARALLEL}" != "false" ]; then
  BUILD_THREADS=$(sysctl hw.ncpu | awk '{print $2}')
fi

# Determine script directory
SCRIPTDIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

# Write files relative to current location and validate directory
CURRENTPATH=$(pwd)
case "${CURRENTPATH}" in
  *\ * )
    echo "Your path contains whitespaces, which is not supported by 'make install'."
    exit 1
  ;;
esac
cd "${CURRENTPATH}"

# Show build options
echo
echo "Build options"
echo "  LDNS version: ${VERSION}"
echo "  Number of make threads: ${BUILD_THREADS}"
if [ -n "${CONFIG_OPTIONS}" ]; then
  echo "  Configure options: ${CONFIG_OPTIONS}"
fi
echo "  Build location: ${CURRENTPATH}"
echo

# # Download LDNS when not present
# LDNS_ARCHIVE_BASE_NAME="ldns-${VERSION}"
# LDNS_ARCHIVE_FILE_NAME="${LDNS_ARCHIVE_BASE_NAME}.tar.gz"
# if [ ! -e ${LDNS_ARCHIVE_FILE_NAME} ]; then
#   echo "Downloading ${LDNS_ARCHIVE_FILE_NAME}..."
#   LDNS_ARCHIVE_URL="https://nlnetlabs.nl/downloads/ldns/${LDNS_ARCHIVE_FILE_NAME}"

#   # Check whether file exists here (this is the location of the latest version for each branch)
#   # -s be silent, -f return non-zero exit status on failure, -I get header (do not download)
#   curl ${CURL_OPTIONS} -sfI "${LDNS_ARCHIVE_URL}" > /dev/null

#   # Both attempts failed, so report the error
#   if [ $? -ne 0 ]; then
#     echo "An error occurred trying to find LDNS ${VERSION} on ${LDNS_ARCHIVE_URL}"
#     echo "Please verify that the version you are trying to build exists, check cURL's error message and/or your network connection."
#     exit 1
#   fi

#   # Archive was found, so proceed with download.
#   # -O Use server-specified filename for download
#   curl ${CURL_OPTIONS} -O "${LDNS_ARCHIVE_URL}"

# else
#   echo "Using ${LDNS_ARCHIVE_FILE_NAME}"
# fi

# -e  Abort script at first error, when a command exits with non-zero status (except in until or while loops, if-tests, list constructs)
# -o pipefail  Causes a pipeline to return the exit status of the last command in the pipe that returned a non-zero return value
set -eo pipefail

# Clean up target directories if requested and present
if [ "${CLEANUP}" == "true" ]; then
  if [ -d "${CURRENTPATH}/build/bin" ]; then
    rm -r "${CURRENTPATH}/build/bin"
  fi
  if [ -d "${CURRENTPATH}/build/include/ldns" ]; then
    rm -r "${CURRENTPATH}/build/include/ldns"
  fi
  if [ -d "${CURRENTPATH}/build/lib" ]; then
    rm -r "${CURRENTPATH}/build/lib"
  fi
  if [ -d "${CURRENTPATH}/build/src" ]; then
    rm -r "${CURRENTPATH}/build/src"
  fi
fi

# (Re-)create target directories
mkdir -p "${CURRENTPATH}/build/bin"
mkdir -p "${CURRENTPATH}/build/lib"
mkdir -p "${CURRENTPATH}/build/src"

# Init vars for library references
INCLUDE_DIR=""
LDNSCONF_ALL=()
LIBLDNS_IOS=()
LIBLDNS_MACOS=()
LIBLDNS_CATALYST=()
LIBLDNS_WATCHOS=()
LIBLDNS_TVOS=()

source "${SCRIPTDIR}/apple-config.sh"

# Copy include directory
cp -R "${INCLUDE_DIR}" "${CURRENTPATH}/build/include/"

# Only create intermediate file when building for multiple targets
# For a single target, common.h is still present in $INCLUDE_DIR (and has just been copied to the target include dir)
if [ ${#LDNSCONF_ALL[@]} -gt 1 ]; then

  # Prepare intermediate header file
  # This overwrites common.h that was copied from $INCLUDE_DIR
  LDNSCONF_INTERMEDIATE="${CURRENTPATH}/build/include/ldns/common.h"
  cp "${CURRENTPATH}/common-template.h" "${LDNSCONF_INTERMEDIATE}"

  # Loop all header files
  LOOPCOUNT=0
  for LDNSCONF_CURRENT in "${LDNSCONF_ALL[@]}" ; do

    # Copy specific common file to include dir
    cp "${CURRENTPATH}/build/bin/${LDNSCONF_CURRENT}" "${CURRENTPATH}/build/include/ldns"

    # Determine define condition
    case "${LDNSCONF_CURRENT}" in
      *_ios_arm64.h)
        DEFINE_CONDITION="TARGET_OS_IOS && TARGET_OS_EMBEDDED && TARGET_CPU_ARM64"
      ;;
      *_ios_arm64e.h)
        DEFINE_CONDITION="TARGET_OS_IOS && TARGET_OS_EMBEDDED && TARGET_CPU_ARM64E"
      ;;
      *_ios_sim_x86_64.h)
        DEFINE_CONDITION="TARGET_OS_IOS && TARGET_OS_SIMULATOR && TARGET_CPU_X86_64"
      ;;
      *_ios_sim_arm64.h)
        DEFINE_CONDITION="TARGET_OS_IOS && TARGET_OS_SIMULATOR && TARGET_CPU_ARM64"
      ;;
      *_macos_x86_64.h)
        DEFINE_CONDITION="TARGET_OS_OSX && TARGET_CPU_X86_64"
      ;;
      *_macos_arm64.h)
        DEFINE_CONDITION="TARGET_OS_OSX && TARGET_CPU_ARM64"
      ;;
      *_catalyst_x86_64.h)
        DEFINE_CONDITION="(TARGET_OS_MACCATALYST || (TARGET_OS_IOS && TARGET_OS_SIMULATOR)) && TARGET_CPU_X86_64"
      ;;
      *_catalyst_arm64.h)
        DEFINE_CONDITION="(TARGET_OS_MACCATALYST || (TARGET_OS_IOS && TARGET_OS_SIMULATOR)) && TARGET_CPU_ARM64"
      ;;
      *_watchos_armv7k.h)
        DEFINE_CONDITION="TARGET_OS_WATCHOS && TARGET_OS_EMBEDDED && TARGET_CPU_ARMV7K"
      ;;
      *_watchos_arm64_32.h)
        DEFINE_CONDITION="TARGET_OS_WATCHOS && TARGET_OS_EMBEDDED && TARGET_CPU_ARM64_32"
      ;;
      *_watchos_sim_x86_64.h)
        DEFINE_CONDITION="TARGET_OS_SIMULATOR && TARGET_CPU_X86_64 || TARGET_OS_EMBEDDED"
      ;;
      *_tvos_arm64.h)
        DEFINE_CONDITION="TARGET_OS_TV && TARGET_OS_EMBEDDED && TARGET_CPU_ARM64"
      ;;
      *_tvos_sim_x86_64.h)
        DEFINE_CONDITION="TARGET_OS_TV && TARGET_OS_SIMULATOR && TARGET_CPU_X86_64"
      ;;
      *)
        # Don't run into unexpected cases by setting the default condition to false
        DEFINE_CONDITION="0"
      ;;
    esac

    # Determine loopcount; start with if and continue with elif
    LOOPCOUNT=$((LOOPCOUNT + 1))
    if [ ${LOOPCOUNT} -eq 1 ]; then
      echo "#if ${DEFINE_CONDITION}" >> "${LDNSCONF_INTERMEDIATE}"
    else
      echo "#elif ${DEFINE_CONDITION}" >> "${LDNSCONF_INTERMEDIATE}"
    fi

    # Add include
    echo "# include <ldns/${LDNSCONF_CURRENT}>" >> "${LDNSCONF_INTERMEDIATE}"
  done

  # Finish
  echo "#else" >> "${LDNSCONF_INTERMEDIATE}"
  echo '# error Unable to determine target or target not included in LDNS build' >> "${LDNSCONF_INTERMEDIATE}"
  echo "#endif" >> "${LDNSCONF_INTERMEDIATE}"
fi

echo "Done."
