defmodule Sshdtest.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Define workers and child supervisors to be supervised
    children = [
      # Starts a worker by calling: Sshdtest.Worker.start_link(arg1, arg2, arg3)
      # worker(Sshdtest.Worker, [arg1, arg2, arg3]),
    ]

    :ssh.daemon(8989, [{:system_dir, :code.priv_dir(:sshdtest)}, {:subsystems, [{'nerves_fw_ssh', {Sshdtest.Echo, []}}]}])

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Sshdtest.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
