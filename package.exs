version = String.strip(File.read!("VERSION"))

Expm.Package.new(
  name: "elixir",
  description: "Elixir is a functional meta-programming aware language built on top of the Erlang VM",
  version: version,
  keywords: [],
  homepage: "http://elixir-lang.org/",
  maintainers: [[name: "José Valim", email: "jose.valim@plataformatec.com.br"]],
  repositories: [[github: "elixir-lang/elixir", tag: "v#{version}"]]
)
