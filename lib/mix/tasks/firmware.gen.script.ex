defmodule Mix.Tasks.Firmware.Gen.Script do
  @shortdoc "Generates a shell script for pushing firmware updates"

  @default_filename "upload.sh"

  use Mix.Task

  def run(_) do
    Mix.shell().info("""

    Generate a new shell script for pushing firmware to devices running `nerves_firmware_ssh`.
    """)

    filename = determine_filename()
    priv_dir = to_string(:code.priv_dir(:nerves_firmware_ssh))
    template = Path.join(priv_dir, "templates/script.upload.eex")
    upload_script_contents = EEx.eval_file(template, [])

    Mix.shell().info("""

    Generating a new file named #{filename}
    """)

    File.write(filename, "#{upload_script_contents}\n")

    File.chmod!(filename, 0o755)
  end

  defp determine_filename do
    prompt_for_filename() |> String.trim() |> apply_default_filename()
  end

  defp prompt_for_filename do
    Mix.shell().prompt("Enter file to use for your new script (./#{@default_filename}):")
  end

  defp apply_default_filename("") do
    @default_filename
  end

  defp apply_default_filename(filename) do
    filename
  end
end
