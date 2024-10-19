#!/bin/sh

BOOT_PARTITION="1"
OS_PARTITION="2"

distro_deps=("dd" "xzcat")

write_image() {
    set -e
    xzcat "${1}" | dd of="${2}" status=progress bs=1M
}

custom_config() {
    bootpart="${1}"
    ospart="${2}"
    shift 2
    toml_path="${bootpart}/custom.toml"

    cat > "${toml_path}" <<EOF
config_version = 1
[system]
hostname = "${hostname}"
[user]
name = "${USERNAME}"
password = "${USERPASS}"
password_encrypted = false
[ssh]
enabled = true
password_authentication = true
autorized_keys = ["$(cat "${ssh_key}")"]
[wlan]
ssid="${wifi_ssid}"
password="${wifi_password}"
password_encrypted = false
hidden=${wifi_hidden:-"false"}
country = ""
[locale]
# keymap="${keymap}"
keymap="us"
timezone = "${timezone}"
EOF

    # enable ssh
    log_debug "Creating: ${bootpart}/ssh"
    touch "${bootpart}/ssh"
    # Add user
    if ! is_null "${USERNAME}"
    then
        log_debug "Creating: ${bootpart}/userconf.txt"
        echo "${USERNAME}:$(openssl passwd -6 -stdin <<<"${USERPASS}")" > "${bootpart}/userconf.txt"
    fi
}

