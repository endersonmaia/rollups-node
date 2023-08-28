
target "docker-metadata-action" {}
target "docker-platforms" {}

group "default" {
  targets = [
    "advance-runner",
    "cli",
    "eth-input-reader",
    "graphql-server",
    "hardhat",
    "host-runner",
    "inspect-server",
    "indexer",
    "state-server"
  ]
}

target "deps" {
  inherits   = ["docker-metadata-action", "docker-platforms"]
  dockerfile = "offchain/Dockerfile"
  target     = "builder"
  context    = "."
}

target "state-server" {
  inherits   = ["docker-metadata-action", "docker-platforms"]
  dockerfile = "offchain/Dockerfile"
  target     = "state_server"
  context    = "."
}

target "eth-input-reader" {
  inherits   = ["docker-metadata-action", "docker-platforms"]
  dockerfile = "offchain/Dockerfile"
  target     = "eth-input-reader"
  context    = "."
}

target "indexer" {
  inherits   = ["docker-metadata-action", "docker-platforms"]
  dockerfile = "offchain/Dockerfile"
  target     = "indexer"
  context    = "."
}

target "inspect-server" {
  inherits   = ["docker-metadata-action", "docker-platforms"]
  dockerfile = "offchain/Dockerfile"
  target     = "inspect_server"
  context    = "."
}

target "graphql-server" {
  inherits   = ["docker-metadata-action", "docker-platforms"]
  dockerfile = "offchain/Dockerfile"
  target     = "graphql_server"
  context    = "."
}

target "advance-runner" {
  inherits   = ["docker-metadata-action", "docker-platforms"]
  dockerfile = "offchain/Dockerfile"
  target     = "advance_runner"
  context    = "."
}

target "host-runner" {
  inherits   = ["docker-metadata-action", "docker-platforms"]
  dockerfile = "offchain/Dockerfile"
  target     = "host_runner"
  context    = "."
}

target "hardhat" {
  inherits = ["docker-metadata-action", "docker-platforms"]
  context  = "./onchain"
  target   = "hardhat"
}

target "cli" {
  inherits = ["docker-metadata-action", "docker-platforms"]
  context  = "./onchain"
  target   = "cli"
}

target "deployments" {
  inherits   = ["docker-metadata-action"]
  dockerfile = "offchain/Dockerfile"
  target     = "deployments"
  context    = "."
  platforms = [
    "linux/amd64",
    "linux/arm64",
    "linux/riscv64"
  ]
}
