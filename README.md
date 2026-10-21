# Upload.am Rule-Based Split VPN for macOS

<p align="center">
  <a href="https://devsponsors.github.io"><img src="https://devsponsors.github.io/assets/badges/sponsor.svg" alt="DevSponsors"></a>
  <a href="https://devsponsors.github.io"><img src="https://img.shields.io/badge/DevSponsors-Verified_OSS-6366f1?style=for-the-badge&logo=github" alt="DevSponsors"></a>
  <a href="https://devsponsors.github.io"><img src="https://img.shields.io/badge/Sponsor-DevSponsors_Hub-emerald?style=for-the-badge&logo=github-sponsors" alt="Sponsor"></a>
  <a href="https://devsponsors.github.io/mediakit.html"><img src="https://img.shields.io/badge/Infrastructure-DevSponsors_Cloud-ec4899?style=for-the-badge&logo=server" alt="Cloud"></a>
</p>

<p align="center">
  <b>English</b> • <a href="README.fa.md">راهنمای فارسی</a>
</p>

<p align="center">
  <img src="assets/banner.png" alt="Upload.am Split VPN Banner" width="100%">
</p>

A lightweight, native macOS menu bar app and rule-based OpenVPN config generator for **Upload.am's free VPN**.

Designed specifically for users who need a dedicated tunnel for **Telegram** or specific blocked domains/IPs without overriding the system default gateway or interfering with active **V2Ray / Xray / Clash** proxies.

---

## Key Features

- **Split-Tunneling by Default (`route-nopull`):** Routes only Telegram traffic through the tunnel. All other system applications, browsers, and terminal sessions stay on your local network or active V2Ray connection.
- **Rule-Based Routing Modes:**
  1. **Telegram Only:** Routes official Telegram ASN IP blocks (`149.154.160.0/20`, `91.108.0.0/16`, etc.).
  2. **Full VPN:** Routes 100% of internet traffic through Upload.am.
  3. **Custom Whitelist:** Route only specified domains (e.g. `twitter.com`, `youtube.com`) or IP/CIDRs.
  4. **Exclude Mode:** Route everything through VPN *except* specified IPs/domains (via native `net_gateway`).
- **Native macOS Dashboard & Menu Bar App:**
  - Written in Swift with AppKit & WKWebView.
  - Liquid glassmorphism dark aesthetic (`NSVisualEffectView`).
  - 1-click toggle with Touch ID / admin privileges prompt.
  - Live server connection logs and status badge.
  - Bilingual UI (English & Persian) with instant RTL/LTR toggle.
- **Zero Heavy Dependencies:** Python scripts use stdlib only.

---

## 1. Get Free Account & API Token

Upload.am provides cloud storage with an integrated free OpenVPN profile.

1. **Register Account:**
   Sign up using the referral invitation link:  
   👉 **[https://upload.am/en/register?ref=zzc77xsprl](https://upload.am/en/register?ref=zzc77xsprl)**

2. **Generate API Token:**
   - Log in and navigate to **Settings** → **API** (or visit `/cabinet/api`).
   - Click **Create Token** and copy your token (format: `ua_live_...`).

3. **Fetch OpenVPN Profile:**
   Run the included helper script:
   ```bash
   ./scripts/fetch_profile.sh "ua_live_YOUR_TOKEN" ~/upload-am-vpn.ovpn
   ```
   Or use `curl` directly:
   ```bash
   curl -sSL -H "Authorization: Bearer ua_live_YOUR_TOKEN" \
        -H "Accept: application/json" \
        "https://upload.am/api/v1/vpn/profile" > ~/upload-am-vpn.ovpn
   ```

---

## 2. Installation & Quick Start

### Quick Install (macOS)

#### Option 1: Download Native DMG Installer (Recommended)
Download the standalone `.dmg` installer directly from the [GitHub Releases](https://github.com/ketabchi-ar/upload-am-split-vpn/releases):
- 📥 **[Download UploadAmVPN.dmg (Apple Silicon & Intel)](https://github.com/ketabchi-ar/upload-am-split-vpn/releases/latest)**

Drag and drop `UploadAmVPN.app` into `/Applications` and run!

#### Option 2: Build from Source via Terminal
Clone the repository and run the automated installer:

```bash
git clone https://github.com/ketabchi-ar/upload-am-split-vpn.git
cd upload-am-split-vpn
./install.sh
```

The installer verifies Homebrew and `openvpn`, compiles the native Swift application, and installs it into `~/Applications/UploadAmVPN.app`.

To launch:
```bash
open ~/Applications/UploadAmVPN.app
```

---

## 3. CLI Config Generator Usage

If you prefer using OpenVPN via terminal or standard clients (Tunnelblick, OpenVPN Connect):

### Mode 1: Telegram Only (V2Ray Safe)
```bash
python3 scripts/generate_config.py \
  -i ~/upload-am-vpn.ovpn \
  -o ~/telegram-vpn.ovpn \
  -m telegram
```

Run in terminal:
```bash
sudo openvpn --config ~/telegram-vpn.ovpn
```

### Mode 2: Custom Domains & IPs Whitelist
Route only specific services through the tunnel:
```bash
python3 scripts/generate_config.py \
  -i ~/upload-am-vpn.ovpn \
  -o ~/custom-vpn.ovpn \
  -m custom \
  -t twitter.com youtube.com 1.1.1.1/32
```

### Mode 3: Exclude Specific IPs
Route all traffic through VPN except specific networks:
```bash
python3 scripts/generate_config.py \
  -i ~/upload-am-vpn.ovpn \
  -o ~/exclude-vpn.ovpn \
  -m exclude \
  -t 192.168.1.0/24 10.0.0.0/8
```

---

## Stopping the VPN

- **From Dashboard:** Click **Disconnect VPN**.
- **From Menu Bar:** Click the menu bar icon → **Disconnect**.
- **From Terminal:**
  ```bash
  sudo killall openvpn
  ```

---

## 4. Web-Based Universal Generator (Mobile, Windows & Linux)

For users on **iOS, Android, Windows, or Linux**:
Open the built-in web generator hosted on GitHub Pages:
🌐 **[Upload.am Split VPN Online Generator](https://ketabchi-ar.github.io/upload-am-split-vpn/)**

1. Paste your API token.
2. Select your split tunnel mode (Telegram only or Custom).
3. Tap **Download Profile (.ovpn)**.
4. Import into **OpenVPN Connect** (iOS / Android / Windows) and connect with one tap!

---

## Architecture

```
                 [ Mac Network Traffic ]
                           │
       ┌───────────────────┴───────────────────┐
       │                                       │
  Telegram / Whitelisted IPs             All Other Traffic
       │                                       │
       ▼                                       ▼
 [ Upload.am VPN (utun) ]            [ V2Ray / Default Gateway ]
 (172.252.236.84:443 TCP)                 (Untouched)
```

---

## License

Released under the [MIT License](LICENSE).
