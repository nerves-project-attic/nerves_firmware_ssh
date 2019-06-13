defmodule Nerves.Firmware.SSH.Fwup do
  use GenServer
  require Logger

  @moduledoc false

  def start_link(cm) do
    GenServer.start_link(__MODULE__, [cm])
  end

  def send_chunk(pid, chunk) do
    GenServer.call(pid, {:send, chunk})
  end

  def init([cm]) do
    Process.monitor(cm)
    fwup = System.find_executable("fwup")
    devpath = Nerves.Runtime.KV.get("nerves_fw_devpath") || "/dev/mmcblk0"
    task = "upgrade"

    args = if supports_handshake(), do: ["--exit-handshake"], else: []
    args = args ++ ["--apply", "--no-unmount", "-d", devpath, "--task", task]

    port =
      Port.open({:spawn_executable, fwup}, [
        {:args, args},
        :use_stdio,
        :binary,
        :exit_status
      ])

    {:ok, %{port: port, cm: cm}}
  end

  def handle_call(_cmd, _from, %{port: nil} = state) do
    # In the process of closing down, so just ignore these.
    {:reply, :error, state}
  end

  def handle_call({:send, chunk}, _from, state) do
    # Since fwup may be slower than ssh, we need to provide backpressure
    # here. It's tricky since `Port.command/2` is the only way to send
    # bytes to fwup synchronously, but it's possible for fwup to error
    # out when it's sending. If fwup errors out, then we need to make
    # sure that a message gets back to the user for what happened.
    # `Port.command/2` exits on error (it will be an :epipe error).
    # Therefore we start a new process to call `Port.command/2` while
    # we continue to handle responses. We also trap_exit to get messages
    # when the port the Task exit.
    result =
      try do
        Port.command(state.port, chunk)
        :ok
      rescue
        ArgumentError ->
          _ = Logger.info("Port.command ArgumentError race condition detected and handled")
          :error
      end

    {:reply, result, state}
  end

  def handle_info({port, {:data, response}}, %{port: port} = state) do
    # fwup says that it's going to exit by sending a CTRL+Z (0x1a)
    case String.split(response, "\x1a", parts: 2) do
      [response] ->
        :ssh_channel.cast(state.cm, {:fwup_data, response})

      [response, <<status>>] ->
        # fwup exited with status
        _ = Logger.info("fwup exited with status #{status}")
        send(port, {self(), :close})
        :ssh_channel.cast(state.cm, {:fwup_data, response})
        :ssh_channel.cast(state.cm, {:fwup_exit, status})

      [response, other] ->
        # fwup exited without status
        _ = Logger.info("fwup exited improperly: #{inspect(other)}")
        send(port, {self(), :close})
        :ssh_channel.cast(state.cm, {:fwup_data, response})
    end

    {:noreply, state}
  end

  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    _ = Logger.info("fwup exited with status #{status} without handshaking")
    :ssh_channel.cast(state.cm, {:fwup_exit, status})
    {:noreply, %{state | port: nil}}
  end

  def handle_info({port, :closed}, %{port: port} = state) do
    _ = Logger.info("fwup port was closed")
    :ssh_channel.cast(state.cm, {:fwup_exit, 0})
    {:noreply, %{state | port: nil}}
  end

  def handle_info({:DOWN, _, :process, cm, reason}, %{cm: cm} = state) do
    {:stop, :normal, state}
  end

  defp supports_handshake() do
    Version.match?(fwup_version(), "> 0.17.0")
  end

  defp fwup_version() do
    {version_str, 0} = System.cmd("fwup", ["--version"])

    version_str
    |> String.trim()
    |> Version.parse!()
  end
end
