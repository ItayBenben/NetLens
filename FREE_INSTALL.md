# Install NetLens Lite for free (no Mac, no App Store, no $99)

**Flow:** GitHub builds the app for free on its Macs → you download the `.ipa` → **Sideloadly** on a Windows PC signs it with your free Apple ID and installs it over USB.

## What works in the free version

| Feature | Lite (free) | Full (paid developer account) |
|---|---|---|
| All domains contacted, per app (from App Privacy Report) | ✅ | ✅ |
| Destination details, tracker detection, grouping, search | ✅ | ✅ |
| Live upload/download speed, Wi-Fi/cellular totals, network info | ✅ | ✅ |
| Live DNS monitor (real-time lookups, resolved IPs, latency) | ❌ | ✅ |

Apple doesn't give Network Extension (VPN) permission to free accounts. That is the only part the Lite version drops.

## What you need (all free)

- A **GitHub** account.
- A **Windows PC you can plug your iPhone into** with a USB cable. A remote or cloud Windows server won't work, because it can't reach the phone.
- A free **Apple ID**. Using a separate, secondary Apple ID is safer, because you type its password into Sideloadly.

---

## Step 1: Build the app on GitHub (free)

1. github.com → **New repository** → name `netlens`, choose **Public**. Public repos get unlimited free macOS build minutes. A private repo also works but only gets about 200 macOS minutes a month, and one build takes about 5–10 minutes.
2. Click **uploading an existing file** and drag in the **contents** of the `NetLens` folder (`project.yml`, `App`, `Shared`, `PacketTunnel`, …). Commit.
3. Browsers sometimes skip hidden folders, so add the workflow by hand: **Add file → Create new file**, name it `.github/workflows/build-lite.yml`, paste the contents of that file from this project, and commit.
4. Open the **Actions** tab → **Build NetLens Lite** → **Run workflow**. Wait for the green check.
5. Open the finished run → **Artifacts** → download **NetLensLite-ipa**. Unzip it to get `NetLensLite.ipa`.

## Step 2: Install with Sideloadly (Windows)

1. Install **iTunes** and **iCloud** using the installers from **apple.com**, *not* the Microsoft Store versions. Sideloadly needs their drivers.
2. Download **Sideloadly** from sideloadly.io and install it.
3. Plug in your iPhone, unlock it, and tap **Trust This Computer**.
4. In Sideloadly, drag in `NetLensLite.ipa`, enter your Apple ID, and click **Start**. Enter the 2-factor code if asked.

## Step 3: Allow it on the iPhone

1. **Settings → Privacy & Security → Developer Mode** → On. The iPhone restarts. (This applies to iOS 16 and later.)
2. **Settings → General → VPN & Device Management** → tap your Apple ID → **Trust**.
3. Open NetLens.

## Step 4: Load your data

1. **Settings → Privacy & Security → App Privacy Report** → turn it on and use your phone normally for a while.
2. Scroll to the bottom → **Save App Activity** → save it to Files.
3. In NetLens → **Apps** tab → **Import**, then pick the file. Re-import whenever you want fresh data.

---

## Free-account limits

- **The app stops opening after 7 days.** Plug in and click Start in Sideloadly again (your data is kept). Sideloadly can also refresh automatically over Wi-Fi while the PC is on.
- At most **3 sideloaded apps** at once per free Apple ID.
