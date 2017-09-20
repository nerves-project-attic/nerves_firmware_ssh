defmodule Nerves.Firmware.SSH.Command do
  @moduledoc false

  @type command :: :reboot | {:fwup, non_neg_integer} | :invalid

  @doc """
  Parse a command string.

  Commands are comma separated and terminated by a newline.
  """
  @spec parse(String.t()) :: {:ok, [command]} | {:error, :partial | :invalid_command}
  def parse(data) do
    case String.split(data, "\n", parts: 2) do
      [command_string, rest] ->
        commands = parse_commands(command_string)

        if Enum.member?(commands, :invalid) do
          {:error, :invalid_command}
        else
          {:ok, commands, rest}
        end

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
  def parse_command(_data), do: :invalid
end
