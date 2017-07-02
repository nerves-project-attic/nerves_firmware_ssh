# Sshdtest

**TODO: Add description**

## Create server keys

ssh-keygen -t rsa -f priv/ssh_host_rsa_key
mkdir -p priv

## User keys

The user keys default to ~/.ssh. For Nerves, the user public keys of interest need to
be copied to the priv dir or someplace.

## Calling
echo "FWUP,REBOOT" | cat - myfirmware.fw | ssh -s -p 8989 localhost nerves_fw_ssh

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `sshdtest` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:sshdtest, "~> 0.1.0"}]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/sshdtest](https://hexdocs.pm/sshdtest).

