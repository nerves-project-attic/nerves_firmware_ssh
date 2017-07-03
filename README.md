# Nerves.Firmware.SSH

Upload to a Nerves target using the ssh protocol.

## Create server keys

ssh-keygen -t rsa -f priv/ssh_host_rsa_key
mkdir -p priv

## User keys

The user keys default to ~/.ssh. For Nerves, the user public keys of interest need to
be copied to the priv dir or someplace.

## Manual invocation

If you need to run a firmware update from a shell script, here's how to do it:

```
FILENAME=myapp.fw
FILESIZE=$(stat -c%s "$FILENAME")
printf "fwup:$FILESIZE,reboot\n" | cat - $FILENAME | ssh -s -p 8989 target_ip_addr nerves_fw_ssh
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `nerves_firmware_ssh` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:nerves_firmware_ssh, "~> 0.1.0"}]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/sshdtest](https://hexdocs.pm/sshdtest).

