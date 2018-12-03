defmodule Nerves.Firmware.SSH.NoShell do
  @moduledoc false

  @doc """
  Called by `:ssh.daemon` when a user requests an interactive shell.
  """
  @spec start_shell(charlist(), :ssh.ip_port()) :: pid()
  def start_shell(_user, _peer) do
    spawn(fn ->
      IO.puts("Interactive login unsupported. Use the nerves_firmware_ssh subsystem.")
    end)
  end

  @doc """
  Called by `:ssh.daemon` when a user tries to run a remote command.
  """
  @spec start_exec(charlist(), charlist(), :ssh.ip_port()) :: pid()
  def start_exec(_cmd, _user, _peer) do
    spawn(fn ->
      IO.puts("Command execution unsupported.")
    end)
  end
end
