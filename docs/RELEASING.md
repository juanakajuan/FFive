# Releasing to TestFlight

`scripts/release-testflight.sh` archives the committed HEAD in Release, stamps a UTC timestamp build number (for example `202611030008`), and uploads it to App Store Connect. The build shows up in TestFlight after Apple finishes processing, usually 5 to 30 minutes.

```sh
scripts/release-testflight.sh           # archive and upload
scripts/release-testflight.sh --local   # archive and export an .ipa to build/release, no upload
```

The script refuses to run on a dirty tree, so every build maps to a commit. Logs and archives land in `build/release/` (gitignored).

## One-time setup

1. Enroll the Apple ID behind team `DEVELOPMENT_TEAM` in the [Apple Developer Program](https://developer.apple.com/programs/enroll/). A free Personal Team can archive but cannot create App Store provisioning profiles, so export fails with `does not have permission to create "iOS App Store" provisioning profiles`. If enrollment gives you a new team ID, update `DEVELOPMENT_TEAM` in the project. The script reads it from there.
2. In [App Store Connect](https://appstoreconnect.apple.com), create an app under Apps > + > New App with bundle ID `com.juanix.FFive`.
3. Pick an auth method:
   - Apple ID: sign in under Xcode > Settings > Accounts. Nothing else to set.
   - API key, for headless runs: create a key under Users and Access > Integrations > App Store Connect API with the App Manager role. Save the `.p8` to `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8`, then export `ASC_KEY_ID` and `ASC_ISSUER_ID` before running the script. Set `ASC_KEY_PATH` if the key lives elsewhere.
4. In TestFlight, add yourself to an internal testing group so builds install through the TestFlight app.

## Shipping a new version

The build number moves on its own. To ship a new user-facing version, bump `MARKETING_VERSION` in the FFive target (Debug and Release), commit, and run the script.

The app declares `ITSAppUsesNonExemptEncryption = NO` because it has no networking or crypto. Revisit that if either is added, or TestFlight will hold builds for export compliance.
