defmodule Nerves.Firmware.SSH.Keys do

    def host_key(algorithm, options) do
    # Delegate to system implementation for handling the host keys
    :ssh_file.host_key(algorithm, options)
  end

  def is_auth_key(key, _user, options) do
    # Grab the decoded authorized keys from the options
    cb_opts = Keyword.get(options, :key_cb_private)
    keys = Keyword.get(cb_opts, :authorized_keys)

    Enum.any?(keys, fn({k, _info}) -> k == key end)
  end
end
