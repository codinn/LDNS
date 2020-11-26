/*
 * Building LDNS for the different architectures of all iOS and tvOS devices requires different settings.
 * In order to be able to use assembly code on all devices, the choice was made to keep optimal settings for all
 * devices and use this intermediate header file to use the proper common.h file for each architecture.

 * Based on work of [openssl-apple](https://github.com/keeshux/openssl-apple)
 */

#include <TargetConditionals.h>

