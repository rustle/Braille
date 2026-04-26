# Braille

Swift Package for [BrlAPI](https://brl.thefreecat.org) with some helpers.

# Building

```bash
swift package build-brltty
swift build
swift test
```

`build-brltty` is a command plugin that initialises git submodules and runs `Scripts/build-brltty-macos.sh`. Pass `-- --no-clean` to skip the configure step on subsequent builds:

```bash
swift package build-brltty -- --no-clean
```

Pass `-- --arch=arm64` or `-- --arch=x86_64` to build for a specific architecture:

```bash
swift package build-brltty -- --arch=arm64
```

To build the xcframework directly from the plugin (equivalent to running the script manually):

```bash
swift package build-brltty -- --xcframework --universal
swift package build-brltty -- --xcframework --universal --no-clean
```

## Releasing

### 1. Build the universal XCFramework

Run this on Apple Silicon — Rosetta 2 (installed by default) lets configure test binaries for x86_64 execute during the cross-compile:

```bash
./Scripts/create-brlapi-xcframework.sh --universal
```

Or via the plugin:

```bash
swift package build-brltty -- --xcframework --universal
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

# Build and test against the local binary target
# (Package.swift detects BrlAPI.xcframework and switches automatically)
swift build
swift test
```

### 3. Update `Package.swift`

Replace the conditional `BrlAPI` target with a URL binary target. You can construct the URL before uploading since GitHub release asset URLs are deterministic:

```swift
.binaryTarget(
    name: "BrlAPI",
    url: "https://github.com/rustle/Braille/releases/download/1.0.0/BrlAPI.xcframework.zip",
    checksum: "<checksum from step 1>"
),
```

Commit this change.

### 4. Tag, push, and publish

```bash
git tag 1.0.0
git push origin main --tags
gh release create 1.0.0 BrlAPI.xcframework.zip --title "1.0.0"
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

## liblouis

liblouis is vendored into this package as a Swift Package Manager C target (`Sources/CLiblouis/`) and compiled from source as part of a normal `swift build` — no separate build step or system install required. The liblouis source is a git submodule at `liblouis/`; run `git submodule update --init` to populate it.

The translation tables live in `liblouis/tables/`. At compile time `TABLESDIR` is set to an empty string so liblouis makes no assumptions about the on-disk location; the tables are resolved at runtime via `Bundle.module` (see below).

To update the vendored sources to a newer liblouis release, advance the submodule and run `Scripts/build-liblouis-macos.sh` to regenerate the derived headers (`config.h`, `liblouis.h`) that are checked in alongside the C sources.

## liblouis tables at runtime

`BrailleTranslator` needs the liblouis translation tables at runtime. The `Braille` package declares `liblouis/tables` as a resource, so they are bundled automatically and resolved via `Bundle.module` — no extra wiring is required when using this package via SPM.

For non-SPM embedding (e.g. adding the Braille sources directly to an Xcode project), pass an explicit path:

```swift
BrailleTranslator(tablesDirectory: Bundle.main.url(forResource: "tables", withExtension: nil)?.path)
```

Or set the `LOUIS_TABLEPATH` environment variable to the absolute path of the tables directory before the process starts.

## License

Braille is released under an Apache license. See the LICENSE file for more information.
