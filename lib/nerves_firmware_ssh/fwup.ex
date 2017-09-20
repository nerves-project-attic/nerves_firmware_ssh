defmodule Nerves.Firmware.SSH.Fwup do
  use GenServer
  require Logger

  @moduledoc false

  def start_link(cm) do
    GenServer.start_link(__MODULE__, [cm])
  end

  def send_chunk(pid, chunk) do
    Logger.error("GenServer.call")
    rc = GenServer.call(pid, {:send, chunk})
    Logger.error("GenServer.call done: #{inspect rc}")
    rc
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
    Logger.info("Starting fwup. port is #{inspect port}")
    {:ok, %{port: port, cm: cm, sender: nil, from: nil, sent_exit: false}}
  end

  def handle_call(_cmd, _from, %{port: nil} = state) do
    {:reply, :error, state}
  end
  def handle_call({:send, chunk}, from, state) do
    Logger.info("#{inspect self()} Sending chunk of size #{byte_size(chunk)} to #{inspect state.port}...")
    try do
      {:ok, pid} = Task.start_link(fn() ->
        Logger.info("#{inspect self()} calling Port.command")
        Port.command(state.port, chunk)
        Logger.info("#{inspect self()} done Port.command")
      end)
      Logger.info("#{inspect self()} Starting task...")
      {:noreply, %{state | sender: pid, from: from}}
    rescue
      ArgumentError ->
          Logger.error("Got an argument error!!")
          {:reply, :error, %{state | port: nil}}
    catch
      :exit, _ ->
          Logger.error("Sending data to fwup failed due to epipe")
          {:reply, :error, %{state | port: nil}}
    end
  end

  def handle_info({port, {:data, response}}, %{port: port} = state) do
    Logger.info("fwup got #{inspect response}")
    :ok = :ssh_channel.cast(state.cm, {:fwup_data, response})
    {:noreply, state}
  end
  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    Logger.info("fwup exited with status #{status}")
    state.sent_exit || :ssh_channel.cast(state.cm, {:fwup_exit, status})
    {:noreply, %{state | sent_exit: true}}
  end
  def handle_info({:EXIT, port, reason}, %{port: port} = state) do
    Logger.error("Caught an EXIT from #{inspect port} for reason #{inspect reason}")
    state.sent_exit || :ssh_channel.cast(state.cm, {:fwup_exit, 255})
    {:noreply, %{state | sent_exit: true}}
  end
  def handle_info({:EXIT, pid, :normal}, %{sender: pid} = state) do
    Logger.info("#{inspect self()} Sending chunk done")
    GenServer.reply(state.from, :ok)
    {:noreply,  %{state | sender: nil, from: nil}}
  end
  def handle_info({:EXIT, pid, reason}, %{sender: pid} = state) do
    Logger.error("Caught an EXIT from sender #{inspect pid} for reason #{inspect reason}")
    state.sent_exit || :ssh_channel.cast(state.cm, {:fwup_exit, 255})
    GenServer.reply(state.from, :error)
    {:noreply, %{state | sent_exit: true, sender: nil, from: nil}}
  end
end
