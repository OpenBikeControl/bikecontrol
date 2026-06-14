# Store metadata (fastlane)

The localized store listings for Google Play and the Apple App Store are
managed with [fastlane](https://fastlane.tools) and live as plain `.txt`
files in the repo, one folder per language:

```
android/fastlane/metadata/android/<locale>/   # Google Play (supply)
  title.txt
  short_description.txt
  full_description.txt
  changelogs/default.txt

ios/fastlane/metadata/<locale>/                # App Store (deliver)
  name.txt
  subtitle.txt
  description.txt
  keywords.txt
  promotional_text.txt
  release_notes.txt
  marketing_url.txt
  support_url.txt
```

Locales currently maintained: **en, de, fr, es, it, pl**
(Play uses `en-US, de-DE, fr-FR, es-ES, it-IT, pl-PL`; the App Store uses
`en-US, de-DE, fr-FR, es-ES, it, pl`).

To add a language, create the matching locale folder with the same files.

## Editing

Just edit the `.txt` files and keep an eye on the store length limits:

| Field | Google Play | App Store |
| --- | --- | --- |
| title / name | 30 | 30 |
| subtitle | – | 30 |
| short description | 80 | – |
| keywords | – | 100 |
| promotional text | – | 170 |
| full description / description | 4000 | 4000 |

## Syncing via GitHub Actions

Use the **Store Metadata** workflow (`.github/workflows/metadata.yml`),
triggered manually (`workflow_dispatch`):

- **download** – pulls the current live listing from the store into the
  `.txt` files and commits the result back to the branch. Use this to refresh
  the repo from whatever is live in the stores.
- **upload** – pushes the `.txt` files to the store. Texts only: it never
  uploads the binary or screenshots. On Android it also skips the per-release
  "what's new" (those are handled by the build workflow), on iOS it updates the
  current editable version's metadata without bumping the version or submitting
  for review.

Pick the platform (`android`, `ios`, or `both`) and the action when you run it.

### Required secrets

These already exist for the build pipeline and are reused here:

- Android: `SERVICE_ACCOUNT_JSON` (Google Play service account JSON)
- iOS: `APPSTORE_API_KEY` (App Store Connect key id), `APPSTORE_API_ISSUER_ID`,
  `APPSTORE_API_KEY_FILE_BASE64` (base64 of the `.p8` key)

## Running locally

```bash
bundle install

# Android (needs android/fastlane/service-account.json)
cd android && bundle exec fastlane download_metadata   # or upload_metadata

# iOS (needs the App Store Connect API key env vars / .p8)
cd ios && bundle exec fastlane download_metadata        # or upload_metadata
```

> Note: keywords and promotional text are not exposed on the public store
> pages, so a `download` cannot refresh those two fields — they are maintained
> by hand in this repo.
