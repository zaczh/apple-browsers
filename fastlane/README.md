fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

### update_dependencies

```sh
[bundle exec] fastlane update_dependencies
```



----


## iOS

### ios sync_signing

```sh
[bundle exec] fastlane ios sync_signing
```

Fetches and updates certificates and provisioning profiles for App Store distribution

### ios sync_signing_adhoc

```sh
[bundle exec] fastlane ios sync_signing_adhoc
```

Fetches and updates certificates and provisioning profiles for Ad-Hoc distribution

### ios sync_signing_alpha

```sh
[bundle exec] fastlane ios sync_signing_alpha
```

Fetches and updates certificates and provisioning profiles for Alpha distribution

### ios sync_signing_alpha_adhoc

```sh
[bundle exec] fastlane ios sync_signing_alpha_adhoc
```

Fetches and updates certificates and provisioning profiles for Ad-Hoc distribution

### ios adhoc

```sh
[bundle exec] fastlane ios adhoc
```

Makes Ad-Hoc build with a specified name and alpha bundle ID in a given directory

### ios release_adhoc

```sh
[bundle exec] fastlane ios release_adhoc
```

Makes Ad-Hoc build with a specified name and release bundle ID in a given directory

### ios alpha_adhoc

```sh
[bundle exec] fastlane ios alpha_adhoc
```

Makes Ad-Hoc build for alpha with a specified name and alpha bundle ID in a given directory

### ios promote_latest_testflight_to_appstore

```sh
[bundle exec] fastlane ios promote_latest_testflight_to_appstore
```

Promotes the latest TestFlight build to App Store without submitting for review

### ios release_appstore

```sh
[bundle exec] fastlane ios release_appstore
```

Makes App Store release build and uploads it to App Store Connect

### ios upload_metadata

```sh
[bundle exec] fastlane ios upload_metadata
```

Updates App Store metadata

### ios release_testflight

```sh
[bundle exec] fastlane ios release_testflight
```

Makes App Store release build and uploads it to TestFlight

### ios release_alpha

```sh
[bundle exec] fastlane ios release_alpha
```

Makes Alpha release build and uploads it to TestFlight

### ios latest_build_number_for_version

```sh
[bundle exec] fastlane ios latest_build_number_for_version
```

Latest build number for version

### ios increment_build_number_for_version

```sh
[bundle exec] fastlane ios increment_build_number_for_version
```

Increment build number based on version in App Store Connect

----


## Mac

### mac sync_signing

```sh
[bundle exec] fastlane mac sync_signing
```

Fetches and updates certificates and provisioning profiles for App Store distribution

### mac sync_signing_dmg_release

```sh
[bundle exec] fastlane mac sync_signing_dmg_release
```

Fetches and updates certificates and provisioning profiles for DMG distribution

### mac sync_signing_dmg_review

```sh
[bundle exec] fastlane mac sync_signing_dmg_review
```

Fetches and updates certificates and provisioning profiles for DMG Review builds

### mac sync_signing_ci

```sh
[bundle exec] fastlane mac sync_signing_ci
```

Fetches and updates certificates and provisioning profiles for CI builds

### mac release_testflight

```sh
[bundle exec] fastlane mac release_testflight
```

Makes App Store release build and uploads it to TestFlight

### mac release_testflight_review

```sh
[bundle exec] fastlane mac release_testflight_review
```

Makes App Store release build and uploads it to TestFlight

### mac promote_latest_testflight_to_appstore

```sh
[bundle exec] fastlane mac promote_latest_testflight_to_appstore
```

Promotes the latest TestFlight build to App Store without submitting for review

### mac release_appstore

```sh
[bundle exec] fastlane mac release_appstore
```

Makes App Store release build and uploads it to App Store Connect

### mac upload_metadata

```sh
[bundle exec] fastlane mac upload_metadata
```

Updates App Store metadata

### mac make_release_branch

```sh
[bundle exec] fastlane mac make_release_branch
```

Executes the release preparation work in the repository

### mac code_freeze

```sh
[bundle exec] fastlane mac code_freeze
```

Executes the release preparation work in the repository

### mac bump_internal_release

```sh
[bundle exec] fastlane mac bump_internal_release
```

Prepares new internal release on top of an existing one

### mac prepare_hotfix

```sh
[bundle exec] fastlane mac prepare_hotfix
```

Executes the hotfix release preparation work in the repository

### mac update_embedded_files

```sh
[bundle exec] fastlane mac update_embedded_files
```

Updates embedded files and pushes to remote.

### mac set_version

```sh
[bundle exec] fastlane mac set_version
```

Executes the release preparation work in the repository

### mac create_keychain_ui_tests

```sh
[bundle exec] fastlane mac create_keychain_ui_tests
```

Creates a new Kechain to use on UI tests

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
