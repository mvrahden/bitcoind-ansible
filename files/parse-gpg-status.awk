# Reduce `gpg --status-fd=1 --verify` output to one line per signature:
#
#   GOOD    <primary-key-fingerprint>
#   EXPIRED <primary-key-fingerprint>
#   REVOKED <primary-key-fingerprint>
#   BAD     <key-id>
#
# Signatures from keys outside the trusted keyring produce ERRSIG/NO_PUBKEY and
# are deliberately dropped: a release is normally signed by more builders than
# any one operator trusts, and those signatures neither help nor harm.
#
# GnuPG emits a per-signature block in which the GOODSIG/EXPKEYSIG/REVKEYSIG
# line always precedes the VALIDSIG line carrying the fingerprints, so the
# classification is carried forward on `st` and consumed at VALIDSIG.
#
# VALIDSIG field 3 is the *signing* key fingerprint and the final field is the
# *primary* key fingerprint. These differ whenever a builder signs with a
# subkey (fanquake does), and it is the primary fingerprint that identifies the
# builder, so the final field is what gets reported.
#
# BADSIG has no accompanying VALIDSIG and is therefore reported immediately.

/^\[GNUPG:\] GOODSIG /    { st = "GOOD";    next }
/^\[GNUPG:\] EXPKEYSIG /  { st = "EXPIRED"; next }
/^\[GNUPG:\] REVKEYSIG /  { st = "REVOKED"; next }
/^\[GNUPG:\] BADSIG /     { print "BAD " $3; st = ""; next }
/^\[GNUPG:\] ERRSIG /     { st = ""; next }
/^\[GNUPG:\] VALIDSIG /   { if (st != "") print st " " $NF; st = ""; next }
