<div align="center">
  <img src="Resources/AppIcon.png" width="128" alt="Bitcoin Ticker Universal icon">

  # Bitcoin Ticker Universal

  **A tiny, native Bitcoin price ticker for the macOS menu bar.**

  [![Swift 6.2](https://img.shields.io/badge/Swift-6.2-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
  [![macOS 11+](https://img.shields.io/badge/macOS-11%2B-000000?logo=apple&logoColor=white)](https://support.apple.com/macos)
  [![Universal Binary](https://img.shields.io/badge/Universal-arm64%20%7C%20x86__64-4c8bf5)](#build-app-bundles)
  [![No Dependencies](https://img.shields.io/badge/dependencies-none-2ea44f)](#requirements)

  [Download](dist/Bitcoin-Ticker-Universal.dmg) · [Features](#features) · [Install](#install-from-dmg) · [Build](#build-from-source) · [Uninstall](#uninstall)
</div>

---

## Why this exists

I liked the simplicity of having the Bitcoin price always visible in the menu bar. The original **Bitcoin Ticker Widget** delivered exactly that experience, but its Mac app was built for Intel and did not run natively on Apple Silicon.

Bitcoin Ticker Universal is a small native replacement built for both Apple Silicon and Intel Macs, while keeping the same glanceable, distraction-free idea.

> Shout-out to [Bitcoin Ticker Widget by Uniweb Labs](https://apps.apple.com/us/app/bitcoin-ticker-widget/id998255317) for the original inspiration.

## Preview

```text
  $64404
```

The selected public API price is displayed as a rounded integer. Request, HTTP, or JSON parsing errors display `--` until the next successful refresh.

## Features

| | Feature | Details |
| --- | --- | --- |
| ⚡️ | Native and lightweight | Pure Swift, no third-party libraries |
| 🖥️ | Universal Binary | Runs on Apple Silicon (`arm64`) and Intel (`x86_64`) |
| 📊 | Multiple price sources | Coinbase, Binance, Bybit, and custom JSON APIs |
| 🔄 | Configurable polling | 60000 ms default with per-source intervals |
| 🧩 | Flexible response parsing | Dot-notation key paths with array indexes |
| 💱 | Currency symbols | USD (`$`), KRW (`₩`), JPY (`¥`), and EUR (`€`) |
| 🚀 | Launch at Login | Native registration on modern macOS with a legacy fallback |
| 🧹 | Clean uninstaller | Removes login registration and saved app data |

Currency selection changes the displayed symbol only. It does not perform exchange-rate conversion.

## Menu

Click the menu bar price to open:

```text
Price Source List
─────────────────
Launch at Login
─────────────────
Settings…
─────────────────
Quit App
```

The current price source changes only through **Price Source List**. Selecting an item in Settings changes the editor target without changing the active ticker source.

## Built-in price sources

All built-in sources use public endpoints and require no API key. Only the active source is polled.

| Source | Endpoint | Response key path | Default refresh |
| --- | --- | --- | ---: |
| Coinbase BTC-USD | `https://api.coinbase.com/v2/prices/BTC-USD/spot` | `data.amount` | 60000 ms |
| Binance BTC-USDT | `https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT` | `price` | 60000 ms |
| Bybit BTC-USDT | `https://api.bybit.com/v5/market/tickers?category=spot&symbol=BTCUSDT` | `result.list.0.lastPrice` | 60000 ms |

Coinbase is selected on first launch.

## Settings

Each price source has five editable fields:

- **Label** — display name in the source menu
- **API** — public HTTP or HTTPS endpoint
- **Response key path** — location of the numeric value in the JSON response
- **Currency symbol** — visual prefix only; no conversion
- **Refresh interval** — milliseconds between requests

Nested objects and array indexes use dot notation:

```text
data.amount
result.list.0.lastPrice
```

New sources default to 60000 ms. The minimum effective polling interval is 250 ms.

## Install from DMG

1. Download and open [`Bitcoin-Ticker-Universal.dmg`](dist/Bitcoin-Ticker-Universal.dmg).
2. Drag **Bitcoin Ticker Universal.app** onto the included **Applications** shortcut.
3. Launch the app from `/Applications`.
4. Enable **Launch at Login** after the app is in its final location.

> [!NOTE]
> The local DMG uses an ad-hoc signature. On another Mac, Gatekeeper may require Finder → right-click the app → **Open**. Warning-free public distribution requires Developer ID signing and Apple notarization.

## Launch at Login

| macOS version | Implementation | System Settings location |
| --- | --- | --- |
| macOS 13+ | `SMAppService.mainApp` | Open at Login |
| macOS 11–12 | Per-user LaunchAgent | App Background Activity |

When upgrading, the fallback LaunchAgent is removed only after native registration succeeds. This avoids duplicate launches without discarding a working registration on failure.

Launch at Login requires the packaged `.app`. It is intentionally unavailable when running the raw Swift Package executable.

## Uninstall

Run **Uninstall Bitcoin Ticker Universal.app** directly from the DMG.

If the ticker is currently running, the Uninstall button remains disabled and displays:

```text
앱이 실행 중이므로 삭제할 수 없습니다.
```

The button becomes active automatically after the ticker quits. After confirmation, the uninstaller:

- Unregisters the login item
- Removes the macOS 11–12 LaunchAgent fallback
- Removes preferences, caches, application support, saved state, and HTTP storage
- Moves `/Applications/Bitcoin Ticker Universal.app` to the Trash

The uninstaller runs from the mounted DMG and installs no additional files.

## Requirements

| | Version |
| --- | --- |
| Runtime | macOS 11 or newer |
| Build toolchain | Xcode with Swift 6.2 |
| Dependencies | None |
| API keys | None |

## Build from source

### Run from Xcode

1. Open `Package.swift` in Xcode.
2. Select the `BitcoinTickerUniversal` scheme.
3. Select **My Mac**.
4. Run with `⌘R`.

Xcode launches the raw Swift Package executable instead of a packaged app bundle. This is sufficient for UI and API development, but bundle-dependent features such as Launch at Login must be tested using the packaged `.app`.

### Build app bundles

```sh
chmod +x scripts/package_app.sh
./scripts/package_app.sh
```

Outputs:

```text
dist/Bitcoin Ticker Universal.app
dist/Uninstall Bitcoin Ticker Universal.app
```

The script builds both architectures, creates both bundles, includes their `.icns` resources, applies local ad-hoc signatures, and verifies `arm64` and `x86_64` with `lipo -archs`.

### Build the DMG

```sh
chmod +x scripts/package_dmg.sh
./scripts/package_dmg.sh
```

Output:

```text
dist/Bitcoin-Ticker-Universal.dmg
```

The disk image contains:

- `Bitcoin Ticker Universal.app`
- `Uninstall Bitcoin Ticker Universal.app`
- `/Applications` shortcut

The completed image is verified with `hdiutil verify`.

## Project structure

```text
.
├── Package.swift
├── Resources
│   ├── AppIcon.png
│   ├── AppIcon.icns
│   ├── UninstallerIcon.png
│   └── UninstallerIcon.icns
├── Sources
│   ├── BitcoinTickerUniversal
│   └── BitcoinTickerUninstaller
└── scripts
    ├── package_app.sh
    └── package_dmg.sh
```

## Acknowledgements

- [Bitcoin Ticker Widget](https://apps.apple.com/us/app/bitcoin-ticker-widget/id998255317) — the simple menu bar experience that inspired this project
- [Coinbase](https://docs.cdp.coinbase.com/coinbase-business/track-apis/prices), [Binance](https://developers.binance.com/en/docs/catalog/core-trading-spot-trading/api/rest-api/market), and [Bybit](https://bybit-exchange.github.io/docs/v5/market/tickers) — public market data APIs

---

<div align="center">
  Built for a quieter menu bar and a quick glance at Bitcoin.
</div>
