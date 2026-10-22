# Signing and releases

Master builds and tagged releases use
`acheronfail/dist-tools/actions/apple-release@v1` (ZIP/DMG support requires v1.2.0+)
for Developer ID signing, notarization and stapling. Pull requests and local
preview builds remain ad-hoc signed.

Both workflows build a universal app, check every Mach-O for `arm64` and
`x86_64`, and generate a nested signing plan from the bundled frameworks and
helpers. The shared Action signs children before containers while preserving
helper entitlements. Checksums are generated from the finalized ZIP and DMG.

## Apple credentials

Use the [dist-tools credential CLI](https://github.com/acheronfail/dist-tools/blob/v1/docs/credentials.md)
with `acheronfail/apptivator` in its repository allowlist. For team API keys,
sync these settings:

| Setting | Type |
| --- | --- |
| `MACOS_CODE_SIGN_P12_BASE64` | Secret |
| `MACOS_CODE_SIGN_P12_PASSWORD` | Secret |
| `APPLE_TEAM_ID` | Secret |
| `APPLE_NOTARY_API_KEY` | Secret |
| `APPLE_NOTARY_KEY_ID` | Secret |
| `APPLE_NOTARY_ISSUER_ID` | Secret |
| `APPLE_NOTARY_AUTH_MODE` = `api-team` | Variable |

Apple Account compatibility uses `APPLE_NOTARY_APPLE_ID` and
`APPLE_NOTARY_PASSWORD` with mode `apple-id` (the default).
The bundle identifier remains `com.acheronfail.apptivator`; the transition from
the previous self-signed certificate may require an Accessibility permission regrant.

## Sparkle update signing

`SPARKLE_PRIVATE_ED_KEY` signs the update archive and appcast. It is independent
of Apple credentials, and the sync CLI leaves it unchanged. Keep the existing
key paired with `SUPublicEDKey` in `Apptivator/Info.plist`. Appcast generation
verifies that they match before upload.

For setup or recovery, install the exported Sparkle key with:

```sh
gh secret set SPARKLE_PRIVATE_ED_KEY --repo acheronfail/apptivator \
  < /path/to/sparkle-private-key
```

See [Sparkle's setup guide](https://sparkle-project.org/documentation/) for a new
key pair. Forks need their own feed URL and repository mapping in the appcast script.

## Builds and publication

- `./scripts/build.sh`: build ad-hoc preview ZIP/DMG packages locally.
- `./scripts/build.sh --prepare-signing`: build the app and signing plan for CI.
- `./scripts/build.sh vX.Y.Z`: prepare a versioned app and signing plan for CI.

Master pushes and manual Build runs upload signed artifacts without publishing
a release. PRs upload ad-hoc previews. A valid `vX.Y.Z` tag triggers the existing
Release workflow, which generates the signed Sparkle feed, creates a complete
draft and then **publishes it as latest**.

Release assets remain:

- `Apptivator-<version>-universal.dmg`
- `Apptivator-<version>-universal.zip`
- `Apptivator-<version>-universal-SHA256SUMS.txt`
- `appcast.xml`

The first Sparkle-enabled build needs manual installation. Before publishing an
update, test install/relaunch and Accessibility permission retention across two
signed builds using a separate test feed. The public feed stays unchanged until
a release is published.
