#!/bin/bash

SCRIPTDIR="$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")"
LIBDIR="${SCRIPTDIR}/lib"
CONFDIR="${SCRIPTDIR}/conf"
TEMPLATEDIR="${SCRIPTDIR}/templates"
export TEMPLATEDIR
. "${LIBDIR}/shfun"

trap unmount_partitions EXIT

unmount_partitions() {
    trap - EXIT
    unmount_partition "${bootpart}"
    unmount_partition "${ospart}"
}

prog=$(basename "$0")

usage() {
    echo "usage: ${prog} [-h] [-r ROTATE] [-n HOSTNAME] [-s SSID] [-d DEVICE] [-o DISTRO]  TARGET CONFIG"
}

get_conf()
{
    shyaml get-value "${1}" "${2:-"null"}"
}

get_count()
{
    shyaml get-length "${1}" || echo -n "0"
}

is_null() {
    [ -z "${1}" ] || [ "${1}" == "null" ]
}

unmount_partition() {
    if grep -q " ${1} " <(mount)
    then
        log_info "Sync data"
        sync
        log_info "Unmounting partition"
        umount "${1}"
    fi
}

copy_template() {
    log_debug "copy template: [${1}] [${2}]"
    envsubst < "${1}" > "${2}"
}

append_template() {
    log_debug "append template: [${1}] [${2}]"
    envsubst < "${1}" >> "${2}"
}

pre_boot_customization() {
    log_info "Customizing OS pre-boot"

    # Partition mount points
    bootpart="$(readlink -f $(mktemp -d))"
    ospart="$(readlink -f $(mktemp -d))"

    log_info "Mounting boot partition: ${bootpart}"
    mount "${SD_DEVICE}${BOOT_PARTITION}" "${bootpart}" || die "Could not mount boot partition"

    log_info "Mounting OS partition: ${ospart}"
    mount "${SD_DEVICE}${OS_PARTITION}" "${ospart}" || die "Could not mount OS partition"

    # Configure image
    custom_config "${bootpart}" "${ospart}"

    #
    # Configure config.txt
    #
    config_path="${bootpart}/config.txt"
    log_debug "Path to config.txt: ${config_path}"
    # Update config.txt with changes for all versions
    if [ -f "${TEMPLATEDIR}/all.txt" ]
    then
        log_debug "Adding configuration for [all] in config.txt"
        append_template "${TEMPLATEDIR}/all.txt" "${config_path}" \
            d|| die "Could not modify 'config.txt'."
    fi

    # Update config.txt with target changes
    if [ -f "${TEMPLATEDIR}/${target}.txt" ]
    then
        log_debug "Adding configuration for [${target}] in config.txt"
        append_template "${TEMPLATEDIR}/${target}.txt" "${config_path}" \
            || die "Could not modify 'config.txt'."
    fi
    # Add display entry to cmdline
    if ! is_null "${rotate}"
    then
        log_debug "Modifying cmdline.txt to properly rotate DSI monitor"
        cmdline="${rotate} $(cat "${bootpart}/cmdline.txt")"
        log_debug "Setting cmdline.txt to: ${cmdline}"
        sed "s/^ *//" <<<"${cmdline}" > "${bootpart}/cmdline.txt"
    fi

    # Clean up
    unmount_partitions

    rm -rf "${bootpart}" "${ospart}"
}

update_config() {
    newconfig="$(cat -)"
    shift 1
    if ! is_null "${newconfig}"
    then
        for key in $(shyaml keys <<<"${newconfig}")
        do
            if is_null "${!key}"
            then
                value="$(shyaml get-value "${key}" <<<"${newconfig}")"
                export ${key}="${value}"
            fi
        done
    fi
}

#
# Process CLI options
#
rotate=""
hostname=""
domain=""

while getopts ":hd:n:o:r:s:" opt "${@}"
do
    case "${opt}" in
        h) usage && exit 0 ;;
        d) SD_DEVICE="${OPTARG}" ;;
        n)
            hostname="$(cut -d. -f1 <<<"${OPTARG}")"
            [ "${hostname}" != "${OPTARG}" ] && domain="$(cut -d. -f2- <<<"${OPTARG}")"
        ;;
        o) distro="${OPTARG}" ;;
        r) rotate="fbcon=rotate:${OPTARG}" ;;
        s) wifi_ssid="${OPTARG}" ;;
        *) die -u "Invalid option: ${OPTARG}"
    esac
done

shift $((OPTIND - 1))

