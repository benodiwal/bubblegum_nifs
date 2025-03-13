defmodule BubblegumNifs.MixProject do
  use Mix.Project

  def project do
    [
      app: :bubblegum_nifs,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: Mix.compilers(),
      description: "Elixir interface for Metaplex Bubblegum compressed NFTs on Solana",
      rustler_crates: rustler_crates(),
      package: package(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp rustler_crates do
    [
      bubblegum_nifs: [
        path: "native/bubblegum_nifs",
        mode: if(Mix.env() == :prod, do: :release, else: :debug)
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:rustler, "~> 0.36.0", runtime: false},
      {:tesla, "~> 1.4.1"},
      {:jason, "~> 1.4.1"},
      {:exbase58, "~> 1.0.2"},
      {:ex_doc, "~> 0.22.0"},
      {:httpoison, "~> 2.2.2"},
      {:mox, "~>  1.1", only: :test}
    ]
  end

  defp package do
    [
      maintainers: ["Sachin Beniwal"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/benodiwal/bubblegum_nifs"},
      files:
        ~w(lib native/bubblegum_nifs/src native/bubblegum_nifs/Cargo.toml .formatter.exs mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_url: "https://github.com/benodiwal/bubblegum_nifs"
    ]
  end
end
