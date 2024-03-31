# Bitcoin Core Ansible role

![GitHub Workflow Status (with branch)](https://img.shields.io/github/actions/workflow/status/mvrahden/bitcoind-ansible/ansible.yml?branch=main&label=Ansible%20Tests&logo=github&style=for-the-badge)

Ansible role to install the [Bitcoin Core](https://bitcoincore.org/en/about/) client as a `systemd` service. By default,
it uses sane defaults and some hardening measures for the Systemd service.

## Summary: What does it do?

- Sets up user, if not single user system
- Downloads bitcoin core and verifies signatures
- Installs all shipped binaries to `/usr/local/bin` (i.e. `bitcoin-cli`, `bitcoind`, ...)
- Sets up a systemd service with configuration at `/etc/bitcoind/<network>/bitcoind.conf`
- Links `/home/<user>/.bitcoin` to `/etc/bitcoind/<network>`

## Requirements

This role requires a user with `sudo` permissions to work properly.

List of officially supported operating systems:

| ID           | Name         | Status             |
|--------------|--------------|--------------------|
| `ubuntu2004` | Ubuntu 20.04 | :white_check_mark: |
| `ubuntu2204` | Ubuntu 22.04 | :white_check_mark: |

## How to run this?

Create a playbook like this one:

```yaml
- hosts: bitcoind
  roles:
    - role: mvrahden.bitcoind
      become: yes
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
molecule test
```

If you want to run a test through a specific operating system you can update the `MOLECULE_DISTRO` variable using
the operating system ID mentioned in the requirements table.

### Variables

You can change some variables to install this role to fit your needs. The default values to install the
Bitcoin node are the following ones:

| Name                | Value                |
|---------------------|----------------------|
| `bitcoind_user`      | `bitcoin`            |
| `bitcoind_group`     | `bitcoin`            |
| `bitcoind_version`   | `26.0`               |
| `bitcoind_arch`      | `x86_64-linux-gnu`   |

> If you want to install Bitcoin into a Raspberry you need to change the architecture to `aarch64-linux-gnu`.

To configure the Bitcoin node, you can use the following variables:

> Use [rpcauth.yp](https://raw.githubusercontent.com/bitcoin/bitcoin/master/share/rpcauth/rpcauth.py) to
> generate `rpcauth` credentials.

| Name                    | Value             | Note                                                 |
| ----------------------- | ----------------- | ---------------------------------------------------- |
| `bitcoind_data_dir`      | `/data/bitcoin`   |                                                      |
| `bitcoind_network`       | `main`            | Valid values are: `regtest`, `signet` and `test`     |
| `bitcoind_rpc_auth`      | `bitcoin:2e00...` | Prevent your password from being stored as cleartext |
| `bitcoind_rpc_user`      | `bitcoin`         | If possible use `btc_rpc_auth` instead               |
| `bitcoind_rpc_password`  | `bitcoin`         | If possible use `btc_rpc_auth` instead               |
| `bitcoind_zmq_host`      | `127.0.0.1`       |                                                      |
| `bitcoind_bind`          | `127.0.0.1`       |                                                      |
| `bitcoind_rpc_bind`      | `127.0.0.1`       | This is where to expose the RPC server               |
| `bitcoind_rpc_allow_ips` | `[127.0.0.1]`     | This can be an IP or a range like `10.0.0.0/24`      |
| `bitcoind_use_onion`     | `False`           | This enables onion support                           |
| `bitcoind_onion_proxy`   | `127.0.0.1:9050`  |                                                      |

### GPG verification

By default, this installer uses `gpg` to verify the integrity and signature of the downloaded artifacts. This
behaviour is controlled by the `bitcoind_pgp_builders_pub_key` field. The content of this structure and default values
are the following:

| Name         | ID                                           |
|--------------|----------------------------------------------|
| `laanwj`     | `71A3B16735405025D447E8F274810B012346C9A6`   |
| `fanquake`   | `E777299FC265DD04793070EB944D35F9AC3DB76A`   |

If you only want to verify with one user, you should use something like this:

```yaml
bitcoind_pgp_builders_pub_key:
  - id: 71A3B16735405025D447E8F274810B012346C9A6
    name: laanwj
```

> I use the Guix attestations to verify the release. The data can be found on
> the [Bitcoin Github official repository](https://github.com/bitcoin-core/guix.sigs).
> If the release can't be trusted the role will fail the installation.
