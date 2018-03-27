defmodule Mix.Tasks.Firmware.Gen.Script do
  use Mix.Task

  @script_name "upload.sh"

  @shortdoc "Generates a shell script for pushing firmware updates"

  @moduledoc """
  Creates a shell script for invoking ssh to upgrade devices with nerves_firmware_ssh.

  This script may be used on its own or used as a base for more complicated
  device software upgrade deployments.

  It saves the script to #{@script_name}.
  """

  def run(_) do
    upload_script_contents =
      Application.app_dir(:nerves_firmware_ssh, "priv/templates/script.upload.eex")
      |> EEx.eval_file([])

    if File.exists?(@script_name) do
      Mix.shell().yes?("OK to overwrite #{@script_name}?") || Mix.raise("Aborted")
    end

    Mix.shell().info("""
    Writing #{@script_name}...
    """)

    File.write!(@script_name, upload_script_contents)
    File.chmod!(@script_name, 0o755)
  end
end
