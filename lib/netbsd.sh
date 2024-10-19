#!/bin/sh

BOOT_PARTITION="1"
OS_PARTITION="2"

distro_deps=("dd" "zcat")

write_image() {
    set -e
    zcat "${1}" | dd of="${2}" status=progress bs=1M
}

is_customizable() {
    false
}

custom_config() {
    log_error "NetBSD pre-boot configuration is not supported."
    exit 1
}
