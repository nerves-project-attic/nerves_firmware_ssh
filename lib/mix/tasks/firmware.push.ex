defmodule Mix.Tasks.Firmware.Push do
  use Mix.Task

  @shortdoc "Pushes a firmware update to a Nerves device over SSH"

  @moduledoc """
  Upgrades the firmware on a Nerves device using SSH.

  This task copies a `.fw` file to a Nerves device running
  `nerves_firmware_ssh`, upgrades the device and then reboots.

  ## Command line options

   * `--firmware` - The path to a fw file
   * `--passphrase` - The passphrase for the private key file
   * `--port` - The TCP port number to use to connect to the target
   * `--target` - Alternative to setting the `MIX_TARGET` environment variable
   * `--user-dir` - The path to your ssh private key files (e.g., "~/.ssh")

  ## Examples

  Upgrade a Raspberry Pi Zero at `nerves.local`:

      MIX_TARGET=rpi0 mix firmware.push nerves.local

  Upgrade `192.168.1.120` and explicitly pass the `.fw` file:

      mix firmware.push 192.168.1.120 --firmware _images/rpi3/my_app.fw

  """

  @switches [
    firmware: :string,
    target: :string,
    port: :integer,
    user_dir: :string,
    passphrase: :string
  ]
  def run(argv) do
    {opts, args, unknown} = OptionParser.parse(argv, strict: @switches)

    if !Enum.empty?(unknown) do
      [{param, _} | _] = unknown
      Mix.raise("unknown parameter passed to mix firmware.push: #{param}")
    end

    if length(args) != 1 do
      Mix.raise("mix firmware.push expects a target IP address or name")
    end

    [ip] = args
    user_dir = opts[:user_dir] || "~/.ssh"
    user_dir = Path.expand(user_dir) |> to_charlist
    fwfile = firmware(opts)
    port = opts[:port] || 8989
    stats = File.stat!(fwfile)
    fwsize = stats.size
    Application.ensure_all_started(:ssh)
    connect_opts = [silently_accept_hosts: true, user_dir: user_dir, auth_methods: 'publickey']

    connect_opts =
      if passphrase = opts[:passphrase] do
        passphrase = to_charlist(passphrase)

        connect_opts
        |> Keyword.put(:rsa_pass_phrase, passphrase)
        |> Keyword.put(:dsa_pass_phrase, passphrase)
      else
        connect_opts
      end

    connection_ref =
      case :ssh.connect(to_charlist(ip), port, connect_opts) do
        {:ok, connection_ref} ->
          connection_ref

        {:error, 'Unable to connect using the available authentication methods'} ->
          Mix.raise(
            "couldn't connected to #{ip}: check private key and the passphrase protecting it"
          )

        {:error, reason} ->
          Mix.raise("couldn't connected to #{ip}: #{inspect(reason)}")
      end

    {:ok, channel_id} = :ssh_connection.session_channel(connection_ref, :infinity)

    :success =
      :ssh_connection.subsystem(connection_ref, channel_id, 'nerves_firmware_ssh', :infinity)

    :ok = :ssh_connection.send(connection_ref, channel_id, "fwup:#{fwsize},reboot\n")

    chunks =
      File.open!(fwfile, [:read])
      |> IO.binstream(16384)

    wait_for_complete(connection_ref, channel_id, chunks)
  end

  # find the firmware

  defp firmware(opts) do
    if fw = opts[:firmware] do
      fw |> Path.expand()
    else
      discover_firmware(opts)
    end
  end

  defp discover_firmware(opts) do
    target =
      opts[:target] || System.get_env("MIX_TARGET") ||
        Mix.raise("""
        You must pass either firmware or target
        Examples:
          $ export MIX_TARGET=rpi0
          $ mix firmware.push rpi0.local
        Or
          $ mix firmware.push rpi0.local --firmware path/to/app.fw
          $ mix firmware.push rpi0.local --target rpi0
        """)

    project = Mix.Project.get()

    :code.delete(project)
    :code.purge(project)
    level = Logger.level()
    Logger.configure(level: :error)
    Application.stop(:mix)
    System.put_env("MIX_TARGET", target)
    Application.start(:mix)
    Logger.configure(level: level)

    Mix.Project.in_project(project, File.cwd!(), fn _module ->
      target = Mix.Project.config()[:target]
      app = Mix.Project.config()[:app]

      images_path =
        Mix.Project.config()[:images_path] ||
          Path.join([Mix.Project.build_path(), "nerves", "images"]) || "_images/#{target}"

      Path.join([images_path, "#{app}.fw"])
      |> Path.expand()
    end)
  end

  defp wait_for_complete(connection_ref, channel_id, chunks) do
    timeout =
      case Enum.take(chunks, 1) do
        [chunk] ->
          :ok = :ssh_connection.send(connection_ref, channel_id, chunk)
          0

        [] ->
          10000
      end

    receive do
      {:ssh_cm, _connection_ref, {:data, 0, 0, message}} ->
        IO.write(message)
        IO.write("")
        wait_for_complete(connection_ref, channel_id, chunks)

      {:ssh_cm, _connection_ref, {:eof, 0}} ->
        # Ignore.
        wait_for_complete(connection_ref, channel_id, chunks)

      {:ssh_cm, _connection_ref, {:closed, 0}} ->
        :ok
    after
      timeout ->
        wait_for_complete(connection_ref, channel_id, chunks)
    end
  end
end
