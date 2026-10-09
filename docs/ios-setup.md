# iOS setup

One-time steps to get Next Game onto your phone through TestFlight. Run them in order from the repo root. Nothing here is automated, because each step touches the Apple Developer account or GitHub secrets.

Prerequisites: `mise install` and `bundle install`, an Apple ID on team `8353VT99LA`, and an App Store Connect API key (Users and Access > Integrations > App Store Connect API) with the Admin role, or App Manager with access to Certificates, Identifiers & Profiles. `fastlane ios certificates` creates certificates and profiles through the API, which App Manager alone cannot do. Keep the downloaded `.p8` somewhere safe (1Password).

## 1. Add the repo secrets

The release and TestFlight workflows read these. Pull each value from 1Password; the `op://` references below are placeholders for your own vault paths.

```sh
gh secret set MATCH_PASSWORD --repo andrewcfitz/next-game --body "$(op read 'op://<vault>/<item>/<field>')"
gh secret set MATCH_DEPLOY_KEY --repo andrewcfitz/next-game --body "$(op read 'op://<vault>/<item>/<field>')"
gh secret set APP_STORE_CONNECT_API_KEY_ID --repo andrewcfitz/next-game --body "$(op read 'op://<vault>/<item>/<field>')"
gh secret set APP_STORE_CONNECT_API_ISSUER_ID --repo andrewcfitz/next-game --body "$(op read 'op://<vault>/<item>/<field>')"
gh secret set APP_STORE_CONNECT_API_KEY --repo andrewcfitz/next-game --body "$(op read 'op://<vault>/<item>/<field>' | base64)"
gh secret set APPLE_TEAM_ID --repo andrewcfitz/next-game --body "8353VT99LA"
```

| Secret | What it is |
|---|---|
| `MATCH_PASSWORD` | Passphrase that encrypts the match repo. |
| `MATCH_DEPLOY_KEY` | Private half of a read-only deploy key on `fitz-biz/earful-certificates`. Add the public half under that repo's Settings > Deploy keys, without write access. |
| `APP_STORE_CONNECT_API_KEY_ID` | Key ID of the App Store Connect API key. |
| `APP_STORE_CONNECT_API_ISSUER_ID` | Issuer ID shown on the same page. |
| `APP_STORE_CONNECT_API_KEY` | The `.p8` file, base64-encoded (a secret can't hold newlines). A raw PEM also works. |
| `APPLE_TEAM_ID` | `8353VT99LA`. |

## 2. Register the App IDs and App Groups

Creates the prod (`biz.fitz.NextGame`) and dev (`biz.fitz.NextGame.dev`) App IDs, their widget IDs, and the `group.biz.fitz.NextGame` and `group.biz.fitz.NextGame.dev` App Groups. This logs in with your Apple ID (expect a 2FA prompt), not the API key.

```sh
FASTLANE_USER=<apple id> bundle exec fastlane ios bootstrap
```

Bootstrap sets the App Group list on the shared `biz.fitz.NextGame` and `biz.fitz.NextGame.Widget` App IDs to the iOS group. The Mac app's team-prefixed group is checked against the signature, so this should be harmless. If Mac Debug signing complains afterwards, let Xcode re-register the group (automatic signing) and rebuild.

## 3. Create the App Store Connect record

TestFlight needs an app record for `biz.fitz.NextGame`. App names are unique across the App Store; if "Next Game" is taken, set `NEXTGAME_ASC_NAME`. The name on the home screen comes from `Config/Prod.xcconfig`, not from this.

```sh
FASTLANE_USER=<apple id> bundle exec fastlane ios appstore_record
# or, if the name is taken:
FASTLANE_USER=<apple id> NEXTGAME_ASC_NAME="<other name>" bundle exec fastlane ios appstore_record
```

## 4. Create the signing profiles

Creates or renews the iOS `development` and `appstore` profiles (named `match AppStore <bundle id>`) for all four identifiers and stores them in the match repo. This needs:

- the App Store Connect key env vars: `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_API_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY` (base64 or raw PEM)
- `MATCH_PASSWORD`
- SSH access to `git@github.com:fitz-biz/earful-certificates.git` from this machine (override with `MATCH_GIT_URL`)

`APPLE_TEAM_ID` is optional locally; the lanes fall back to the team in `project.yml`.

```sh
export APP_STORE_CONNECT_API_KEY_ID="$(op read 'op://<vault>/<item>/<field>')"
export APP_STORE_CONNECT_API_ISSUER_ID="$(op read 'op://<vault>/<item>/<field>')"
export APP_STORE_CONNECT_API_KEY="$(op read 'op://<vault>/<item>/<field>' | base64)"
export MATCH_PASSWORD="$(op read 'op://<vault>/<item>/<field>')"
bundle exec fastlane ios certificates
```

To install the same certificates and profiles on this Mac afterwards (read-only, needs `MATCH_PASSWORD` and repo access): `bundle exec fastlane ios setup`.

## 5. Run the TestFlight workflow

```sh
gh workflow run testflight.yml -R andrewcfitz/next-game
```

It builds the prod app, numbers the build one above the latest on TestFlight, and uploads without waiting for Apple's processing. Follow it with `gh run watch -R andrewcfitz/next-game`.

## 6. Install on the phone

In App Store Connect, open Users and Access, make sure you're an internal tester (TestFlight > Internal Testing, add yourself to a group). Once the build finishes processing, install it from the TestFlight app.

## 7. Add the widgets

On the phone, add a Home Screen widget and a Lock Screen widget (Next Game), then pick a team in each one's edit sheet.

## Dev vs prod

Debug builds use `Config/Dev.xcconfig` (`biz.fitz.NextGame.dev`, "Next Game Dev") so a development build installs beside the TestFlight one. Release builds, including TestFlight, use `Config/Prod.xcconfig` (`biz.fitz.NextGame`, "Next Game"). Both are registered by step 2.
