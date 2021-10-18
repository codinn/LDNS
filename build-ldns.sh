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
VERSION=
PARALLEL=

# Init optional env variables (use available variable or default to empty string)
CURL_OPTIONS="${CURL_OPTIONS:-}"
CONFIG_OPTIONS="${CONFIG_OPTIONS:-}"

extra_help() {
  echo "     --noparallel                  Disable running make with parallel jobs (make -j)"
  echo "     --version=VERSION             LDNS version to build (defaults to ${DEFAULTVERSION})"
  echo
  echo "For custom cURL options, set variable CURL_OPTIONS"
  echo "  Example: CURL_OPTIONS=\"--proxy 192.168.1.1:8080\" ./build-ldns.sh"
}

extra_argument() {
  local ARG=$1
  case ${ARG} in
    --noparallel)
      PARALLEL="false"
      ;;
    --version=*)
      VERSION="${i#*=}"
      shift
      ;;
    *)
      echo "Unknown argument: ${i}"
      ;;
  esac
}

did_process_arguments() {
  if [ -z "${VERSION}" ]; then
    VERSION="${DEFAULTVERSION}"
  fi

  # Determine number of cores for (parallel) build
  BUILD_THREADS=1
  if [ "${PARALLEL}" != "false" ]; then
    BUILD_THREADS=$(sysctl hw.ncpu | awk '{print $2}')
  fi
}

cleanup_build()
{
  # Clean up target directories if requested and present
  if [ -d "${CURRENTPATH}/build/bin" ]; then
    rm -rfd "${CURRENTPATH}/build/bin"
  fi
  if [ -d "${CURRENTPATH}/build/include/ldns" ]; then
    rm -rfd "${CURRENTPATH}/build/include/ldns"
  fi
  if [ -d "${CURRENTPATH}/build/lib" ]; then
    rm -rfd "${CURRENTPATH}/build/lib"
  fi
  if [ -d "${CURRENTPATH}/build/src" ]; then
    rm -rfd "${CURRENTPATH}/build/src"
  fi
  if [ -d "${CURRENTPATH}/build/frameworks" ]; then
    rm -rfd "${CURRENTPATH}/build/frameworks"
  fi
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

  LDNSCONF_SUFFIX="${PLATFORM}_${ARCH}"

  # Copy common.h to bin directory and add to array
  LDNSCONF="common_${LDNSCONF_SUFFIX}.h"
  cp "${TARGETDIR}/include/ldns/common.h" "${CURRENTPATH}/build/bin/${LDNSCONF}"
  LDNSCONF_ALL+=("${LDNSCONF}")

  # Keep reference to first build target for include file
  if [ -z "${INCLUDE_DIR}" ]; then
    INCLUDE_DIR="${TARGETDIR}/include/ldns"
  fi
}

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

source "${CURRENTPATH}/apple-config.sh"

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

# (Re-)create target directories
mkdir -p "${CURRENTPATH}/build/bin"
mkdir -p "${CURRENTPATH}/build/lib"
mkdir -p "${CURRENTPATH}/build/src"

# Init vars for library references
INCLUDE_DIR=""
LDNSCONF_ALL=()

bootstrap

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
    define_condition ${LDNSCONF_CURRENT}

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
