defmodule Mix.Tasks.Firmware.Push do
  use Mix.Task

  @shortdoc "Pushes firmware to a Nerves device over SSH"

  @moduledoc """
  Pushes firmware to a Nerves device.

  This task will take a fw file path passed as --firmware or discover it from
  a target passed as --target.

  ## Command line options

   * `--target` - The target string of the target configuration.
   * `--firmware` - The path to a fw file.
   * `--port` - The TCP port number to use to connect to the target.
   * `--user-dir` - The path to where your ssh private key files are located.

  For example, to push firmware to a device at an IP by specifying a fw file

    mix firmware.push 192.168.1.120 --firmware _images/rpi3/my_app.fw

  Or by discovering it with the target

    mix firmware.push 192.168.1.120 --target rpi3

  """

  @switches [firmware: :string, target: :string, port: :integer, user_dir: :string]
  def run(argv) do
    {opts, args, _} = OptionParser.parse(argv, switches: @switches)
    if length(args) != 1 do
	Mix.raise "mix firmware.push expects a target IP address or name"
    end
    [ip] = args
    user_dir = opts[:user_dir] || "~/.ssh"
    user_dir = Path.expand(user_dir) |> to_char_list
    fwfile = firmware(opts)
    port = opts[:port] || 8989
    stats = File.stat!(fwfile)
    fwsize = stats.size
    Application.ensure_all_started(:ssh)
    connect_opts = [silently_accept_hosts: true, user_dir: user_dir]
    connect_opts =
      if passphrase = opts[:rsa_pass_phrase] do
        Keyword.put(connect_opts, :rsa_pass_phrase, passphrase)
      else
        connect_opts
      end

    {:ok, connection_ref} = :ssh.connect(to_char_list(ip), port, connect_opts)
    {:ok, channel_id} = :ssh_connection.session_channel(connection_ref, :infinity)
    :success = :ssh_connection.subsystem(connection_ref, channel_id, 'nerves_firmware_ssh', :infinity)
    :ok = :ssh_connection.send(connection_ref, channel_id, "fwup:#{fwsize},reboot\n")

    chunks =
      File.open!(fwfile, [:read])
      |> IO.binstream(16384)

    wait_for_complete(connection_ref, channel_id, chunks)
  end

  #find the firmware

  defp firmware(opts) do
    if fw = opts[:firmware] do
      fw |> Path.expand
    else
      discover_firmware(opts)
    end
  end

  defp discover_firmware(opts) do
    target = opts[:target] || System.get_env("MIX_TARGET") || Mix.raise """
    You must pass either firmware or target
    Examples:
      $ export MIX_TARGET=rpi0
      $ mix firmware.push rpi0.local
    Or
      $ mix firmware.push rpi0.local --firmware path/to/app.fw
      $ mix firmware.push rpi0.local --target rpi0
    """

    project = Mix.Project.get

    :code.delete(project)
    :code.purge(project)
    level = Logger.level
    Logger.configure(level: :error)
    Application.stop(:mix)
    System.put_env("MIX_TARGET", target)
    Application.start(:mix)
    Logger.configure(level: level)

    Mix.Project.in_project(project, File.cwd!, fn(_module) ->
      target = Mix.Project.config[:target]
      app = Mix.Project.config[:app]
      images_path =
        (Mix.Project.config[:images_path] ||
        Path.join([Mix.Project.build_path, "nerves", "images"]) ||
        "_images/#{target}")
      Path.join([images_path, "#{app}.fw"])
      |> Path.expand
    end)
  end

  defp wait_for_complete(connection_ref, channel_id, chunks) do
    timeout =
      case Enum.take(chunks, 1) do
        [chunk] ->
          :ok = :ssh_connection.send(connection_ref, channel_id, chunk)
          0
        [] ->
          10_000
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
