defmodule Sshdtest.Echo do
  alias Sshdtest.Command

  defmodule State do
    defstruct state: :parse_commands,
            commands: [],
            buffer: <<>>,
            id: nil,
            cm: nil
  end

  # See http://erlang.org/doc/man/ssh_channel.html for API

  def init([]) do
    {:ok, %State{}}
  end

  def handle_msg({:ssh_channel_up, channel_id, connection_manager}, state) do
    IO.puts("ssh_channel_up #{inspect channel_id} #{inspect connection_manager}")
    {:ok, %{state | id: channel_id, cm: connection_manager}}
  end

  def handle_ssh_msg({:ssh_cm, _cm, {:data, _channel_id, 0, data}}, state) do
    process_message(state.state, data, state)
  end
  def handle_ssh_msg({:ssh_cm, _cm, {:data, _channel_id, 1, _data}}, state) do
    # Ignore data?
    {:ok, state}
  end
  def handle_ssh_msg({:ssh_cm, _cm, {:eof, _channel_id}}, state) do
    {:ok, state}
  end
  def handle_ssh_msg({:ssh_cm, _cm, {:signal, _, _}}, state) do
    # Ignore signals
    {:ok, state}
  end
  def handle_ssh_msg({:ssh_cm, _cm, {:exit_signal, channel_id, _, _error, _}}, state) do
    {:stop, channel_id, state}
  end
  def handle_ssh_msg({:ssh_cm, _cm, {:exit_status, channel_id, _status}}, state) do
    {:stop, channel_id, state}
  end

  def terminate(_reason, _state), do: :ok

  defp process_message(:parse_commands, data, state) do
    alldata = state.buffer <> data
    case Command.parse(data) do
      {:error, :partial} ->
        {:ok, %{state | buffer: alldata}}
      {:error, reason} ->
        :ssh_connection.send(state.cm, state.id, "nerves_firmware_ssh: error #{reason}")
        :ssh_connection.send_eof(state.cm, state.id)
        {:stop, state.id, state}
      {:ok, command_list, rest} ->
        new_state = %{state | buffer: <<>>, state: :running_commands, commands: command_list}
        run_commands(command_list, rest, new_state)
    end
  end
  defp process_message(:running_commands, data, state) do
    IO.puts("process_message: #{inspect state.commands}")
    alldata = state.buffer <> data
    run_commands(state.command_list, alldata, state)
  end

  defp run_commands([], _data, state) do
    IO.puts("Done running commands!")
    :ssh_connection.send_eof(state.cm, state.id)
    {:stop, state.id, state}
  end
  defp run_commands([:fwup | rest], data, state) do
    IO.puts("Running fwup command with #{byte_size(data)} bytes of data")
    {:ok, %{state | buffer: <<>>, commands: rest}}
  end
  defp run_commands([:reboot | rest], data, state) do
    IO.puts("Running reboot command with #{byte_size(data)} bytes of data")
    {:ok, %{state | buffer: <<>>, commands: rest}}
  end

end
