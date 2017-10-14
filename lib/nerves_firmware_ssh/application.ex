defmodule Nerves.Firmware.SSH.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Task, [fn -> init() end], restart: :transient)
    ]

    opts = [strategy: :one_for_one, name: Nerves.Firmware.SSH.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def init() do
    port = Application.get_env(:nerves_firmware_ssh, :port, 8989)

    authorized_keys =
      Application.get_env(:nerves_firmware_ssh, :authorized_keys, [])
      |> Enum.join("\n")

    decoded_authorized_keys = :public_key.ssh_decode(authorized_keys, :auth_keys)

    cb_opts = [authorized_keys: decoded_authorized_keys]

    {:ok, _ref} =
      :ssh.daemon(port, [
        {:max_sessions, 1},
        {:id_string, :random},
        {:key_cb, {Nerves.Firmware.SSH.Keys, cb_opts}},
        {:system_dir, system_dir()},
        {:subsystems, [{'nerves_firmware_ssh', {Nerves.Firmware.SSH.Handler, []}}]}
      ])
  end

  def system_dir() do
    cond do
      system_dir = Application.get_env(:nerves_firmware_ssh, :system_dir) ->
        to_charlist(system_dir)

      File.dir?("/etc/ssh") ->
        to_charlist("/etc/ssh")

      true ->
        :code.priv_dir(:nerves_firmware_ssh)
    end
  end
end
