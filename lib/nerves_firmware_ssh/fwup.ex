defmodule Nerves.Firmware.SSH.Fwup do
  use GenServer
  require Logger

  @moduledoc """
  """

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

    port = Port.open({:spawn_executable, fwup},
      [{:args, ["--apply", "--no-unmount", "-d", devpath,
                "--task", task]},
       :use_stdio,
       :binary,
       :exit_status
      ])
    {:ok, %{port: port, cm: cm}}
  end

  def handle_call({:send, chunk}, _from, state) do
    true = Port.command(state.port, chunk)
    {:reply, :ok, state}
  end

  def handle_info({_port, {:data, response}}, state) do
    :ok = :ssh_channel.cast(state.cm, {:fwup_data, response})
    {:noreply, state}
  end
  def handle_info({_port, {:exit_status, status}}, state) do
    Logger.info("fwup exited with status #{status}")
    :ok = :ssh_channel.cast(state.cm, {:fwup_exit, status})
    {:noreply, state}
  end
end
