# Bitcoin Core Ansible role

![GitHub Workflow Status (with branch)](https://img.shields.io/github/actions/workflow/status/fooock/bitcoind-ansible/ansible.yml?branch=main&label=Ansible%20Tests&logo=github&style=for-the-badge)

Ansible role to install the [Bitcoin Core](https://bitcoincore.org/en/about/) client as a `systemd` service. By default,
it uses sane defaults and some hardening measures for the Systemd service.

By default, all binaries are installed inside `/usr/local/bitcoin-core-<version>/bin` directory. So for example, if you
are installing the version `23.0`, if you want to invoke the `bitcoin-cli` binary, you will need to
use `/usr/local/bitcoin-core-23.0/bin/bitcoin-cli`. Note this is the case for the rest of the binaries from Bitcoin.

Usually, you don't need the absolute binary path since this role creates a symbolic link
to `/home/<user>/.bitcoin`. Using absolute routes is only useful when doing updates to the binary and a rollback is
required
or to using a specific binary version to execute an operation.

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
    - role: fooock.bitcoind
      become: yes
```

Note that you can use `become` at a global level instead at the role level.
If you want to install the Bitcoin node into a Raspberry Pi, just change the architecture:

```yaml
- hosts: bitcoind
  become: yes
  vars:
    bitcoin_arch: aarch64-linux-gnu
  roles:
    - role: fooock.bitcoind
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
| `bitcoin_user`      | `bitcoin`            |
| `bitcoin_group`     | `bitcoin`            |
| `bitcoin_version`   | `26.0`               |
| `bitcoin_arch`      | `x86_64-linux-gnu`   |

> If you want to install Bitcoin into a Raspberry you need to change the architecture to `aarch64-linux-gnu`.

To configure the Bitcoin node, you can use the following variables:

| Name                         | Value             | Note                                               |
|------------------------------|-------------------|----------------------------------------------------|
| `bitcoin_data_dir`           | `/data/bitcoin`   |                                                    |
| `bitcoin_network`            | `main`            | Valid values are: `regtest`, `signet` and `test`   |
| `bitcoin_rpc_user`           | `bitcoin`         |                                                    |
| `bitcoin_rpc_password`       | `bitcoin`         |                                                    |
| `bitcoin_zmq_host`           | `127.0.0.1`       |                                                    |
| `bitcoin_bind`               | `127.0.0.1`       |                                                    |
| `bitcoin_rpc_bind`           | `127.0.0.1`       | This is where to expose the RPC server             |
| `bitcoin_rpc_allow_ip`       | `127.0.0.1`       | This can be an IP or a range like `10.0.0.0/24`    |

### GPG verification

By default, this installer uses `gpg` to verify the integrity and signature of the downloaded artifacts. This
behaviour is controlled by the `bitcoin_pgp_builders_pub_key` field. The content of this structure and default values
are the following:

| Name         | ID                                           |
|--------------|----------------------------------------------|
| `laanwj`     | `71A3B16735405025D447E8F274810B012346C9A6`   |
| `fanquake`   | `E777299FC265DD04793070EB944D35F9AC3DB76A`   |

If you only want to verify with one user, you should use something like this:

```yaml
bitcoin_pgp_builders_pub_key:
  - id: 71A3B16735405025D447E8F274810B012346C9A6
    name: laanwj
```

> I use the Guix attestations to verify the release. The data can be found on
> the [Bitcoin Github official repository](https://github.com/bitcoin-core/guix.sigs).
> If the release can't be trusted the role will fail the installation.
