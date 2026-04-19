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

The translation tables live in `liblouis/tables/`. At compile time `TABLESDIR` is set to an empty string so liblouis makes no assumptions about the on-disk location; the path must be supplied at runtime (see below).

To update the vendored sources to a newer liblouis release, advance the submodule and run `Scripts/build-liblouis-macos.sh` to regenerate the derived headers (`config.h`, `liblouis.h`) that are checked in alongside the C sources.

## Packaging the liblouis tables

`BrailleTranslator` needs the liblouis translation tables at runtime. There are two options:

- **App bundle (recommended)**: Add `liblouis/tables` as a folder reference in your Xcode project's Resources build phase, then pass `Bundle.main.url(forResource: "tables", withExtension: nil)?.path` to `BrailleTranslator(tablesDirectory:)` or `Braille(tablesDirectory:)`. This is what the SpeakUp app project does.

- **Environment variable**: Set `LOUIS_TABLEPATH` to the absolute path of the tables directory before the process starts. `BrailleTranslator` will use it automatically when `tablesDirectory` is `nil`.

<!-- TODO: explore distributing the tables as a Swift package resource so consumers don't need to wire up the path themselves -->

## License

Braille is released under an Apache license. See the LICENSE file for more information.
