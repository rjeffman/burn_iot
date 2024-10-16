#!/bin/bash

SCRIPTDIR="$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")"
LIBDIR="${SCRIPTDIR}/lib"
CONFDIR="${SCRIPTDIR}/conf"
TEMPLATEDIR="${SCRIPTDIR}/templates"
export TEMPLATEDIR
. "${LIBDIR}/shfun"

prog=$(basename "$0")

usage() {
    echo "usage: ${prog} [-d] [-h HOSTNAME]  DISTRO TARGET SD_DEVICE [CONFIG]"
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
    log_info "Sync data"
    sync
    log_info "Unmounting partition"
    umount "${1}"
}

#
# Process CLI options
#
display=""
hostname=""
domain=""

while getopts ":dn:" opt "${@}"
do
    case "${opt}" in
        d) display="video=DSI-1:800x480@60,rotate=180" ;;
        n)
            hostname="$(cut -d. -f1 <<<"${OPTARG}")"
            domain="$(cut -d. -f2- <<<"${OPTARG}")"
        ;;
        *) die -u "Invalid option: ${OPTARG}"
    esac
done

shift $((OPTIND - 1))

# validate input
[ $# -lt 3 ] && die -u "Missing mandatory options."

#
# Positional arguments
#
distro="${1}"
target="${2}"
SD_DEVICE="$(readlink -f "${3}")"
shift 3
[ -n "${1}" ] && CONFIG="$(realpath "${1}")" && shift

test -f "${LIBDIR}/${distro}.sh" || die "Invalid distro: ${distro}"
test -b "${SD_DEVICE}" || die "Invalid block device: ${SD_DEVICE}"

log_debug "Distro: ${distro}"
log_debug "Target: ${target}"
log_debug "Media device: ${SD_DEVICE}"

export distro target SD_DEVICE

#
# Check script dependencies
#
log_info "Checking dependencies"
check_deps envsubst tr mount openssl shyaml
check_deps "${distro_deps[@]:-""}"

# load distro specific scripts
log_info "Loading ${distro} scripts"
. "${LIBDIR}/${distro}.sh"

#
# Global configuration
#
log_info "Parsing global configuration"
configdata="$(get_conf "config.target" < "${CONFDIR}/distros.yaml")"
declare -A "config=()"
if ! is_null "${configdata}"
then
    targetconfig=( $(shyaml key-values "target.${target}" <<< "${configdata}" 2>/dev/null) )
    if ! is_null "${targetconfigu}"
    then
        declare -A "config=( $(echo ${targetconfig[@]} \
            | sed 's/[ ]*\([^ ]*\)[ ]*\([^ ]*\)/[\1]=\2 /g') )"
    fi
    export config
fi

#
# Distro release
#
log_info "Parsing distro release"
distroconf="$(get_conf "distro.${distro}" < "${CONFDIR}/distros.yaml")"
is_null "${distroconf}" && die "No configuration for distro ${distro}"

url="$(get_conf "url" <<<"${distroconf}")"
is_null "${url}" && die "Could not parse download URL for ${distro}."

releaseconf=( $(shyaml key-values "target.${target}" <<< "${distroconf}") )
is_null "${releaseconf}" && die "${distro} has no release data for target ${target}"
declare -A "releasedata=( $(echo ${releaseconf[@]} | sed 's/[ ]*\([^ ]*\)[ ]*\([^ ]*\)/[\1]=\2 /g') )"
for key in "${!releasedata[@]}"
do
    export ${key}="${releasedata[${key}]}"
done
# Raspbian OS has an awful download link.
IMGRELEASE=""
if ! is_null "${release}" && [ "${distro}" == "raspios" ]
then
    IMGRELEASE="-${release}"
    release="${release}_"
    export release
fi
export IMGRELEASE

#
# Defaults
#
USERNAME="pi"
USERPASS="raspberry"

#
# User configuration
#
if [ -f "${CONFIG}" ]
then
    ssh_key="$(get_conf "ssh-key" < "${CONFIG}")"
    is_null "${hostname}" && hostname="$(get_conf "hostname" "raspberry" < "${CONFIG}")"
    is_null "${domain}" && domain="$(get_conf "domain" < "${CONFIG}")"
    is_null "${domain}" || hostname="${hostname}.${domain}"
    # Locale configuration
    keymap="$(get_conf "keymap" < "${CONFIG}")"
    timezone="$(get_conf "timezone" "Etc/UTC" < "${CONFIG}")"
    # WiFi configuration
    wificonf="$(get_conf "network.wifi" < "${CONFIG}")"
    if [ "${wificonf}" != "null" ]
    then
        wifi_ssid="$(get_conf "ssid" <<<"${wificonf}")"
        wifi_password="$(get_conf "password" <<<"${wificonf}")"
        export wifi_ssid wifi_password
    fi
    # User configuration
    userconf="$(get_conf "user" < "${CONFIG}")"
    if ! is_null "${userconf}"
    then
        USERNAME="$(get_conf "username" <<<"${userconf}")"
        USERPASS="$(get_conf "password" <<<"${userconf}")"
        export USERNAME USERPASS
    fi

fi

log_info "Configuration:"
log_info "Release: $arch $version $date $release"
is_null "${hostname}" || log_debug "Hostname: ${hostname}"
is_null "${USERNAME}" || log_debug "Username: ${USERNAME}"
is_null "${USERPASS}" || log_debug "Password: ${USERPASS}"
is_null "${ssh_key}" || log_debug "SSH Key file: ${ssh_key}"
if ! is_null "${wifi_ssid}"
then
    log_debug "SSID: ${wifi_ssid}"
    log_debug "Password: ${wifi_password}"
    log_debug "Hidden: ${wifi_hidden:-"false"}"
fi
is_null "${keymap}" || log_debug "Username: ${keymap}"
is_null "${timezone}" || log_debug "Username: ${timezone}"

# download image
url="$(envsubst <<<"${url}")"
log_debug "Download link: ${url}"
log_info "Downloading image: ${distro} version ${version} for ${target}"
quiet mkdir -p "${SCRIPTDIR}/images"
IMAGEFILE="${SCRIPTDIR}/images/$(basename "${url}")"
curl -C - -L -o "${IMAGEFILE}" "${url}" \
    || die "Failed to Dowload image."

# write image to SDCARD
log_info "Writing image"
write_image "${IMAGEFILE}" "${SD_DEVICE}" "${ssh_key}" "${target}" \
    || die "Failed to write image ${1}"

# Partition mount points
bootpart="$(readlink -f $(mktemp -d))"
ospart="$(readlink -f $(mktemp -d))"

log_info "Mounting boot partition: ${bootpart}"
mount "${SD_DEVICE}${BOOT_PARTITION}" "${bootpart}" || die "Could not mount boot partition"

log_info "Mounting OS partition: ${ospart}"
mount "${SD_DEVICE}${OS_PARTITION}" "${ospart}" || die "Could not mount OS partition"

# Configure image
custom_config "${bootpart}" "${ospart}"

# Clean up
unmount_partition "${bootpart}"
unmount_partition "${ospart}"

rm -rf "${bootpart}" "${ospart}"

log_info "Image configured and saved to ${SD_DEVICE}."
