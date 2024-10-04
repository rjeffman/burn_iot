#!/bin/bash

prog=$(basename "$0")

die() {
    echo "usage: ${prog} CONFIG SD_DEVICE"
    echo "$*"
    exit 1
}

get_conf()
{
    shyaml get-value "${1}" "${2:-"null"}"
}

get_count()
{
    shyaml get-length "${1}" || echo -n "0"
}

command -v shyaml 2>/dev/null >/dev/null || die "shyaml not found."

[ $# -ne 2 ] && die "Must provide CONFIG and SD_DEVICE"

CONF="$(realpath "${1}")"
SD_DEVICE="$(realpath "${2}")"
shift 2

# Defaults
ARCH="aarch64"
VERSION="40"
DATE="20240422"
RELEASE="3"
TARGET="rpi4"

SSH_KEY="$(get_conf "ssh-key" < "${CONF}")"

distroconf="$(get_conf "distro" < "${CONF}")"
if [ "${distroconf}" != "null" ]
then
    ARCH="$(get_conf "arch" "${ARCH}" <<<"${distroconf}")"
    TARGET="$(get_conf "target" "${TARGET}" <<<"${distroconf}")"
    VERSION="$(get_conf "version" "${VERSION}" <<<"${distroconf}")"
    DATE="$(get_conf "date" "${DATE}" <<<"${distroconf}")"
    RELEASE="$(get_conf "release" "${RELEASE}" <<<"${distroconf}")"
fi

hostconf="$(get_conf "host" < "${CONF}")"
if [ "${hostconf}" != "null" ]
then
    ARCH="$(get_conf "arch" "${ARCH}" <<<"${hostconf}")"
    TARGET="$(get_conf "target" "${TARGET}" <<<"${hostconf}")"
    hostname="$(get_conf "hostname" <<<"${hostconf}")"
    keymap="$(get_conf "keymap" "us" <<<"${hostconf}")"
    wificonf="$(get_conf "network.wifi" <<<"${hostconf}")"
    if [ "${wificonf}" != "null" ]
    then
        wifi_ssid="$(get_conf "ssid" <<<"${wificonf}")"
        wifi_password="$(get_conf "password" <<<"${wificonf}")"
        export wifi_ssid wifi_password
    fi
fi 

if [ "${TARGET}" == "rpi4" ]
then
    command -v arm-image-installer 2>/dev/null >/dev/null || die "arm-image-installer not found."
fi


IMAGE="Fedora-IoT-raw-${VERSION}-${DATE}.${RELEASE}.${ARCH}.raw.xz"
IOT_URL="https://download.fedoraproject.org/pub/alt/iot"

# download image
echo "Downloading image: ${IMAGE} version ${VERSION} for ${ARCH}"
curl -C - -LO "${IOT_URL}/${VERSION}/IoT/${ARCH}/images/${IMAGE}" || die "Failed to download image."

# write image to SDCARD
echo "Writing image..."
arm-image-installer -y \
   --image="${IMAGE}" \
   --media="${SD_DEVICE}" \
   --addkey="${SSH_KEY}" \
   --norootpass \
   --resizefs \
   --target="${TARGET}" || die "Failed to write image ${IMAGE} to SD card."

echo "Mounting image..."
tmpdir="$(mktemp -d)"
mkdir -p "${tmpdir}"
mount "${SD_DEVICE}3" "${tmpdir}" || die "Could not mount image."

#
# Get deploy root
#
deployroot="$(dirname "$(realpath "$(find "${tmpdir}/ostree/deploy/fedora-iot/" -name "etc" ! -path "*/usr/*")")")"

#
# Hostname
#
if [ -n "${hostname}" ]
then
    echo "Configuring hostname to '$hostname'."
    echo "${hostname}" > "${deployroot}/etc/hostname"
fi

#
# Keymap
#
echo "Configuring keymap to '$keymap'."
echo "KEYMAP=${keymap:-"us"}" > "${deployroot}/etc/vconsole.conf"

#
# Configure WiFi
#
system_connections="etc/NetworkManager/system-connections"
if [ -n "${wifi_ssid}" ]
then
    echo "Configuring WiFi..."
    dest="${deployroot}/${system_connections}/wifi01.nmconnection"
    envsubst < files/wifi01.nmconnection > "${dest}"
    chmod 0600 "${dest}"
fi

#
# Configure eth
#
echo "Configuring eth..."
dest="${deployroot}/${system_connections}/eth01.nmconnection"
cp files/eth01.nmconnection "${dest}"
chmod 0644 "${dest}"

#
# Clean up
#
echo "Sync-ing data..."
sync
umount "${tmpdir}"
rm -rf "${tmpdir}"


echo "Image saved to ${SD_DEVICE}."
