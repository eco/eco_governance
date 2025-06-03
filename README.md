# Eco Governance Repo

This repo contains the code for the Eco Governance system. For now, this repository is limited to the migration of the old ECOx and ECO tokens and governance system to the new unified single token system. To access those contracts, please see the src/migration directory. To start up the enviroment, run:

```sh
forge install
```

There may be an issue with the libraries not being found in the `currency-1.5` or `op-eco` git submodule. If this occurs, run:

```sh
cd lib/currency-1.5
yarn install
cd -
cd lib/op-eco
yarn install
cd -
```

To build, run:

```sh
forge build
```

To test, run. We have to generate an interface for L2ECOxFreeze because of incompability issues with Solidity versions.

```sh
forge build src/migration/upgrades/L2ECOxFreeze.sol 
cast interface out/L2ECOxFreeze.sol/L2ECOxFreeze.json --name IL2ECOxFreeze > src/migration/interfaces/IL2ECOxFreeze.sol
forge test
```

# Foundry Reference

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
