defmodule Sshdtest.Echo do

  defmodule State do
    defstruct n: nil, id: nil, cm: nil
  end

  def init([n]) do
    {:ok, %State{n: n}}
  end

  def handle_msg({:ssh_channel_up, channel_id, connection_manager}, state) do
    IO.puts("ssh_channel_up #{inspect channel_id} #{inspect connection_manager}")
    {:ok, %{state | id: channel_id, cm: connection_manager}}
  end

  def handle_ssh_msg({:ssh_cm, cm, {:data, channel_id, 0, data}}, state) do
    n = state.n
    m = n - byte_size(data)
    case m > 0 do
      true ->
        :ssh_connection.send(cm, channel_id, data)
        {:ok, %{state | n: m}}
      false ->
        <<send_data::binary-size(n), _::binary>> = data
        :ssh_connection.send(cm, channel_id, send_data)
        :ssh_connection.send_eof(cm, channel_id)
        {:stop, channel_id, state}
    end
  end
  def handle_ssh_msg({:ssh_cm, _cm,
    {:data, _channel_id, 1, data}}, state) do
    IO.puts("Error #{inspect data}")
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
end
