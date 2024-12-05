#!/bin/sh

BOOT_PARTITION="1"
OS_PARTITION="2"

distro_deps=("dd" "xzcat")

write_image() {
    set -e
    xzcat "${1}" | dd of="${2}" status=progress bs=1M
}

is_customizable() {
    # UFS file systems are often read-only under Linux
    false
}

custom_config() {
    log_error "FreeBSD pre-boot configuration is not supported."
    exit 1
}
