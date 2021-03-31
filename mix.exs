defmodule Nerves.Firmware.SSH.MixProject do
  use Mix.Project

  @version "0.4.6"
  @source_url "https://github.com/nerves-project/nerves_firmware_ssh"

  @description "Perform over-the-air updates to Nerves devices using ssh"

  def project() do
    [
      app: :nerves_firmware_ssh,
      version: @version,
      description: @description,
      package: package(),
      elixir: "~> 1.6",
      docs: docs(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [
        flags: [:error_handling, :race_conditions, :underspecs],
        plt_add_apps: [:mix, :eex]
      ],
      preferred_cli_env: %{
        docs: :docs,
        "hex.publish": :docs,
        "hex.build": :docs
      }
    ]
  end

  def application() do
    [extra_applications: [:logger, :ssh], mod: {Nerves.Firmware.SSH.Application, []}]
  end

  defp docs() do
    [
      extras: ["README.md", "CHANGELOG.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end

  defp deps() do
    [
      {:nerves_runtime, "~> 0.6"},
      {:ex_doc, "~> 0.22", only: :docs, runtime: false},
      {:dialyxir, "~> 1.1.0", only: :dev, runtime: false}
    ]
  end

  defp package() do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end
end