# validate input
[ $# -lt 2 ] && die -u "Missing mandatory options."
[ $# -ne 2 ] && die -u "Only TARGET and CONFIG must be provided."

#
# Positional arguments
#
target="${1}"
CONFIG="$(realpath "${2}")"
shift 2

#
# Check script dependencies
#
log_info "Checking dependencies"
check_deps envsubst tr mount openssl shyaml
check_deps "${distro_deps[@]:-""}"

#
# Defaults
#
USERNAME="pi"
USERPASS="raspberry"

#
# User configuration
#
echo "Confifguration file: ${CONFIG}"

if [ -f "${CONFIG}" ]
then
    configdata="$(cat "${CONFIG}")"
    # instalation parameters
    is_null "${distro}" && distro="$(get_conf "distro" <<< "${configdata}" 2>/dev/null)"
    is_null "${SD_DEVICE}" && SD_DEVICE="$(get_conf "device" <<< "${configdata}" 2>/dev/null)"

    ssh_key="$(get_conf "ssh-key" <<< "${configdata}")"
    is_null "${hostname}" && hostname="$(get_conf "hostname" "raspberry" <<< "${configdata}")"
    domain="$(get_conf "domain" <<< "${configdata}")"
    is_null "${domain}" && hostname="${hostname}.${domain}"
    # Locale configuration
    keymap="$(get_conf "keymap" <<< "${configdata}")"
    timezone="$(get_conf "timezone" "Etc/UTC" <<< "${configdata}")"
    # WiFi configuration
    wificonf="$(get_conf "network.wifi" <<< "${configdata}")"
    if ! is_null "${wificonf}"
    then
        is_null "${wifi_ssid}" && wifi_ssid="$(get_conf "ssid" <<<"${wificonf}")"
        wifi_password="$(get_conf "password" <<<"${wificonf}")"
        wifi_country="$(get_conf "country" "BR" <<<"${wificonf}")"
    fi
    # User configuration
    userconf="$(get_conf "user" <<< "${configdata}")"
    if ! is_null "${userconf}"
    then
        USERNAME="$(get_conf "username" <<<"${userconf}")"
        USERPASS="$(get_conf "password" <<<"${userconf}")"
        export USERNAME USERPASS
    fi
    # Set current configuration
    update_config <<<$(get_conf "target.${target}" <"${CONFIG}" 2>/dev/null)
fi

#
# Global configuration
#
[ -f "${CONFDIR}/${target}.yaml" ] && update_config < "${CONFDIR}/${target}.yaml"
log_info "Parsing global configuration"
configdata="$(get_conf "config" < "${CONFDIR}/distros.yaml")"
is_null "${configdata}" \
  || update_config <<<"$(get_conf "target.${target}" <<< "${configdata}" 2>/dev/null)"

# check parameters
is_null "${distro}" && die -u "Distro not defined."
is_null "${SD_DEVICE}" && die -u "SD device not defined."
test -f "${LIBDIR}/${distro}.sh" || die "Invalid distro: ${distro}"
test -b "${SD_DEVICE}" || die "Invalid block device: ${SD_DEVICE}"

export distro target SD_DEVICE

# load distro specific scripts
log_info "Loading ${distro} scripts"
. "${LIBDIR}/${distro}.sh"

#
# Distro release
#
log_info "Parsing distro release"
distroconf="$(get_conf "distro.${distro}" < "${CONFDIR}/distros.yaml")"
is_null "${distroconf}" && die "No configuration for distro ${distro}"

url="$(get_conf "url" <<<"${distroconf}")"
is_null "${url}" && die "Could not parse download URL for ${distro}."

releaseconf=$(get_conf "target.${target}" <<< "${distroconf}")
is_null "${releaseconf}" && die "${distro} has no release data for target ${target}"
update_config <<<"${releaseconf}"


is_null "${wifi_ssid}" || export wifi_ssid wifi_password wifi_country

# Raspbian OS has an awful download link.
IMGRELEASE=""
if ! is_null "${release}" && [ "${distro}" == "raspios" ]
then
    IMGRELEASE="-${release}"
    release="${release}_"
    export release
fi
export IMGRELEASE

log_info "Configuration:"

log_info "Distro: ${distro}"
log_info "Target: ${target}"
log_info "Media device: ${SD_DEVICE}"

log_info "Release: $arch $version $date $release"
is_null "${hostname}" || log_debug "Hostname: ${hostname}"
is_null "${USERNAME}" || log_debug "Username: ${USERNAME}"
is_null "${USERPASS}" || log_debug "Password: ${USERPASS}"
is_null "${ssh_key}" || log_debug "SSH Key file: ${ssh_key}"
if ! is_null "${wifi_ssid}"
then
    log_info "SSID: ${wifi_ssid}"
    log_info "Password: ${wifi_password}"
    log_info "Country: ${wifi_country:-"BR"}"
    log_info "Hidden: ${wifi_hidden:-"false"}"
fi
is_null "${keymap}" || log_debug "Keymap: ${keymap}"
is_null "${timezone}" || log_debug "Timezone: ${timezone}"

# download image
url="$(envsubst <<<"${url}")"
log_debug "Download link: ${url}"
log_info "Downloading image: ${distro} version ${version} for ${target}"

quiet mkdir -m 0777 -p "${SCRIPTDIR}/images"
IMAGEFILE="${SCRIPTDIR}/images/$(basename "${url}")"
curl --create-file-mode 0666 -C - -L -o "${IMAGEFILE}" "${url}" \
    || die "Failed to Dowload image."


# write image to SDCARD
log_info "Writing image"
write_image "${IMAGEFILE}" "${SD_DEVICE}" "${ssh_key}" "${target}" \
    || die "Failed to write image ${1}"

if is_customizable
then
    pre_boot_customization
else
    log_info "${distro} is not customizable."
fi

log_info "Image configured and saved to ${SD_DEVICE}."
