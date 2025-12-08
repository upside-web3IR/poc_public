# 🔐 DeFi Security Incident PoC Collection

A comprehensive collection of Proof-of-Concept (PoC) implementations for various DeFi security incidents, built with Foundry.

---

## 📊 Incident Overview

| Incident                      | Vulnerability Type  | Loss Amount  | Researcher    | PoC Link                                |
| ----------------------------- | ------------------- | ------------ | ------------- | --------------------------------------- |
| **Abracadabra Spell**         | Logic Bug           | $1,700,000   | kyrie         | [PoC](./test/pocs/Abracadabra_V4)       |
| **Arcadia V2**                | Re-entrancy         | $2.5m        | kyrie         | [PoC](./test/pocs/Arcadia_V2)           |
| **Astera Fi**                 | Oracle Manipulation | $820,000     | kyrie, castle | [PoC](./test/pocs/AsteraFi)             |
| **Balancer**                  | Logic Bug           | $128,000,000 | kyrie         | [PoC](./test/pocs/Balancer)             |
| **BebopDEX**                  | Access Control      | $20,069      | kenny         | [PoC](./test/pocs/Bebop)                |
| **Bunni V2**                  | Logic Bug           | $8.4m        | castle        | [PoC](./test/pocs/Bunniv2)              |
| **Coinbase**                  | Misconfiguration    | $300k        | Muang         | [PoC](./test/pocs/Coinbase)             |
| **Cozy V2**                   | Logic Bug           | $427,000     | kyrie         | [PoC](./test/pocs/CozyFi_V2)            |
| **CreditX**                   | Control Hijacking   | $4.5m        | kenny         | [PoC](./test/pocs/CrediX)               |
| **Dexodus Finance**           | Logic Bug           | $300,000     | kyrie         | [PoC](./test/pocs/Dexodus)              |
| **GMX V1 Perps**              | Re-entrancy         | $42m         | kyrie         | [PoC](./test/pocs/GMX_V1)               |
| **Impermax V3**               | Logic Bug           | $380,000     | kyrie         | [PoC](./test/pocs/Impermax_V3)          |
| **Kame Aggregator**           | Logic Bug           | $3M          | castle        | [PoC](./test/pocs/Kame_Aggregator)      |
| **Kinto Bridge**              | Backdoor            | $1.55m       | Muang         | [PoC](./test/pocs/Kinto_Bridge)         |
| **MetaPool**                  | Access Control      | $25,000      | castle        | [PoC](./test/pocs/Metapool)             |
| **BigONE (NPM Supply Chain)** | Social Engineering  | $27m         | kyrie         | [PoC](./test/pocs/NpmSupplyChainAttack) |
| **Numa.money**                | Oracle Manipulation | $320,000     | Sori          | [PoC](./test/pocs/Numa)                 |
| **Peapods Finance**           | Oracle Manipulation | $175,000     | kyrie         | [PoC](./test/pocs/PeapodsFinance)       |
| **Resupply**                  | Oracle Manipulation | $9.6M        | kyrie         | [PoC](./test/pocs/ResupplyFi)           |
| **Sharwa Finance**            | Logic Bug           | $146,000     | castle        | [PoC](./test/pocs/SharwaFinance)        |
| **Silo Finance**              | Logic Bug           | $546,000     | kyrie         | [PoC](./test/pocs/SiloFinance)          |
| **SuperRare**                 | Access Control      | $730,000     | castle        | [PoC](./test/pocs/SuperRare)            |
| **SWAPP Staking**             | Logic Bug           | $32,196      | kenny         | [PoC](./test/pocs/Swapp)                |
| **WXC Token**                 | Logic Bug           | $39,000      | castle        | [PoC](./test/pocs/WXC_Token)            |

**Total Loss Amount**: ~$193M+

---

## 🔍 Vulnerability Categories

### 🐛 Logic Bug (13 incidents)

- Abracadabra Spell, Balancer, Bunni V2, Cozy V2, Dexodus Finance, Impermax V3, Kame Aggregator, Sharwa Finance, Silo Finance, SWAPP Staking, WXC Token

