defmodule Nerves.Firmware.SSH.Mixfile do
  use Mix.Project

  @version "0.2.2"

  @description """
  Perform over-the-air updates to Nerves devices using ssh
  """

  def project() do
    [
      app: :nerves_firmware_ssh,
      version: @version,
      description: @description,
      package: package(),
      elixir: "~> 1.4",
      docs: docs(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application() do
    [extra_applications: [:logger, :ssh], mod: {Nerves.Firmware.SSH.Application, []}]
  end

  defp docs() do
    [main: "readme", extras: ["README.md"]]
  end

  defp deps() do
    [{:nerves_runtime, "~> 0.4"}, {:ex_doc, "~> 0.11", only: :dev}]
  end

  defp package() do
    [
      maintainers: ["Frank Hunleth"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/fhunleth/nerves_firmware_ssh"}
    ]
  end
end
