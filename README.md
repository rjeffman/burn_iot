# Headles deployment of Raspberry Pi devices

The `deploy_raspbery.sh` script eases the creation of SD card images using [Fedora IoT](https://fedoraproject.org/iot) and [Raspberry Pi OS](https://www.raspberrypi.com/software/) for devices like the Raspberry Pi.

The script will download the Fedora IoT image, write it to an SD card, and configure the hostname, the keymap, and the Ethernet and WiFi interfaces. The root password will be disabled and a SSH key will be added to provide SSH access to the device.

The configuration is done through a YAML file:

```yaml
hostname: "myhost"
domain: "mydomain.local"
timezone: "Etc/UTC"
ssh-key: "mysshkey.pub"
user:
  username: "defaultuser"
  password: "clearpassword"
network:
  wifi:
    ssid: "MyNetwork"
    password: "MyVerySecretPassword"
    hidden: false
```

Some notes about the configuration:

* Tilde expansion (`~`) does'nt work, use `/home/<myuser>` to refer to the user $HOME directory
* By default the keymap used is _us_. This configuration only works for Fedora.
* The user configures an initial user with _sudoer_ powers. It only works on Ubuntu.
    * On Fedora, root user is enabled through `ssh_key` authentication, and no other user is created.
* If the `wifi` network is not defined, it will not be configured

To genetare the SSH key, you can use:

```bash
ssh-keygen -te ed25519 -a 100 -f mysshkey -N "MyPassphase"
```

To write the SD Card use:

```
sudo ./deploy_raspberry.sh <distro> <target> <device>
```

Currently available distros are `fedora` and `raspios`.

Targets tested are `rpi1` (Model 1 B+) and `rpi 4` (tested with 4Gb and 8Gb models).

Superuser privileges are usually needed to write to the device.

Optionally, the hostname and domain can be set though argumenst. Use `-n <hostname>[.<domain>]` (domain is optional). If using a Raspberry Pi Dispaly on the DSI connector, add the option `-d` to generate the proper configuration.

## Speeding things up

Downloading the image and writing to the card is what really consumes time here, if you have more than a single card to prepare, the image downloaded is kept in the working directory, and is used as cache, speeding things up. As the changes are applied directly to the SD card, the original image is kept as downloaded.

Choose your SD cards wisely, some are really slow to write to (as in ~5MB/s rate or less), and may take up to 15 minutes to prepare.


## Dependencies

You'll need [shyaml](https://github.com/0k/shyaml) and [arm-image-installer](https://pagure.io/arm-image-installer) to use the script.


## First boot configuration

Upon first boot a lot of stuff will happen on your Raspberry Pi and you should give it some minutes (as much as 20 minutes depending on board, card, configuration and network) to finish the configuration.

## License

This script is distributed under the very permissive BSD Zero Clause Licene. See [LICENSE](LICENSE).

Use at your own (very low) risk.

## Author

Rafael Jeffman <rafasgj@gmail.com>
