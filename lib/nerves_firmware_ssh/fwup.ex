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
    fwup = System.find_executable("fwup")
    devpath = Nerves.Runtime.KV.get("nerves_fw_devpath") || "/dev/mmcblk0"
    task = "upgrade"

    Process.flag(:trap_exit, true)

    port = Port.open({:spawn_executable, fwup},
      [{:args, ["--apply", "--no-unmount", "-d", devpath,
                "--task", task]},
       :use_stdio,
       :binary,
       :exit_status
      ])
    {:ok, %{port: port, cm: cm, sender: nil, from: nil, sent_exit: false}}
  end

  def handle_call(_cmd, _from, %{sent_exit: true} = state) do
    {:reply, :error, state}
  end
  def handle_call({:send, _chunk}, _from, %{from: inprogress_from} = state) when inprogress_from != nil do
    exit(:cant_handle_multiple_sends)
  end
  def handle_call({:send, chunk}, from, state) do
    # Since fwup may be slower than ssh, we need to provide backpressure
    # here. It's tricky since `Port.command/2` is the only way to send
    # bytes to fwup synchronously, but it's possible for fwup to error
    # out when it's sending. If fwup errors out, then we need to make
    # sure that a message gets back to the user for what happened.
    # `Port.command/2` exits on error (it will be an :epipe error).
    # Therefore we start a new process to call `Port.command/2` while
    # we continue to handle responses. We also trap_exit to get messages
    # when the port the Task exit.
    {:ok, pid} = Task.start_link(fn() ->
      Port.command(state.port, chunk)
    end)
    {:noreply, %{state | sender: pid, from: from}}
  end

  def handle_info({port, {:data, response}}, %{port: port} = state) do
    :ok = :ssh_channel.cast(state.cm, {:fwup_data, response})
    {:noreply, state}
  end
  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    Logger.info("fwup exited with status #{status}")
    new_state = maybe_send_fwup_exit(state, status)
    {:noreply, new_state}
  end
  def handle_info({:EXIT, port, reason}, %{port: port} = state) do
    Logger.error("nerves_firmware_ssh: unexpected exit from fwup: #{inspect reason}")
    Process.send_after(self(), :send_exit, 1000)
    {:noreply, %{state | sent_exit: true}}
  end
  def handle_info({:EXIT, pid, :normal}, %{sender: pid} = state) do
    # Normal case where `Port.command/2` succeeds
    GenServer.reply(state.from, :ok)
    {:noreply,  %{state | sender: nil, from: nil}}
  end
  def handle_info({:EXIT, pid, reason}, %{sender: pid} = state) do
    # Unexpected case where `Port.command/2` fails
    Logger.error("nerves_firmware_ssh: unexpected send failure to fwup: #{inspect reason}")

    # The :epipe from fwup exiting beats the final bytes sent by
    # fwup. This delay lets those be received.
    Process.send_after(self(), :send_exit, 1000)

    {:noreply, %{state | sender: nil, sent_exit: true}}
  end
  def handle_info(:send_exit, state) do
    if state.from do
      GenServer.reply(state.from, :error)
    end
    :ssh_channel.cast(state.cm, {:fwup_exit, 255})
    {:noreply, %{state | from: nil}}
  end

  def maybe_send_fwup_exit(%{sent_exit: false} = state, status) do
    :ssh_channel.cast(state.cm, {:fwup_exit, status})
    %{state | sent_exit: true}
  end
  def maybe_send_fwup_exit(state, _status), do: state


end
