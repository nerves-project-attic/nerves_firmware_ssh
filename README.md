# Nerves.Firmware.SSH

[![Hex version](https://img.shields.io/hexpm/v/nerves_firmware_ssh.svg "Hex version")](https://hex.pm/packages/nerves_firmware_ssh)

This project contains the necessary infrastruction to support "over-the-air"
firmware updates with Nerves by using
[ssh](https://en.wikipedia.org/wiki/Secure_Shell).

The default settings make it quick to integrate into Nerves projects for
development work. Later on, if your deployed devices can be reached by `ssh`,
it's even possible to use tools like Ansible or even shell scripts to update a
set of devices all at once.

## Installation

First, add `nerves_firmware_ssh` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:nerves_firmware_ssh, github: "fhunleth/nerves_firmware_ssh"}]
end
```

Next, update your `config/config.exs` with one or more authorized keys. These
come from files like your `~/.ssh/id_rsa.pub` or `~/.ssh/id_ecdsa.pub` that were
created when you created your `ssh` keys. If you haven't done this, the following
[article](https://help.github.com/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent/)
may be helpful. Here's an example:

```elixir
config :nerves_firmware_ssh,
  authorized_keys: [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgQDBCdMwNo0xOE86il0DB2Tq4RCv07XvnV7W1uQBlOOE0ZZVjxmTIOiu8XcSLy0mHj11qX5pQH3Th6Jmyqdj",
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCaf37TM8GfNKcoDjoewa6021zln4GvmOiXqW6SRpF61uNWZXurPte1u8frrJX1P/hGxCL7YN3cV6eZqRiF"
  ]
```

Here's another way that may work well for you that avoids needing to commit your keys:

```elixir
config :nerves_firmware_ssh,
  authorized_keys: [
    File.read!(Path.join(System.user_home!, ".ssh/id_rsa.pub"))
  ]
```

The first firmware bundle that you create after adding `nerves_firmware_ssh`
will need to be installed in a non-ssh way. The usual route is to burn a MicroSD
card for most targets, but you may have another way of getting the new image
onto the device.

## Pushing firmware updates to devices

The easiest way to push updates during development is to let `mix` do it for
you:

```
MIX_TARGET=rpi0 mix firmware.push nerves.local
```

Substitute `rpi0` above for your target and `nerves.local` for the IP address or
DNS name of the device that you want to update.

The `firmware.push` takes several arguments:

   * `--firmware` - The path to a fw file.
   * `--passphrase` - The passphrase on the SSH private key (if any)
   * `--port` - The TCP port number to use to connect to the target.
   * `--target` - The target string of the target configuration.
   * `--user-dir` - The path to where your id_rsa id_rsa.pub key files are located.

Run `mix help firmware.push` for more information.

## Manual invocation

The `mix firmware.push` method uses Erlang's ssh implementation which has
some limitations like not supporting password protected private keys. If this is
an issue or if you just want to use commandline ssh(1), here's how to do it:

```
FILENAME=myapp.fw
FILESIZE=$(stat -c%s "$FILENAME")
printf "fwup:$FILESIZE,reboot\n" | cat - $FILENAME | ssh -s -p 8989 target_ip_addr nerves_firmware_ssh
```

The
[upload.sh](https://github.com/fhunleth/nerves_firmware_ssh/blob/master/upload.sh)
script has a slightly nicer implementation of the above.

Also see the section on the `nerves_firmware_ssh` protocol and the ssh(1) man page
for more details.

## Troubleshooting

If you're not able to connect, try the following:

1. Make sure that there's network connectivity and that you can ping the device.
2. Check that the authorized keys are set correctly. On the target, run
   `Application.get_all_env(:nerves_firmware_ssh)` and compare keys.
3. Are you trying to use OpenSSH's `ssh-agent`? See
   [ERL-469](https://bugs.erlang.org/browse/ERL-469) and try not using it.
4. Add `:runtime_tools` to the `:extra_applications` key in your `mix.exs` and
   run `:ssh_dbg.messages()` on the target and try to connect. You should get
   some diagnostic data from the Erlang `:ssh` application that may help.
5. File an [issue](https://github.com/fhunleth/nerves_firmware_ssh/issues/new)
   or try the `#nerves` channel on the [Elixir Slack](https://elixir-slackin.herokuapp.com/).

## Device keys

Devices also have keys. This prevents man-in-the-middle attacks. For
development, `nerves_firmware_ssh` uses hardcoded device keys that are contained
in its `priv` directory. The private key portion is also in the clear in
source control, so you should not rely on device authentication in this default
configuration. This is for convenience since man-in-the-middle attacks and
device authentication are usually not concerns for everyday development tasks.

If your device uses `ssh` for other services (e.g., for providing a remote
command prompt), you'll likely want to use the same keys for both services. If
the `/etc/ssh` directory exists in the device's root filesystem,
`nerves_system_ssh` will automatically use keys from there. To generate them,
add a rootfs-additions directory to your project (see the [Nerves
documentation](https://hexdocs.pm/nerves/advanced-configuration.html#root-filesystem-additions)
and run something like the following:

```
mkdir -p rootfs-additions/etc/ssh
ssh-keygen -t rsa -f rootfs-additions/etc/ssh/ssh_host_rsa_key
```

This setup also hardcodes the ssh server keys for all devices and keeps them in
the clear, so it doesn't improve security, but makes working with devices more
convenient since there's one set of keys.

Another method is to either symlink `/etc/ssh` on the device to a writable
location on the device (Nerves devices have read-only root filesystems) or to
specify an alternative location for device keys in your `config.exs`:

```elixir
config :nerves_firmware_ssh,
  authorized_keys: [
  ],
  system_dir: "/mnt/device/ssh"
```
This requires that you add a manufacturing step to your device production that
creates a public/private key pair, writes it to your device in a hypothetical
`/mnt/device` partition, and saves the public key portion. How to do this isn't
covered here.

## The nerves_firmware_ssh protocol

`nerves_firmware_ssh` makes use of the `ssh` subsystem feature for operation.
This is similar to `sftp`. The subsystem is named `nerves_firmware_ssh`. See the
`-s` option on [ssh(1)](https://man.openbsd.org/ssh).

The data sent over `ssh` contains a header and then the contents of one or more
`.fw` files. The header is terminated by a newline (`\n`) and is a comma
separated list of operations. Currently supported operations are:

Operation         | Description
------------------|------------
fwup($FILESIZE)   | Stream $FILESIZE bytes to [fwup](https://github.com/fhunleth/fwup) on the device
reboot            | Reboot the device

After the header, all data required by operations in the header is concatenated
and streamed over. Here's an example header:

`fwup(10000),reboot\n`

For this case, 10,000 bytes of data should be sent after the header. That data
will be streamed into `fwup`. After `fwup` completes, the device will be
rebooted. If any error occurs with the `fwup` step, processing stops and the
device will not be rebooted.

The data coming back from the server is the output of the invoked commands. This
is primarily textual output suitable for reading by humans. If automating
updates, this output should be logged to help debug update failures if any.

# License

All source code is licensed under the
[Apache License, 2.0](https://opensource.org/licenses/Apache-2.0).

