# Headless deployment of Raspberry Pi devices

The `deploy_raspbery.sh` script eases the creation of SD card images using [Fedora IoT](https://fedoraproject.org/iot) and [Raspberry Pi OS](https://www.raspberrypi.com/software/) for devices like the Raspberry Pi.

The script will download a pre-built image, write it to an SD card, and configure the hostname, the keymap, and the Ethernet and WiFi interfaces. The root password will be disabled and a SSH key will be added to provide SSH access to the device.

## Customizing configuration

The configuration is done through a YAML file:

```yaml
hostname: "myhost"
domain: "mydomain.local"
timezone: "Etc/UTC"
ssh-key: "ssh_keys/mysshkey.pub"
keymap: "us-dvorak-alt-intl"
user:
  username: "defaultuser"
  password: "clearpassword"
network:
  wifi:
    ssid: "MyNetwork"
    password: "MyVerySecretPassword"
    hidden: false
target:
  rpi1:
    gpu_mem: 16
```

All configuration is optional. Currently, NetBSD cannot be customized.


### Keymap configuration

Keymap configuration only works for Fedora. By default the keymap used is "us".


### Access configuration

There are two ways to configure access to the device, by adding a user with `sudo` powers, or by allowing `root` login through a SSH key.

Adding a user requires a username and a password, in clear text. By default, the user is `pi` and the password is `raspberry`. This is only used for Raspberry Pi OS.

Setting up a SSH key for root access only works with Fedora. If you don't set the ssh key, you'll not be able to access the device.

To genetare the SSH key, you can use: 

```bash
ssh-keygen -te ed25519 -a 100 -f ssh_keys/mysshkey -N "MyPassphrase"
```

A passphrase is optional, see `ssh-keygen` documentation.


## Overriding config.txt options

It is possible to override any setting for the board type using the proper `target` configuration.

Any variable set under a target board will be added to the `config.txt` file, in the boot partition, as:

```ini
[<target>]
variable = value
```

For example, to reduce the GPU memory and slightly overclock a Raspberry Pi 1 device use:

```yaml
target:
  rpi1:
    gpu_mem: 16
    arm_freq: 800
```


## Writing the image

To write the SD Card use:

```
sudo ./deploy_raspberry.sh <system> <target> <device>
```

Currently available systems and targets:
* Fedora IoT (_fedora_)
    * rpi4
* Raspberry Pi OS (_raspios_):
    * rpi1
    * rpi4a (untested)
* NetBSD (_netbsd_):
    * rpi1 (NetBSD 9.x)
    * rpi4 (NetBSD 10.x - untested)
    * `Note`: only partial support is provided for `netbsd`. To finish the installation you'll still need a monitor and a keyboard attached to the Raspberry Pi device to setup the `root` password and, at least, install a Python version (e.g. `# pkg_add python3.11`) if you plan to use [Ansible](https://ansible.com) to automate the configuration.


Superuser privileges are usually needed to write to the SD card device.

Optionally, the hostname and domain can be set though argumenst. Use `-n <hostname>[.<domain>]` (domain is optional).

It is also possible to set the framebuffer rotation with the `-r` option where the rotation is defined as:
* 0 = no rotation
* 1 = rotate right
* 2 = rotate 180 degrees
* 3 = rotate left


## Speeding things up

Downloading the image and writing to the card is what really consumes time here, if you have more than a single card to prepare, the image downloaded is kept in a chache directory speeding things up. As the changes are applied directly to the SD card, the original image is kept as downloaded.

Choose your SD cards wisely, some are really slow to write to (as in ~5MB/s rate or less), and may take up to 15 minutes to prepare.


## Dependencies

You'll need [shyaml](https://github.com/0k/shyaml), `envsubst` (which usually is part of `gettext-envsubst` package) and `dd`(which is usually avaiable, as is part of `coreutils`). Als for each system to be deployed you'll need:
* fedora: [arm-image-installer](https://pagure.io/arm-image-installer), `uuid`
* raspios: [xzcat](https://github.com/tukaani-project/xz)
* netbsd: [zcat](https://www.gnu.org/software/gzip)


## First boot configuration

Upon first boot a lot of stuff will happen on your Raspberry Pi and you should give it some minutes (as much as 20 minutes depending on board, card, system, configuration and network) to finish the configuration.

## License

This script is distributed under the very permissive BSD Zero Clause Licene. See [LICENSE](LICENSE).

Use at your own (very low) risk.

## Author

Rafael Jeffman <rafasgj@gmail.com>
