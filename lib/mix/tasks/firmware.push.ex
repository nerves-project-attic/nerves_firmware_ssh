defmodule Mix.Tasks.Firmware.Push do
  use Mix.Task

  @shortdoc "Pushes a firmware update to a Nerves device over SSH"

  @moduledoc """
  Upgrades the firmware on a Nerves device using SSH.

  Please use `mix firmware.gen.script` and run the shell script
  until `mix firmware.push` can be properly fixed.
  """

  def run(_args) do
    Mix.raise("""
    Please use `mix firmware.gen.script` and run the shell script
    manually until `mix firmware.push` can be properly fixed.
    """)
  end
end