### 🔄 Oracle Manipulation (5 incidents)

- Astera Fi, Numa.money, Peapods Finance, Resupply

### 🔓 Access Control (3 incidents)

- BebopDEX, MetaPool, SuperRare

### 🔁 Re-entrancy (2 incidents)

- Arcadia V2, GMX V1 Perps

### 🎭 Other (3 incidents)

- Coinbase (Misconfiguration), CreditX (Control Hijacking), Kinto Bridge (Backdoor), BigONE (Social Engineering)

---

## 🛠️ Tech Stack

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## 📚 Documentation

https://book.getfoundry.sh/

---

## 🚀 Usage

### Build

```shell
$ forge build
```

### Test All PoCs

```shell
$ forge test
```

### Test Specific Incident

```shell
$ forge test --match-path test/pocs/Balancer/*.sol -vvv
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

---

## 📂 Project Structure

```
test/pocs/
├── Abracadabra_V4/      # Logic Bug - $1.7M
├── Arcadia_V2/          # Re-entrancy - $2.5M
├── AsteraFi/            # Oracle Manipulation - $820K
├── Balancer/            # Logic Bug - $128M
├── Bebop/               # Access Control - $20K
├── Bunniv2/             # Logic Bug - $8.4M
├── Coinbase/            # Misconfiguration - $300K
├── CozyFi_V2/           # Logic Bug - $427K
├── CrediX/              # Control Hijacking - $4.5M
├── Dexodus/             # Logic Bug - $300K
├── GMX_V1/              # Re-entrancy - $42M
├── Impermax_V3/         # Logic Bug - $380K
├── Kame_Aggregator/     # Logic Bug - $3M
├── Kinto_Bridge/        # Backdoor - $1.55M
├── Metapool/            # Access Control - $25K
├── NpmSupplyChainAttack/ # Social Engineering - $27M
├── Numa/                # Oracle Manipulation - $320K
├── PeapodsFinance/      # Oracle Manipulation - $175K
├── ResupplyFi/          # Oracle Manipulation - $9.6M
├── SharwaFinance/       # Logic Bug - $146K
├── SiloFinance/         # Logic Bug - $546K
├── SuperRare/           # Access Control - $730K
├── Swapp/               # Logic Bug - $32K
└── WXC_Token/           # Logic Bug - $39K
```

---

## 🎯 Key Learnings

### Logic Bug Prevention

- Always validate input parameters and edge cases
- Implement comprehensive unit tests for all state transitions
- Use formal verification for critical functions

### Oracle Manipulation Defense

- Use Time-Weighted Average Price (TWAP) oracles
- Implement multiple oracle sources with price deviation checks
- Add delay mechanisms for large price changes

### Access Control Best Practices

- Use OpenZeppelin's AccessControl or Ownable
- Implement role-based access control (RBAC)
- Always use modifiers for privileged functions

### Re-entrancy Protection

- Follow Checks-Effects-Interactions pattern
- Use ReentrancyGuard from OpenZeppelin
- Update state before external calls

---

## 👥 Contributors

- **kyrie**: Arcadia V2, Astera Fi, Balancer, Cozy V2, Dexodus, GMX V1, Impermax V3, BigONE, Peapods Finance, Resupply, Silo Finance, Abracadabra Spell
- **castle**: Astera Fi, Bunni V2, Kame Aggregator, MetaPool, Sharwa Finance, SuperRare, WXC Token
- **kenny**: BebopDEX, CreditX, SWAPP Staking
- **Muang**: Coinbase, Kinto Bridge
- **Sori**: Numa.money

---

## ⚠️ Disclaimer

This repository contains Proof-of-Concept code for educational and security research purposes only. The code demonstrates vulnerabilities found in real-world DeFi protocols.

**DO NOT** use this code for malicious purposes. The authors are not responsible for any misuse of the information or code provided in this repository.

---

## 📖 Additional Resources

- [Foundry Book](https://book.getfoundry.sh/)
- [Solidity Documentation](https://docs.soliditylang.org/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [Smart Contract Security Best Practices](https://consensys.github.io/smart-contract-best-practices/)

---

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Last Updated**: December 2025
