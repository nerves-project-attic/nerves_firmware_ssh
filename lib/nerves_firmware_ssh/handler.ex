defmodule Nerves.Firmware.SSH.Handler do
  require Logger

  @moduledoc false

  alias Nerves.Firmware.SSH.Command

  defmodule State do
    @moduledoc false
    defstruct state: :parse_commands,
              id: nil,
              cm: nil,
              commands: [],
              buffer: <<>>,
              bytes_processed: 0,
              fwup: nil,
              exit_timer: nil
  end

  # See http://erlang.org/doc/man/ssh_channel.html for API

  def init([]) do
    state = %State{} |> maybe_fwup()
    {:ok, state}
  end

  def handle_ssh_msg({:ssh_cm, _cm, {:data, _channel_id, 0, data}}, %{fwup: nil} = state) do
    if state.exit_timer do
      {:ok, state}
    else
      Logger.debug "FWUP is not running."
      :ssh_connection.send(state.cm, state.id, "FWUP failed. Exiting.")
      timer = Process.send_after(self(), :timer, 5000)
      {:ok, %{state | exit_timer: timer}}
    end
  end

  def handle_ssh_msg({:ssh_cm, _cm, {:data, _channel_id, 0, data}}, state) do
    process_message(state.state, data, state)
  end

  def handle_ssh_msg({:ssh_cm, _cm, {:data, _channel_id, 1, _data}}, state) do
    # Ignore stderr
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

  def handle_ssh_msg({:ssh_cm, _cm, _message}, state) do
    {:ok, state}
  end

  def handle_msg({:EXIT, _port, _reason}, state) do
    {:stop, state.id, state}
  end

  def handle_msg({:ssh_channel_up, channel_id, connection_manager}, state) do
    Logger.debug("nerves_firmware_ssh: new connection")
    {:ok, %{state | id: channel_id, cm: connection_manager}}
  end

  def handle_msg({_from_port, {:data, data}}, %{fwup: _port} = state) do
    IO.puts "got fwup data:"
    IO.puts "\r\n" <> data <> "\r\n"
    case :ssh_connection.send(state.cm, state.id, data) do
      :ok -> {:ok, state}
      {:error, reason} ->
        Logger.debug "failed to send ssh data: #{inspect reason} "
        {:stop, state.id, state}
    end
  end

  def handle_msg({from_port, {:exit_status, 0}}, %{fwup: port} = state)
    when from_port == port
  do
    buffer = state.buffer
    state = %{state | buffer: <<>>}

    case run_commands(state.commands, buffer, state) do
      {:ok, state} -> {:ok, state}
      {:stop, _, state} -> {:stop, :normal, state}
    end
  end

  def handle_msg({from_port, {:exit_status, status}}, state) do
    :ssh_connection.send(state.cm, state.id, "fwup failed: #{status}")
    {:ok, %{state | fwup: nil}}
  end

  def handle_msg(:timer, state) do
    {:stop, state.id, state}
  end

  def terminate(reason, _state) do
    Logger.debug("nerves_firmware_ssh: connection terminated: #{inspect reason}")
    :ok
  end

  defp process_message(:parse_commands, data, state) do
    alldata = state.buffer <> data

    case Command.parse(data) do
      {:error, :partial} ->
        {:ok, %{state | buffer: alldata}}

      {:error, reason} ->
        :ssh_connection.send(state.cm, state.id, "nerves_firmware_ssh: error #{reason}\n")
        :ssh_connection.send_eof(state.cm, state.id)
        {:stop, state.id, state}

      {:ok, command_list, rest} ->
        new_state = %{state | buffer: <<>>, state: :running_commands, commands: command_list}
        run_commands(command_list, rest, new_state)
    end
  end

  defp process_message(:running_commands, data, state) do
    alldata = state.buffer <> data
    new_state = %{state | buffer: <<>>}
    run_commands(state.commands, alldata, new_state)
  end

  defp process_message(:wait_for_fwup, data, state) do
    alldata = state.buffer <> data
    new_state = %{state | buffer: alldata}
    {:ok, new_state}
  end

  defp process_message(:wait_for_fwup_error, _data, state) do
    # Just disgard anything we get
    {:ok, state}
  end

  defp run_commands([], _data, state) do
    :ssh_connection.send_eof(state.cm, state.id)
    {:stop, state.id, state}
  end

  defp run_commands([{:fwup, count} | rest], data, state) do
    state = maybe_fwup(state)

    bytes_left = count - state.bytes_processed
    bytes_to_process = min(bytes_left, byte_size(data))
    <<for_fwup::binary-size(bytes_to_process), leftover::binary>> = data
    new_bytes_processed = state.bytes_processed + bytes_to_process

    case {send_chunk(state.fwup, for_fwup), new_bytes_processed} do
      {:ok, ^count} ->
        # Done
        new_state = %{
          state
          | state: :wait_for_fwup,
            buffer: leftover,
            commands: rest,
            bytes_processed: 0
        }

        {:ok, new_state}

      {:ok, _} ->
        # More left
        new_state = %{state | bytes_processed: new_bytes_processed}
        {:ok, new_state}
      {:error, _} ->
        {:ok, %{state | fwup: nil}}
        # {:stop, state.id, state}
    end
  end

  defp run_commands([:reboot | rest], data, state) do
    Logger.debug("nerves_firmware_ssh: rebooting...")
    :ssh_connection.send(state.cm, state.id, "Rebooting...\n")
    Nerves.Runtime.reboot()

    new_state = %{state | commands: rest}
    run_commands(rest, data, new_state)
  end

  defp maybe_fwup(%{fwup: nil} = state) do
    Logger.debug("nerves_firmware_ssh: starting fwup...")
    :ssh_connection.send(state.cm, state.id, "starting fwup...\n")

    fwup = System.find_executable("fwup")
    devpath = Nerves.Runtime.KV.get("nerves_fw_devpath") || "/dev/mmcblk0"
    task = "upgrade"
    port = Port.open({:spawn_executable, "#{:code.priv_dir(:nerves_firmware_ssh)}/wrapper.sh"}, [
            {:args, [fwup, "--apply", "--no-unmount", "-d", devpath, "--task", task]},
            :use_stdio,
            :binary,
            :exit_status
          ])
    %{state | fwup: port}
  end

  defp maybe_fwup(state), do: state

  defp send_chunk(port, chunk) do
    Logger.debug "sending chunk"
    try do
      true = Port.command(port, chunk)
      :ok
    rescue
      _e in ArgumentError ->
        Logger.debug "Failed to send chunk because the port is dead."
        :error
      e in MatchError ->
        Logger.debug "Failed to send chunk: #{inspect e}"
        :error
    end
  end
end
