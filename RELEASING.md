# Signing and releases

Apptivator uses a dedicated, long-lived self-signed certificate and this explicit
code-signing designated requirement:

```text
designated => anchor = H"<certificate SHA-1 fingerprint>" and identifier "com.acheronfail.apptivator"
```

The certificate and bundle identifier stay the same across builds, rather than
using each build's ad-hoc identity. This is intended to preserve macOS Accessibility
permission across updates. Moving from an old signature to the first release with
this identity may require one more Accessibility grant. Losing or replacing the
certificate changes the identity and can require another grant.

This approach does not provide Developer ID signing or notarization. No Apple
Developer account or Apple signing secrets are needed. See Apple's
[code-signing identity documentation](https://developer.apple.com/library/archive/technotes/tn2206/)
for how designated requirements identify updated code.

## 1. Create the identity once (files only; no keychain changes)

Use a dedicated Apptivator certificate, not another app's private signing key.
On a trusted machine with OpenSSL 3, run the following from this repository:

```bash
./scripts/create-code-signing-identity.sh /private/tmp/apptivator-code-signing.p12
```

If the default `openssl` is Apple's LibreSSL, point the script to an existing
OpenSSL 3 installation:

```bash
OPENSSL_BIN="$(brew --prefix openssl@3)/bin/openssl" \
  ./scripts/create-code-signing-identity.sh /private/tmp/apptivator-code-signing.p12
```

The script asks for a password twice, then creates a password-protected PKCS#12
file containing a 20-year certificate named **Apptivator Code Signing** and its
private key. It uses OpenSSL files only: it does not access the macOS keychain,
import an identity, change trust settings, or build the app. It refuses to write
inside this repository or overwrite an existing file.

Back up the `.p12` file and its password in your password/secrets manager. Reuse
this exact file for every release; do not generate a new identity on each run.

## 2. Add two GitHub repository secrets

Open [Apptivator → Settings → Secrets and variables → Actions](https://github.com/acheronfail/apptivator/settings/secrets/actions).
Choose **New repository secret** for each of these:

| Secret | Value |
| --- | --- |
| `MACOS_CODE_SIGN_P12_BASE64` | Base64-encoded contents of the `.p12` file, including its private key |
| `MACOS_CODE_SIGN_P12_PASSWORD` | The password you chose when creating that file |

To copy the first value without printing it into terminal logs:

```bash
/usr/bin/base64 -i /private/tmp/apptivator-code-signing.p12 | pbcopy
```

Paste it into `MACOS_CODE_SIGN_P12_BASE64`, save it, then add the password as
`MACOS_CODE_SIGN_P12_PASSWORD`. These must be **Secrets**, not repository Variables.
There is no identity-name, keychain-password, Apple team ID, or fingerprint secret
to configure: CI derives the fingerprint from the certificate and generates a
temporary keychain password for each run. `GITHUB_TOKEN` is supplied automatically.

After confirming your backup and saving both secrets, remove the temporary `.p12`
file and clear the clipboard. Do not paste either secret into chat or commit it.
GitHub's [secrets documentation](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets)
explains storage and fork-PR restrictions.

## 3. Run CI

Configure the Sparkle keys below before running signed builds.

Once this branch is merged, a push to `master` signs the Build workflow's app using
that identity. You can also use **Actions → Build → Run workflow** and select the
branch to test it after the secrets are set. Signed runs fail when secrets are
missing; they do not silently publish ad-hoc artifacts.

Pull-request builds test and package an ad-hoc preview without receiving either
signing secret. Installing a PR preview over a signed release changes its identity;
use master/release artifacts for normal updates.

To publish a release:

```bash
git tag v1.7.0
git push origin v1.7.0
```

Both production workflows import the identity into a temporary keychain **only on
a GitHub-hosted macOS runner**, sign the archived universal app with its explicit
requirement, verify that requirement, and package the signed app. The wrapper
removes the temporary keychain and private files on exit and attempts to remove
certificate trust. Cleanup calls are time-limited because macOS security services
can stall; the disposable hosted VM is discarded after the job. The wrapper
refuses to run on a local developer machine.

Every release uploads these four files:

- `Apptivator-<version>-universal.dmg`
- `Apptivator-<version>-universal.zip`
- `Apptivator-<version>-universal-SHA256SUMS.txt`
- `appcast.xml` (signed Sparkle update feed)

The checksum manifest covers the DMG and app ZIP. No `*-dSYMs.zip` is generated or
published. Upload paths explicitly allow only these package files and the appcast.

## Sparkle update signing (one-time setup)

Sparkle 2.9.6 checks the signed feed at
`https://github.com/acheronfail/apptivator/releases/latest/download/appcast.xml`.
GitHub Releases hosts everything; no GitHub Pages site or separate server is
needed. Updates use the existing universal ZIP, with an Ed25519 signature in the
appcast. The feed is also signed and verified before it is used. These signatures
are separate from the macOS code-signing identity described above.

After resolving packages, generate a dedicated key using Sparkle's official tool:

```bash
xcodebuild -resolvePackageDependencies -project Apptivator.xcodeproj \
  -scheme Apptivator -clonedSourcePackagesDirPath build/SourcePackages
build/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys --account apptivator
```

This stores a new private key in your login Keychain and prints its public key.
Set the public key as `SUPublicEDKey` in `Apptivator/Info.plist` and commit it.
The build script validates this embedded public key before signed builds.
Export the private key to a temporary file, then upload it as a repository secret:

```bash
umask 077
build/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys \
  --account apptivator -x /private/tmp/apptivator-sparkle-private-key
gh secret set SPARKLE_PRIVATE_ED_KEY < /private/tmp/apptivator-sparkle-private-key
```

Back up the exported private key in your password/secrets manager before deleting
the temporary file. Keep the same key for every release. Never put it in the
repository, a release, a command-line argument, or logs. CI passes it to Sparkle
through standard input, without importing it into a keychain. Signed builds fail
if the public key is absent or malformed; release publication also fails if the
private key is absent or does not match the embedded public key.

The Release workflow generates and validates `appcast.xml`, uploads it alongside
the ZIP, DMG, and checksum manifest to a draft, then publishes the complete draft
as the latest release. Release jobs are serialized. Publish tags in increasing
version order; do not mark older releases or releases without an appcast as
latest. If publishing fails after draft creation, inspect/delete that draft
before rerunning the job. GitHub's latest-release redirect must remain publicly
accessible; forks must change the feed URL and publishing script to their repo.

The feed contains only the current full ZIP (no delta updates). If the minimum
supported macOS version changes, preserve compatible older items in the feed
before release so users on older systems can still find their last supported
update. Release assets and the appcast must remain byte-for-byte unchanged after
signing. The checksum manifest covers the packages; the appcast has its own
embedded cryptographic signature.

Debug builds keep the updater disabled. Configured
Release builds offer **Check for Updates…** in the menu and Sparkle's standard
permission prompt for automatic checks. CI build numbers use seconds since 2020,
shared across both workflows, rather than unrelated workflow run counters.

The first Sparkle-enabled version must be installed manually. For an end-to-end
smoke test, install that signed build in `/Applications`, publish a newer version,
choose **Check for Updates…**, and confirm the update installs, relaunches, retains
shortcuts, and preserves Accessibility access. Local build/signature validation
does not substitute for this two-release test. Sparkle does not add Developer ID
signing or notarization; the distribution limitations above still apply.

See [Sparkle setup](https://sparkle-project.org/documentation/) and
[publishing updates](https://sparkle-project.org/documentation/publishing/).
