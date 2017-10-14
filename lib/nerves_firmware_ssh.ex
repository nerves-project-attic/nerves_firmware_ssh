defmodule Nerves.Firmware.SSH do
  @moduledoc """
  This project contains the necessary infrastruction to support "over-the-air"
  firmware updates with Nerves by using
  [ssh](https://en.wikipedia.org/wiki/Secure_Shell).

  The default settings make it quick to integrate into Nerves projects for
  development work. Later on, if your deployed devices can be reached by `ssh`,
  it's even possible to use tools like Ansible or even shell scripts to update a
  set of devices all at once.

  It's intended to start and run on its own and there's no API for modifying its
  behavior at runtime.

  See the README.md for configuration options. In particular, make sure to add
  all authorized ssh keys.
  """
end
