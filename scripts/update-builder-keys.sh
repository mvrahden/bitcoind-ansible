#!/usr/bin/env bash
#
# Regenerate the bundled builder public keys under files/builder-keys/.
#
# Provenance: keys are taken verbatim from the upstream guix.sigs repositories,
# which are the same source Bitcoin Core's own contrib/verify-binaries tooling
# points users at:
#
#   Core:  https://github.com/bitcoin-core/guix.sigs/tree/main/builder-keys
#   Knots: https://github.com/bitcoinknots/guix.sigs/tree/knots/builder-keys
#
# Keys are re-exported with --export-options export-minimal, which strips
# third-party certifications (which make some keys 80 KB+) while retaining the
# self-signatures and subkey binding signatures needed for verification.
#
# The role does not fetch keys at runtime, so this script is the only path by
# which the trust anchor changes. Review the resulting diff carefully.
#
# Usage: scripts/update-builder-keys.sh [core|knots|all]

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-all}"

fetch_impl() {
  local impl="$1" repo="$2" ref="$3"
  local outdir="${ROOT}/files/builder-keys/${impl}"
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp}"' RETURN

  echo "==> ${impl}: listing builder-keys from ${repo}@${ref}"
  local names
  names="$(curl -fsSL "https://api.github.com/repos/${repo}/contents/builder-keys?ref=${ref}" \
    | grep -o '"name": "[^"]*"' | sed 's/"name": "//;s/"//')"

  [ -n "${names}" ] || { echo "ERROR: no builder keys listed for ${impl}" >&2; return 1; }

  rm -rf "${outdir}"
  mkdir -p "${outdir}"

  local count=0
  for name in ${names}; do
    local builder="${name%.gpg}"
    curl -fsSL -o "${tmp}/${name}" \
      "https://raw.githubusercontent.com/${repo}/${ref}/builder-keys/${name}"

    # Import into a throwaway keyring, then re-export minimized so the bundled
    # file contains only what verification actually needs.
    local ring="${tmp}/ring-${builder}"
    mkdir -p "${ring}"
    chmod 700 "${ring}"
    gpg --homedir "${ring}" --batch --quiet --import "${tmp}/${name}" 2>/dev/null
    gpg --homedir "${ring}" --batch --quiet --armor \
        --export-options export-minimal --export > "${outdir}/${builder}.asc"
    gpgconf --homedir "${ring}" --kill gpg-agent >/dev/null 2>&1 || true

    [ -s "${outdir}/${builder}.asc" ] || {
      echo "ERROR: empty export for ${impl}/${builder}" >&2
      return 1
    }
    count=$((count + 1))
  done

  echo "==> ${impl}: wrote ${count} keys to files/builder-keys/${impl}/"
  du -sh "${outdir}" | awk '{print "    size: " $1}'
}

case "${TARGET}" in
  core)  fetch_impl core  bitcoin-core/guix.sigs  main ;;
  knots) fetch_impl knots bitcoinknots/guix.sigs  knots ;;
  all)
    fetch_impl core  bitcoin-core/guix.sigs  main
    fetch_impl knots bitcoinknots/guix.sigs  knots
    ;;
  *)
    echo "usage: $0 [core|knots|all]" >&2
    exit 2
    ;;
esac
