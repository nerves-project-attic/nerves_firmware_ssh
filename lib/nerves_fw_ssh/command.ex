defmodule Nerves.Firmware.SSH.Command do

  @doc """
  Parse a command string.

  Commands are comma separated and terminated by a newline.
  """
  def parse(data) when byte_size(data) > 64 do
    # Immediately fail if the command looks too long
    {:error, :no_command}
  end
  def parse(data) do
    case String.split(data, "\n", parts: 2) do
      [commands, rest] ->
        {:ok, parse_commands(commands), rest}
      [_] ->
        {:error, :partial}
    end
  end

  defp parse_commands(commands) do
    commands
    |> String.split(",")
    |> Enum.map(&parse_command/1)
  end

  def parse_command(<<"fwup:", filesize::binary>>), do: {:fwup, String.to_integer(filesize)}
  def parse_command("reboot"), do: :reboot
end
