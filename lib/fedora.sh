#!/bin/sh

BOOT_PARTITION="1"
OS_PARTITION="3"

distro_deps=("arm-image-installer")

write_image() {
    # write image to SDCARD
    arm-image-installer -y \
       --image="${1}" \
       --media="${2}" \
       --addkey="${3}" \
       --norootpass \
       --resizefs \
       --target="${4}" 
}

get_deployroot() {
    dirname "$(realpath "$(find "${1}/ostree/deploy/fedora-iot/" -name "etc" ! -path "*/usr/*")")"
}

copy_template() {
    src="${1}"
    dest="${2}"
    mode="${3-"0644"}"
    envsubst < "${src}" > "${dest}"
    chmod 0644 "${dest}"
}

is_customizable() {
    true
}

custom_config() {
    bootpart="${1}"
    ospart="${2}"
    shift 2
    deployroot="$(get_deployroot "${ospart}")"
    # Enable SSH
    log_info "Enable SSH"
    touch "${bootpart}/ssh"
    # Set hostname
    log_info "Configuring hostname to '$hostname'"
    echo "${hostname}" > "${deployroot}/etc/hostname"
    # Keymap
    if ! is_null "${keymap}"
    then
        log_info "Configuring keymap to '$keymap'."
        echo "KEYMAP=${keymap:-"us"}" > "${deployroot}/etc/vconsole.conf"
    fi
    # Configure WiFi
    system_connections="etc/NetworkManager/system-connections"
    if [ -n "${wifi_ssid}" ]
    then
        log_info "Configuring WiFi..."
        dest="${deployroot}/${system_connections}/wifi01.nmconnection"
        copy_template "${TEMPLATEDIR}/wifi01.nmconnection" "${dest}"
    fi
    # Configure eth
    log_info "Configuring eth..."
    dest="${deployroot}/${system_connections}/eth01.nmconnection"
    copy_template "${TEMPLATEDIR}/eth01.nmconnection" "${dest}"
}
