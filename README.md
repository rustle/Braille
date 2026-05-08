# Braille

Swift Package for [BrlAPI](https://brl.thefreecat.org), with some helpers.

The package exposes a single `Braille` library that depends on the `BrlAPI` binary XCFramework target. Translation from text to braille dot patterns happens server-side in the BRLTTY daemon — this package sends text via `brlapi__writeWText` and lets the daemon apply its configured text/contraction tables.

# Building

```bash
swift package build-brlapi -- --xcframework
swift build
swift test
```

`build-brlapi` is a command plugin that initialises the `BRLTTY` git submodule and runs `Scripts/build-brltty-macos.sh`. Pass `-- --no-clean` to skip the configure step on subsequent builds:

```bash
swift package build-brlapi -- --no-clean
```

Pass `-- --arch=arm64` or `-- --arch=x86_64` to build for a specific architecture:

```bash
swift package build-brlapi -- --arch=arm64
```

To build the xcframework directly from the plugin (equivalent to running the script manually):

```bash
swift package build-brlapi -- --xcframework --universal
swift package build-brlapi -- --xcframework --universal --no-clean
```

`Package.swift` ships with a URL-based `binaryTarget`, so a fresh clone resolves `BrlAPI.xcframework` from a published GitHub release without running the plugin. The plugin is only needed when working on BRLTTY itself or cutting a new release.

## Releasing

### 1. Build the universal XCFramework

Run this on Apple Silicon — Rosetta 2 (installed by default) lets configure test binaries for x86_64 execute during the cross-compile:

```bash
./Scripts/create-brlapi-xcframework.sh --universal
```

Or via the plugin:

```bash
swift package build-brlapi -- --xcframework --universal
```

This compiles BRLTTY for arm64 and x86_64, `lipo`s the dylibs into a fat binary, and produces:

- `BrlAPI.xcframework` — the binary target consumed by SPM
- `BrlAPI.xcframework.zip` — the release asset
- The SPM checksum printed to stdout — note it

Pass `--no-clean` to reuse existing BRLTTY build outputs:

```bash
./Scripts/create-brlapi-xcframework.sh --universal --no-clean
```

### 2. Verify the binary before releasing

```bash
# Confirm both architectures are present
lipo -info BrlAPI.xcframework/macos-arm64_x86_64/BrlAPI.framework/BrlAPI
```

(If the file isn't there, you may have forgotten `--universal`, which changes the path.)

```bash
swift build
swift test
```

### 3. Sign and notarize the XCFramework

The framework binaries must be signed with a Developer ID certificate before release.

```bash
codesign --force --sign "Developer ID Application: Your Name (TEAMID)" \
  --timestamp \
  BrlAPI.xcframework/macos-arm64_x86_64/BrlAPI.framework/Versions/A/BrlAPI

codesign --force --sign "Developer ID Application: Your Name (TEAMID)" \
  --timestamp \
  BrlAPI.xcframework/macos-arm64_x86_64/BrlAPI.framework

codesign --force --sign "Developer ID Application: Your Name (TEAMID)" \
  --timestamp \
  BrlAPI.xcframework
```

Verify the binary has a valid Developer ID signature:

```bash
codesign -dv BrlAPI.xcframework/macos-arm64_x86_64/BrlAPI.framework/Versions/A/BrlAPI
# TeamIdentifier should match your team ID; no "adhoc" in the flags
```

Then notarize:

```bash
ditto -c -k --keepParent BrlAPI.xcframework BrlAPI.xcframework.zip

xcrun notarytool submit BrlAPI.xcframework.zip \
  --apple-id "your@email.com" \
  --team-id "TEAMID" \
  --wait
```

The checksum will change after signing — recompute it:

```bash
swift package compute-checksum BrlAPI.xcframework.zip
```

### 4. Update `Package.swift`

Replace the URL/checksum on the `BrlAPI` `binaryTarget`:

```swift
.binaryTarget(
    name: "BrlAPI",
    url: "https://github.com/rustle/Braille/releases/download/<tag>/BrlAPI.xcframework.zip",
    checksum: "<checksum from step 3>"
),
```

Commit this change.

### 5. Tag, push, and publish

```bash
git tag <tag>
git push origin main --tags
gh release create <tag> BrlAPI.xcframework.zip --title "<tag>"
```

### Local development after a release

`Package.swift` at a release tag uses the URL binary target, so there is no local build path in the shipped manifest. Consumers who want to work on the `Braille` package itself reference it via a local override in their consuming project:

```swift
// In SpeakUp or ScreenReader Package.swift
.package(path: "../Braille")
```

This bypasses the binary target entirely and uses the source package directly.

## Verifying BRLTTY output

### Debug log

Run the daemon without `-q` and with `--log-level=debug` to see each BrlAPI write it receives:

```bash
sudo .build/brltty/Programs/brltty -b no -x no -n -A auth=none --log-level=debug
```

### apitest

`apitest` is a BrlAPI client that connects to the running daemon and sends test patterns — the same path your code uses. With the daemon running:

```bash
.build/brltty/Programs/apitest
```

### brltest

`brltest` exercises braille drivers directly (bypasses BrlAPI). Useful for confirming a driver works independently of the daemon:

```bash
.build/brltty/Programs/brltest -b no
```

Both `apitest` and `brltest` are built by `./Scripts/build-brltty-macos.sh`.

## Running the BRLTTY daemon

`BrlAPIDisplay` connects to a running BRLTTY daemon over a Unix socket. The daemon must be running before `connect()` is called; if it isn't, the call throws `BrlAPIError.connectionFailed`.

### Development (no physical display)

Run BRLTTY with the null drivers so the socket is available without hardware:

```bash
sudo .build/brltty/Programs/brltty -b no -x no -n -q -A auth=none
```

- `-b no` — null Braille driver (simulates a display)
- `-x no` — null screen driver
- `-n` — don't daemonize (stays in foreground)
- `-q` — quiet
- `-A auth=none` — disable key-file authentication (the app runs as a non-root user and cannot read root's auth key)

The simulated display accepts `write` calls silently, so the full send path can be exercised.

### With a real Braille display

```bash
sudo .build/brltty/Programs/brltty
```

BRLTTY auto-detects most USB and Bluetooth displays. Pass `-b <driver>` to force a specific driver if needed.

### Notes

- BRLTTY needs `root` (or USB/Accessibility permissions) to open the display device.
- The socket is created at `/var/run/BrlAPI.socket` (root) or `~/.BrlAPI.socket` (user).
- If `/etc/brltty.conf` is absent, pass all options on the command line as shown above.

## Translation tables

`BrlAPIDisplay.write(text:)` calls `brlapi__writeWText`, which sends raw text to the daemon. The daemon translates the text to dot patterns using its currently loaded text and contraction tables (the BRLTTY `.ttb` / `.ctb` formats).

Pick a table on the daemon command line:

```bash
sudo .build/brltty/Programs/brltty -T en-nabcc -b no -x no -n -A auth=none
```

Or set `text-table` / `contraction-table` in `/etc/brltty.conf`. The bundled tables live under `BRLTTY/Tables/Text/` and `BRLTTY/Tables/Contraction/`.

Selecting the table is a daemon-level concern; the client has no API to override it.

## License

Braille is released under an Apache license. See the LICENSE file for more information.
