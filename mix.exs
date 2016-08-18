defmodule EMDRConsumer.Mixfile do
  use Mix.Project

  def project do
    [app: :emdr_consumer,
     version: "0.0.1",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :elixir_nsq, :jiffy, :erlzmq],
     mod: {EMDRConsumer, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:jiffy, "~> 0.14.7"},
      {:elixir_nsq, github: "wistia/elixir_nsq"},
      {:erlzmq, github: "zeromq/erlzmq2"},
      {:distillery, "~> 0.9"}
    ]
  end
end
