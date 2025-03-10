#!/bin/sh

BOOT_PARTITION="1"
OS_PARTITION="2"

distro_deps=("dd" "xzcat")

write_image() {
    set -e
    xzcat "${1}" | dd of="${2}" status=progress bs=1M
}

is_customizable() {
    true
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
password_authentication = false
authorized_keys = ["$(cat "${ssh_key}")"]
[wlan]
ssid="${wifi_ssid}"
password = "${wifi_password}"
password_encrypted = false
hidden = ${wifi_hidden:-"false"}
country = "${wifi_country:-"BR"}"
[locale]
# keymap is not working as expected
# keymap = "${keymap:-us}"
timezone = "${timezone}"
EOF

    # add ssh-key to root user
    mkdir -p "${ospart}/root/.ssh"
    cat "${ssh_key}" > "${ospart}/root/.ssh/authorized_keys"
    chown -R 0:0 "${ospart}/root/.ssh"
    chmod 0600 "${ospart}/root/.ssh/authorized_keys"

    # configure keyboard
    if [ -n "${keymap}" ]
    then
        kbdlayout="$(cut -d- -f1 <<<"${keymap}")"
        kbdvariant="$(cut -d- -f2- <<<"${keymap}")"
        export kbdlayout kbdvariant
        copy_template "${TEMPLATEDIR}/keyboard" "${ospart}/etc/default/keyboard"
    fi
}

