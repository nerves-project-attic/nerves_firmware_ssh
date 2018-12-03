defmodule Nerves.Firmware.SSH.NoShell do
  def start_shell(user, peer) do
    spawn(fn ->
      run(user, peer, "Interactive Login")
    end)
  end

  def start_exec(cmd, user, peer) do
    spawn(fn ->
      run(user, peer, "Command Execution (#{cmd})")
    end)
  end

  def run(user, peer = {ip, _port}, feature) do
    """
    Sorry #{inspect(user)} from #{:inet.ntoa(ip)}, Nerves Firmware SSH does not support #{feature}
    """
    |> IO.puts()
  end
end
