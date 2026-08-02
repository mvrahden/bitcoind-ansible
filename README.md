# Bitcoin Core / Knots Ansible role

![GitHub Workflow Status (with branch)](https://img.shields.io/github/actions/workflow/status/mvrahden/bitcoind-ansible/ansible.yml?branch=main&label=Ansible%20Tests&logo=github&style=for-the-badge)

Ansible role to install [Bitcoin Core](https://bitcoincore.org/en/about/) or
[Bitcoin Knots](https://bitcoinknots.org/) as a `systemd` service, with verified
binaries and a hardened unit.

## Summary: What does it do?

- Downloads the release and verifies it against a threshold of trusted builder signatures
- Installs the shipped binaries to `/usr/local/bin` (`bitcoind`, `bitcoin-cli`, ...)
- Creates a dedicated service account with a `nologin` shell
- Sets up a hardened systemd service with configuration at `<data_dir>/bitcoind.conf`
- Links `/home/<user>/.bitcoin` to `<data_dir>`
- Confirms the daemon answers over RPC before reporting success

## Requirements

A Debian-family target and a user with `sudo` permissions.

| ID           | Name         | Status             |
| ------------ | ------------ | ------------------ |
| `debian12`   | Debian 12    | :white_check_mark: |
| `debian13`   | Debian 13    | :white_check_mark: |
| `ubuntu2204` | Ubuntu 22.04 | :white_check_mark: |
| `ubuntu2404` | Ubuntu 24.04 | :white_check_mark: |

Install the collection this role depends on:

```bash
ansible-galaxy install -r requirements.yml
```

## How to run this?

`bitcoind_rpc_auth` is required. Generate it with
[rpcauth.py](https://raw.githubusercontent.com/bitcoin/bitcoin/master/share/rpcauth/rpcauth.py)
and pass the value after `rpcauth=`.

### Bitcoin Core (default)

```yaml
- hosts: bitcoind
  become: yes
  vars:
    bitcoind_rpc_auth: "alice:f7efda5c189b...$d5b51b3beffbc02b..."
  roles:
    - role: mvrahden.bitcoind
```

### Bitcoin Knots

```yaml
- hosts: bitcoind
  become: yes
  vars:
    bitcoind_implementation: knots
    bitcoind_version: "29.3.knots20260508"
    bitcoind_rpc_auth: "alice:f7efda5c189b...$d5b51b3beffbc02b..."
  roles:
    - role: mvrahden.bitcoind
```

Architecture is detected automatically, so a Raspberry Pi needs no special
handling. Set `bitcoind_arch` only to override detection, for example when
building for a different target than the host.

## Configuration

The role exposes the common options as named variables. **Anything else goes in
`bitcoind_config`**, which is applied last and overrides the named variables.
This reaches every `bitcoin.conf` option, so you never need to fork the role to
set one.

```yaml
bitcoind_config:
  prune: 550
  dbcache: 2048
  maxconnections: 40
  blockfilterindex: true
  uacomment: my-node
```

Booleans render as `1`/`0`, lists render as repeated keys, and empty values are
omitted. Every key is emitted exactly once.

### Use-case examples

The defaults give a minimal-surface full node. Enable what you need:

**Pruned node** (smallest disk footprint; incompatible with the indexes)

```yaml
bitcoind_txindex: false
bitcoind_config:
  prune: 550
```

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

**Tor**

Routes traffic through Tor and publishes an onion address. Requires a running
Tor daemon with `ControlPort 9051` and `CookieAuthentication 1`; the role does
not install or configure Tor.

```yaml
bitcoind_tor_enabled: true
bitcoind_use_onion: true   # optional: reach *only* onion peers
```

**On-node wallet**

```yaml
bitcoind_disablewallet: false
```

### Variables

| Name                      | Default              | Note                                |
| ------------------------- | -------------------- | ----------------------------------- |
| `bitcoind_implementation` | `core`               | `core` or `knots`                   |
| `bitcoind_version`        | `31.1`               | Knots example: `29.3.knots20260508` |
| `bitcoind_user`           | `bitcoin`            |                                     |
| `bitcoind_group`          | `bitcoin`            |                                     |
| `bitcoind_arch`           | _(auto-detected)_    | Override for cross-platform deploys |

Node configuration:

| Name                          | Default         | Note                                                  |
| ----------------------------- | --------------- | ----------------------------------------------------- |
| `bitcoind_config`             | `{}`            | **Any `bitcoin.conf` option; overrides the below**    |
| `bitcoind_network_config`     | `{}`            | Options scoped to the active network                  |
| `bitcoind_data_dir`           | `/data/bitcoin` |                                                       |
| `bitcoind_network`            | `main`          | Valid values are: `main`, `regtest`, `signet`, `test` |
| `bitcoind_server`             | `true`          | Enable JSON-RPC server                                |
| `bitcoind_disablewallet`      | `true`          | Disable wallet (enable only if needed)                |
| `bitcoind_txindex`            | `true`          | Maintain full transaction index                       |
| `bitcoind_listen`             | `true`          | Listen for incoming peer connections                  |
| `bitcoind_whitelist`          | `127.0.0.1`     | Whitelist address (empty to disable)                  |
| `bitcoind_rpc_auth`           | _(required)_    | Generate with `rpcauth.py`                            |
| `bitcoind_rpc_bind`           | `127.0.0.1`     | Address to expose the RPC server                      |
| `bitcoind_rpc_port`           | `8332`          |                                                       |
| `bitcoind_rpc_allow_ips`      | `[127.0.0.1]`   | IP or range like `10.0.0.0/24`                        |
| `bitcoind_bind`               | `127.0.0.1`     |                                                       |
| `bitcoind_enable_zmq`         | `false`         | Enable ZMQ pub/sub endpoints                          |
| `bitcoind_zmq_host`           | `127.0.0.1`     |                                                       |
| `bitcoind_zmq_port_rawblock`  | `28332`         |                                                       |
| `bitcoind_zmq_port_rawtx`     | `28333`         |                                                       |
| `bitcoind_zmq_port_hashblock` | `28332`         |                                                       |
| `bitcoind_proxy`              |                 | SOCKS5 proxy (e.g. `127.0.0.1:9050`)                  |
| `bitcoind_use_onion`          | `false`         | Restrict to onion network only                        |
| `bitcoind_nodes`              | `[]`            | Peers to add via `addnode=`                           |
| `bitcoind_health_check`       | `true`          | Confirm RPC responds after start                      |
| `bitcoind_rpc_wait_timeout`   | `120`           | Seconds to wait for RPC                               |

Tor:

| Name                         | Default           | Note                                    |
| ---------------------------- | ----------------- | --------------------------------------- |
| `bitcoind_tor_enabled`       | `false`           | Wire up proxy, `listenonion`, control   |
| `bitcoind_tor_proxy`         | `127.0.0.1:9050`  |                                         |
| `bitcoind_tor_control`       | `127.0.0.1:9051`  |                                         |
| `bitcoind_tor_control_group` | `debian-tor`      | Group owning Tor's control cookie       |

Verification:

| Name                                | Default | Note                                            |
| ----------------------------------- | ------- | ----------------------------------------------- |
| `bitcoind_gpg_min_valid_signatures` | `3`     | Distinct trusted signatures required            |
| `bitcoind_gpg_trusted_fingerprints` | `[]`    | Empty trusts all bundled keys                   |
| `bitcoind_gpg_allow_expired_keys`   | `false` | Count signatures from since-expired keys        |
| `bitcoind_skip_gpg_verification`    | `false` | Bypass verification entirely (discouraged)      |

## Binary verification

Bitcoin releases are signed by a number of builders who independently reproduce
the build and attest to identical hashes. The role downloads `SHA256SUMS` and
`SHA256SUMS.asc`, verifies the signatures against the builder keys bundled in
`files/builder-keys/`, and installs only if at least
`bitcoind_gpg_min_valid_signatures` distinct trusted builders signed it. The
binary is then checked against the checksum from that verified file.

Signatures from revoked keys, and checksum files that fail verification outright,
abort the install regardless of how many other signatures are good. Signatures
from since-expired keys are reported but do not count toward the threshold unless
`bitcoind_gpg_allow_expired_keys` is set.

The default of 3 matches Bitcoin Core's own
[`contrib/verify-binaries`](https://github.com/bitcoin/bitcoin/tree/master/contrib/verify-binaries)
tooling. Requiring a threshold rather than specific named signers matters:
attestation is voluntary, and which builders sign changes from release to
release.

Keys come from the upstream
[Core](https://github.com/bitcoin-core/guix.sigs/tree/main/builder-keys) and
[Knots](https://github.com/bitcoinknots/guix.sigs/tree/knots/builder-keys)
guix.sigs repositories and are bundled rather than fetched at install time, so a
blocked or unavailable keyserver cannot break a deploy. Refresh them with:

```bash
scripts/update-builder-keys.sh
```

To trust only specific builders, list their primary key fingerprints:

```yaml
bitcoind_gpg_trusted_fingerprints:
  - E777299FC265DD04793070EB944D35F9AC3DB76A  # fanquake
bitcoind_gpg_min_valid_signatures: 1
```

## Upgrading

Change `bitcoind_version` and re-run. The role tracks the installed version in a
cookie file in the data directory, stops the service, swaps the binaries, and
restarts. Runs where the version is unchanged make no changes at all.

## Testing

Tests run with `molecule` in Docker:

```bash
make test                                                                    # Core, Debian 12
make test DISTRO=debian13 BITCOIND_IMPL=knots BITCOIND_VERSION=29.3.knots20260508
make test SCENARIO=upgrade BITCOIND_VERSION_FROM=31.0 BITCOIND_VERSION_TO=31.1
make lint
```

Use any ID from the requirements table as `DISTRO`.

## Migrating from 1.x

`bitcoind_pgp_builders_pub_key_core` and `bitcoind_pgp_builders_pub_key_knots`
no longer exist. Playbooks setting them keep working and emit a warning; remove
them. If you were narrowing trust to specific builders, express that with
`bitcoind_gpg_trusted_fingerprints` and `bitcoind_gpg_min_valid_signatures`.

If you customised `bitcoin.conf` by forking the template, most of it can move
into `bitcoind_config` instead.

See [CHANGELOG.md](CHANGELOG.md) for the full list.
