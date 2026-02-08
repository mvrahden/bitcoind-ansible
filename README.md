# Bitcoin Core / Knots Ansible role

![GitHub Workflow Status (with branch)](https://img.shields.io/github/actions/workflow/status/mvrahden/bitcoind-ansible/ansible.yml?branch=main&label=Ansible%20Tests&logo=github&style=for-the-badge)

Ansible role to install [Bitcoin Core](https://bitcoincore.org/en/about/) or [Bitcoin Knots](https://bitcoinknots.org/) as a `systemd` service. By default,
it uses sane defaults and some hardening measures for the Systemd service.

## Summary: What does it do?

- Sets up user, if not single user system
- Downloads bitcoin binaries and verifies GPG signatures
- Installs all shipped binaries to `/usr/local/bin` (i.e. `bitcoin-cli`, `bitcoind`, ...)
- Sets up a systemd service with configuration at `<data_dir>/bitcoind.conf`
- Links `/home/<user>/.bitcoin` to `<data_dir>`

## Requirements

This role requires a user with `sudo` permissions to work properly.

List of officially supported operating systems:

| ID           | Name         | Status             |
| ------------ | ------------ | ------------------ |
| `ubuntu2004` | Ubuntu 20.04 | :white_check_mark: |
| `ubuntu2204` | Ubuntu 22.04 | :white_check_mark: |

## How to run this?

### Bitcoin Core (default)

```yaml
- hosts: bitcoind
  become: yes
  roles:
    - role: mvrahden.bitcoind
```

### Bitcoin Knots

```yaml
- hosts: bitcoind
  become: yes
  vars:
    bitcoind_implementation: knots
    bitcoind_version: "29.2.knots20251110"
  roles:
    - role: mvrahden.bitcoind
```

Note that you can use `become` at a global level instead at the role level.
If you want to install the Bitcoin node into a Raspberry Pi, just change the architecture:

```yaml
- hosts: bitcoind
  become: yes
  vars:
    bitcoind_arch: aarch64-linux-gnu
  roles:
    - role: mvrahden.bitcoind
```

### Testing

You can execute tests using `molecule`. Install the [`requirements.txt`](molecule) file depending on if you want
to execute tests through Docker or with a VM managed by Vagrant.

```bash
make test                                                              # Core (default)
BITCOIND_IMPL=knots BITCOIND_VERSION=29.2.knots20251110 make test      # Knots
```

If you want to run a test through a specific operating system you can update the `DISTRO` variable using
the operating system ID mentioned in the requirements table.

### Variables

You can change some variables to install this role to fit your needs. The default values to install the
Bitcoin node are the following ones:

| Name                      | Value              | Note                                    |
| ------------------------- | ------------------ | --------------------------------------- |
| `bitcoind_implementation` | `core`             | `core` or `knots`                       |
| `bitcoind_version`        | `30.2`             | Knots example: `29.2.knots20251110`     |
| `bitcoind_user`           | `bitcoin`          |                                         |
| `bitcoind_group`          | `bitcoin`          |                                         |
| `bitcoind_arch`           | _(auto-detected)_  | Override for cross-platform deploys     |

> Architecture is auto-detected from `ansible_architecture`. Override with e.g. `aarch64-linux-gnu` for Raspberry Pi.

To configure the Bitcoin node, you can use the following variables:

> Use [rpcauth.py](https://raw.githubusercontent.com/bitcoin/bitcoin/master/share/rpcauth/rpcauth.py) to
> generate `rpcauth` credentials.

| Name                          | Value           | Note                                                  |
| ----------------------------- | --------------- | ----------------------------------------------------- |
| `bitcoind_data_dir`           | `/data/bitcoin` |                                                       |
| `bitcoind_network`            | `main`          | Valid values are: `main`, `regtest`, `signet`, `test` |
| `bitcoind_server`             | `true`          | Enable JSON-RPC server                                |
| `bitcoind_disablewallet`      | `true`          | Disable wallet (enable only if needed)                |
| `bitcoind_txindex`            | `true`          | Maintain full transaction index                       |
| `bitcoind_listen`             | `true`          | Listen for incoming peer connections                  |
| `bitcoind_whitelist`          | `127.0.0.1`     | Whitelist address (empty to disable)                  |
| `bitcoind_rpc_auth`           |                 | Required. Generate with `rpcauth.py`                  |
| `bitcoind_rpc_bind`           | `127.0.0.1`     | Address to expose the RPC server                      |
| `bitcoind_rpc_port`           | `8332`          |                                                       |
| `bitcoind_rpc_allow_ips`      | `[127.0.0.1]`   | IP or range like `10.0.0.0/24`                        |
| `bitcoind_bind`               | `127.0.0.1`     |                                                       |
| `bitcoind_enable_zmq`         | `false`         | Enable ZMQ pub/sub endpoints                          |
| `bitcoind_zmq_host`           | `127.0.0.1`     |                                                       |
| `bitcoind_zmq_port_rawblock`  | `28332`         |                                                       |
| `bitcoind_zmq_port_rawtx`     | `28333`         |                                                       |
| `bitcoind_zmq_port_hashblock` | `28332`         |                                                       |
| `bitcoind_proxy`              |                 | SOCKS5 proxy (e.g. `127.0.0.1:9050` for Tor)          |
| `bitcoind_use_onion`          | `false`         | Restrict to onion network only                        |
| `bitcoind_nodes`              | `[]`            | Peers to add via `addnode=`                           |

### Use-case examples

The defaults provide a minimal-surface full node. Enable additional features as needed:

**Lightning node (LND / CLN)**

```yaml
bitcoind_enable_zmq: true
bitcoind_txindex: false  # not needed for Lightning
```

**Block explorer / Electrum server (Electrs / Fulcrum / mempool.space)**

```yaml
bitcoind_enable_zmq: true  # required for real-time block notifications
bitcoind_txindex: true     # required for address lookups
```

**Tor-only (requires a running Tor daemon)**

```yaml
bitcoind_proxy: "127.0.0.1:9050"
bitcoind_use_onion: true
```

**On-node wallet**

```yaml
bitcoind_disablewallet: false
```

### GPG verification

By default, this installer uses `gpg` to verify the integrity and signature of the downloaded artifacts.
The role selects the appropriate GPG builder keys based on `bitcoind_implementation`.

**Bitcoin Core** default keys (`bitcoind_pgp_builders_pub_key_core`):

| Name       | ID                                         |
| ---------- | ------------------------------------------ |
| `laanwj`   | `71A3B16735405025D447E8F274810B012346C9A6` |
| `fanquake` | `E777299FC265DD04793070EB944D35F9AC3DB76A` |

**Bitcoin Knots** default keys (`bitcoind_pgp_builders_pub_key_knots`):

| Name      | ID                                         |
| --------- | ------------------------------------------ |
| `luke-jr` | `1A3E761F19D2CC7785C5502EA291A2C45D0C504A` |
| `shiny`   | `1D70CBE4B42239445617D33DD316C8140185B647` |

If you only want to verify with one user, you can override the list for the respective implementation:

```yaml
bitcoind_pgp_builders_pub_key_core:
  - id: 71A3B16735405025D447E8F274810B012346C9A6
    name: laanwj
```

> Guix attestations are used to verify each release. The data can be found in the
> [Bitcoin Core](https://github.com/bitcoin-core/guix.sigs) or
> [Bitcoin Knots](https://github.com/bitcoinknots/guix.sigs) guix.sigs repositories.
> If the release can't be trusted the role will fail the installation.
