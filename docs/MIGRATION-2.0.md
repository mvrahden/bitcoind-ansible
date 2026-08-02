# Migrating to 2.0

For downstream users upgrading from 1.x. Most playbooks need one small edit or
none at all; the sections below are ordered by how likely they are to affect you.

**The generated `bitcoin.conf` is semantically identical to 1.x** for every
combination of role variables, with a single exception documented under
[Behaviour changes](#behaviour-changes). This was verified by rendering both
templates across the default, regtest, onion, ZMQ, proxy, wallet and signet
configurations and comparing the effective settings, not just the text. Your
node will not silently start behaving differently.

**Expect one service restart.** The config file is rewritten in a new layout, so
the first 2.0 run restarts `bitcoind`. Nothing is lost — the daemon shuts down
cleanly and resumes from the chainstate — but schedule it if you care about
uptime windows. Subsequent runs make no changes.

---

## 1. Remove the builder key variables

If your playbook sets either of these, delete them:

```yaml
# Remove:
bitcoind_pgp_builders_pub_key_core: [...]
bitcoind_pgp_builders_pub_key_knots: [...]
```

They no longer do anything. Playbooks that still set them run fine and print a
warning.

**Why they went.** They pinned verification to specific named builders, but
attestation is voluntary and the signer set changes with every release. `laanwj`
stopped attesting after Core 30.2 and `shiny` is not on the current Knots
release, so on 1.x those defaults produced a bare HTTP 404 partway through any
attempt to install a current version. 2.0 instead requires a threshold of
signatures from a bundled set of trusted builders, which does not break when an
individual stops signing.

**If you were narrowing trust deliberately**, express the same intent with
fingerprints. Use the primary key fingerprints listed in
`files/builder-keys/<implementation>/MANIFEST`:

```yaml
bitcoind_gpg_trusted_fingerprints:
  - E777299FC265DD04793070EB944D35F9AC3DB76A  # fanquake
  - 152812300785C96444D3334D17565732E08E5E41  # achow101
bitcoind_gpg_min_valid_signatures: 2
```

Setting `bitcoind_gpg_min_valid_signatures` to `1` reproduces the weakest 1.x
behaviour, but the default of `3` is a materially stronger guarantee for the
same effort.

## 2. Move custom config into `bitcoind_config`

If you forked `templates/bitcoin.conf.j2` to set options the role did not
expose, you can almost certainly drop the fork:

```yaml
bitcoind_config:
  prune: 550
  dbcache: 2048
  maxconnections: 40
  blockfilterindex: true
  datacarriersize: 42        # Knots
```

`bitcoind_config` is applied last and overrides anything derived from the named
variables, so it can also change values the role sets itself. Booleans render as
`1`/`0`, lists render as repeated keys, and empty values are omitted.

Options that apply per-network — `bind`, `rpcbind`, `rpcport`, `addnode` — go in
`bitcoind_network_config` instead, and are emitted under the matching
`[section]` for any network other than `main`.

## 3. Check your target OS

Ubuntu 20.04 is no longer tested; its standard support ended in April 2025. The
role does not refuse to run on it, but nothing verifies it either.

Tested: Debian 12, Debian 13, Ubuntu 22.04, Ubuntu 24.04.

Non-Debian systems now fail immediately with a clear message rather than part
way through an `apt` task.

## 4. Nothing to do, but worth knowing

- **The systemd unit moves** from `/lib/systemd/system/` to
  `/etc/systemd/system/`. The role deletes the old copy on first run. If you
  wrote a drop-in override under `/etc/systemd/system/bitcoind-<net>.service.d/`
  it keeps working untouched.
- **`gpg-agent` is now installed** alongside `gpg`. `dirmngr` is no longer
  installed, because keys are bundled rather than fetched from a keyserver.
- **Installs no longer contact a keyserver or GitHub.** Only the release site is
  reached. Air-gapped and egress-restricted environments benefit.
- **`ansible.posix` is now declared** in `requirements.yml`. If you install this
  role through Galaxy, run `ansible-galaxy install -r requirements.yml`. On 1.x
  this dependency was undeclared and failed at runtime when
  `bitcoind_data_mount_device` was used.

---

## Behaviour changes

### `bitcoind_server: false` now takes effect

This is the one case where 2.0 renders a different configuration than 1.x.

1.x omitted the `server` line entirely when `bitcoind_server` was `false`. Since
`bitcoind` defaults `-server` to `1`, the RPC server stayed **enabled** — the
setting silently did nothing. 2.0 emits `server=0`, so it now does what it says.

If you set `bitcoind_server: false` and have been relying on RPC, you were
relying on a bug. Either remove the setting, or keep it and be aware RPC will
stop answering. The health check is skipped automatically when the RPC server is
disabled, so it will not fail your run.

Every other variable combination produces an identical effective configuration.

### `bitcoind_rpc_auth` is no longer required

1.x refused to run without a credential. 2.0 requires one only when RPC is
reachable from another host, meaning **both** a non-loopback `bitcoind_rpc_bind`
*and* a non-loopback entry in `bitcoind_rpc_allow_ips`. Either alone still leaves
RPC local.

Nothing to do if you already set it: the value is used exactly as before. But you
can now drop it for a loopback-only node, along with whatever generates and
stores it. Local clients — the health check, the `bitcoin-cli` wrapper, an
indexer such as electrs on the same host — authenticate with the cookie file
Bitcoin Core writes on every start. A cookie rotates on restart and leaves no
secret to store, rotate or leak.

If you expose RPC and leave the credential empty, the run now fails rather than
producing a node no remote client can authenticate to.

### Only the binaries a node needs are installed

1.x copied every binary in the release tarball into `/usr/local/bin`. 2.0 selects
by group through `bitcoind_install_binary_groups`, defaulting to `[node, cli]`:
`bitcoind` and `bitcoin-cli`, roughly 20 MB against 81 MB for Core 31.1 and
107.5 MB for Knots 29.3.

**On the first 2.0 run, the surplus is deleted from `/usr/local/bin`.** That is
the point — otherwise upgrading would leave dead weight behind forever — but it
means `bitcoin-tx`, `bitcoin-util`, `bitcoin`, `bitcoin-wallet`, `bitcoin-qt` and
`test_bitcoin` disappear unless you ask for them:

```yaml
bitcoind_install_binary_groups:
  - node
  - cli
  - tools     # bitcoin, bitcoin-tx, bitcoin-util
  - wallet    # bitcoin-wallet
```

Groups are `node`, `cli`, `wallet`, `tools`, `gui` and `test`. A group installs
whichever of its binaries the release actually ships, so the same setting works
for Core and Knots despite their differing binary sets. To pick individual
binaries instead, use `bitcoind_install_extra_binaries`; those must exist in the
release, and asking for one that does not fails the run with a list of what does.
A name no Bitcoin release is known to ship is flagged on every run, so a typo
does not wait for your next version bump to surface.

Note that `wallet` is not implied by setting `bitcoind_disablewallet: false`.
`bitcoin-wallet` is an *offline* tool for creating and repairing wallet files; a
node with the wallet enabled manages wallets over RPC and does not need it. Add
the group if you want the tool.

Removal is bounded to the binaries these groups name. Anything else you keep in
`/usr/local/bin` is left alone.

**`bitcoin-qt` could not run on a headless target anyway.** On a clean Debian 12
it fails to resolve `libfontconfig.so.1` and `libfreetype.so.6` for Core, and
seventeen libraries including the whole X11/xcb stack for Knots, while `bitcoind`
resolves everything it needs. What 1.x installed was a binary that would not
start. If you want it, add the `gui` group and install its libraries yourself —
the role will not:

```bash
# Core
apt install libfontconfig1 libfreetype6
# Knots additionally needs an X11/xcb stack
```

If you drop the `tools` group you also lose the `bitcoin` multiplexer, and with
it `bitcoin rpc`, `bitcoin node` and friends. Note that `bitcoin bench`,
`bitcoin chainstate`, `bitcoin test` and `bitcoin test-gui` already fail on an
unmodified official install, because those binaries are not in the tarball
either.

### An operator wrapper is installed

`/usr/local/bin/bitcoin-cli-<network>` is added, calling `bitcoin-cli` with this
node's data directory and configuration already supplied, so
`sudo bitcoin-cli-main getblockchaininfo` works with no flags. Set
`bitcoind_install_cli_wrapper: false` to skip it.

The role also links `<data_dir>/bitcoin.conf` to the managed `bitcoind.conf`. If
a regular file already exists at that path — likely if you adopted a
hand-configured node into this role — it is left alone and the run prints a
notice. Be aware that `bitcoin-cli` will then read your file rather than the
managed one.

### Stricter preflight validation

Playbooks that were quietly wrong now fail fast, before anything is installed:

| Condition | 1.x | 2.0 |
| --- | --- | --- |
| `prune` with `txindex` or `coinstatsindex` | daemon failed at startup with an opaque message | fails preflight, naming the conflict |
| Unsupported CPU architecture | installed x86_64 binaries regardless | fails, listing supported architectures |
| Non-Debian target | failed inside an `apt` task | fails immediately |
| `bitcoind_tor_enabled` without a Tor group | n/a | fails, explaining the Tor-side requirements |
| Release has no build for your architecture | failed on an empty checksum | fails, pointing at the release's `SHA256SUMS` |

None of these break a correct playbook. They convert late, confusing failures
into early, explicit ones.

### Handlers are flushed before the health check

The role now calls `meta: flush_handlers` before verifying the daemon over RPC,
so the health check tests the configuration that is actually running rather than
the one the daemon started with.

**Side effect worth knowing in multi-role plays:** `flush_handlers` flushes
*all* pending handlers in the play, not only this role's. If another role in the
same play has notified a handler before this role runs, that handler fires
earlier than it otherwise would. If that matters, run this role in its own play.

### Tor

`bitcoind_proxy` alone still routes outbound traffic through Tor and behaves as
before. It never published an onion address, because that additionally needs
access to Tor's control port, which the service account was never granted.

To publish an onion address, use the new option:

```yaml
bitcoind_tor_enabled: true
```

This wires up `proxy`, `listenonion` and `torcontrol`, and grants the service
control-cookie access through `SupplementaryGroups` in the unit. Tor must
already be running with `ControlPort 127.0.0.1:9051`, `CookieAuthentication 1`
and `CookieAuthFileGroupReadable 1`; the role does not install or configure Tor.
That last directive is easy to miss: without it Tor writes the cookie mode
`0600` and group membership does not help.

---

## New capabilities you may want

| Variable | Default | What it gives you |
| --- | --- | --- |
| `bitcoind_config` | `{}` | Any `bitcoin.conf` option, including `prune` |
| `bitcoind_network_config` | `{}` | Per-network options |
| `bitcoind_tor_enabled` | `false` | A working onion service |
| `bitcoind_health_check` | `true` | Fails the run if the daemon does not answer RPC |
| `bitcoind_rpc_wait_timeout` | `120` | How long to wait for it |
| `bitcoind_gpg_min_valid_signatures` | `3` | Verification strictness |
| `bitcoind_gpg_trusted_fingerprints` | `[]` | Narrow trust to specific builders |
| `bitcoind_gpg_allow_expired_keys` | `false` | Count signatures from expired keys |
| `bitcoind_no_log` | `true` | Set `false` to preview config changes with `--check --diff` |
| `bitcoind_install_binary_groups` | `[node, cli]` | Which binaries to install, by purpose |
| `bitcoind_install_extra_binaries` | `[]` | Individual binaries alongside the groups |
| `bitcoind_install_cli_wrapper` | `true` | `bitcoin-cli-<network>` needing no flags |
| `bitcoind_rpc_auth` | _(cookie auth)_ | Now optional for a loopback-only node |

## Verifying the upgrade

Run against one host first. A successful run ends with the daemon answering RPC,
because the health check is part of the play.

```bash
ansible-playbook -l one-node playbook.yml --diff
```

To see exactly what will change in `bitcoin.conf` before committing to it:

```bash
ansible-playbook -l one-node playbook.yml --check --diff -e bitcoind_no_log=false
```

That prints the rendered config, including the `rpcauth` hash if you set one, so
run it somewhere the output is not captured.

Note that 1.x could not do this at all. A check-mode run died on the first task
of the install block, because `--check` does not create the staging directory and
everything after it referenced a path that was never set. 2.0 reports what it
would download and install, then carries on, so the configuration diff is
actually reachable. The download, verification and binary install themselves are
still not simulated — there is no honest way to do so without performing them.

Afterwards, confirm the version and that the node is healthy:

```bash
bitcoind -version
sudo bitcoin-cli-main -getinfo   # or your network's name
```

## Rolling back

2.0 does not change anything on disk that 1.x cannot read: the data directory,
its layout, and the chainstate are untouched. To roll back, pin the role to your
previous version and re-run. The only cleanup is the systemd unit, which 2.0
moved — 1.x will write `/lib/systemd/system/bitcoind-<net>.service` again, so
remove the 2.0 copy so the two do not coexist:

```bash
rm -f /etc/systemd/system/bitcoind-<network>.service
systemctl daemon-reload
```

Two things to know before rolling back:

- **If you dropped `bitcoind_rpc_auth`**, put it back first. 1.x refuses to run
  without a credential, so a node you converted to cookie-only authentication
  will fail the first 1.x run. The daemon keeps working throughout; it is the
  playbook that stops.
- **A 1.x role is again unable to install any Bitcoin release newer than its
  pinned default**, which is the defect 2.0 exists to fix.
