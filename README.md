# Create a Raspberry Pi image using Fedora IoT

The `burn_iot_image.sh` script eases the creation of SD card images using [Fedora IoT](https://fedoraproject.org/iot) for devices like the Raspberry Pi.

The script will download the Fedora IoT image, write it to an SD card, and configure the hostname, the keymap, and the Ethernet and WiFi interfaces. The root password will be disabled and a SSH key will be added to provide SSH access to the device.

The configuration is done through a YAML file:

```yaml
ssh-key: "mysshkey.pub"
distro:
  arch: "aarch64"
  target: "rpi4"
  version: "40"
  date: "20240422"
  release: "3"
host:
  keymap: "us-intl"
  hostname: "myhost.example.net"
  network:
    wifi:
      ssid: "MyNetwork"
      password: "MyVerySecretPassword"
```

Some notes about the configuration:

* Tilde expansion (`~`) does'nt work, use `/home/<myuser>` to refer to the user $HOME directory
* By default the keymap used is _us_
* If the `wifi` network is not defined, it will not be configured
* The ethernet interface is always configured for automatic discovery

To genetare the SSH key, you can use:

```bash
ssh-keygen -te ed25519 -a 100 -f mysshkey -N "MyPassphase"
```

To write the SD Card use:

```
sudo ./burn_iot_image.sh myhost.yaml /dev/sda
```

Superuser privileges are usually needed to write directly to the card.


## Speeding things up

Downloading the image and writing to the card is what really consumes time here, if you have more than a single card to prepare, the image downloaded is kept in the working directory, and is used as cache, speeding things up. As the changes are applied directly to the SD card, the original image is kept as downloaded.

Choose your SD cards wisely, some are really slow to write to (as in ~5MB/s rate or less), and may take up to 15 minutes to prepare.


## Dependencies

You'll need [shyaml]() and [arm-image-installer]() to use the script.


## License

This script is distributed under the very permissive BSD Zero Clause Licene. See [LICENSE](LICENSE).

Use at your own (very low) risk.

## Author

Rafael Jeffman <rafasgj@gmail.com>
