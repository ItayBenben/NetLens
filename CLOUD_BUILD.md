# Build NetLens without a Mac

**Flow:** your code on GitHub → Codemagic (cloud Mac) builds and signs the app → TestFlight → install on your iPhone.
Every step works from a Windows PC browser, and most also work on the iPhone.

## What you need

- **Apple Developer Program**, $99/year: required. Apple only allows VPN/Network Extension apps from paid accounts, and TestFlight needs it too. Enroll at developer.apple.com or in the *Apple Developer* iPhone app. Approval can take 1–2 days.
- **GitHub account** (free) to hold the code.
- **Codemagic account** (free tier with monthly macOS build minutes). Sign in at codemagic.io with GitHub.
- **TestFlight app** on your iPhone (free, from the App Store).

---

## Step 1: Choose your app ID

Pick a unique ID, e.g. `com.yourname.netlens`. Replace `com.example.netlens` with it in **all four** files:

- `project.yml` (3 places, including `group.com.example.netlens`)
- `Shared/AppConfig.swift` (2 places)
- `codemagic.yaml` (`BUNDLE_ID`)

## Step 2: Set up identifiers at developer.apple.com

Go to developer.apple.com → Account → **Certificates, Identifiers & Profiles**.

1. **Identifiers → + → App Groups**: create `group.com.yourname.netlens`.
2. **Identifiers → + → App IDs → App**: create `com.yourname.netlens`. Enable **App Groups** (assign the group above) and **Network Extensions**.
3. Create a second App ID, `com.yourname.netlens.PacketTunnel`, with the same two capabilities and the same group.

## Step 3: Create the app in App Store Connect

appstoreconnect.apple.com → **Apps → + → New App**. Choose platform iOS, name "NetLens" (or any free name), bundle ID `com.yourname.netlens`, and any SKU. You don't need to publish it to the App Store. TestFlight alone is enough.

## Step 4: Create an API key for Codemagic

App Store Connect → **Users and Access → Integrations → App Store Connect API → +**.
Name: `Codemagic`, Access: **Admin**. Download the `.p8` file (you can only download it once). Note the **Issuer ID** and **Key ID**.

## Step 5: Put the code on GitHub

1. github.com → **New repository** → name `netlens`, **Private**.
2. On the empty repo page, click **uploading an existing file** and drag in the **contents** of the `NetLens` folder (`project.yml`, `codemagic.yaml`, `App`, `Shared`, `PacketTunnel`, …) so that `codemagic.yaml` sits at the repository root. Commit.

## Step 6: Configure Codemagic

1. codemagic.io → **Add application** → GitHub → choose `netlens` → project type **iOS App** (it uses `codemagic.yaml`).
2. **Teams → your team → Integrations → Developer Portal → Connect**: enter the Issuer ID, Key ID and `.p8` file. Name it exactly **`NetLens API Key`**.
3. Generate a certificate key. On Windows, open PowerShell and run:
   ```powershell
   ssh-keygen -t rsa -b 2048 -m PEM -f netlens_cert_key -q -N '""'
   ```
   Open the `netlens_cert_key` file (not `.pub`) in Notepad and copy all of its text.
4. In your Codemagic app → **Environment variables**: add `CERTIFICATE_PRIVATE_KEY`, paste the key, tick **Secure**, and set the group to **`signing`**.
   Keep this file safe. Reusing the same key keeps your certificate stable.

## Step 7: Build

Codemagic → your app → **Start new build** → workflow **NetLens → TestFlight**. It takes about 10–20 minutes. If it fails, open the failed step's log.

## Step 8: Install on your iPhone

1. App Store Connect → your app → **TestFlight**. The build appears after Apple finishes processing it (about 5–30 min).
2. Under **Internal Testing**, create a group and add yourself (your Apple ID). Internal builds don't need Apple review.
3. Open **TestFlight** on your iPhone → install NetLens.
4. Open NetLens → **Start**. iOS asks to *Add VPN Configuration*; tap **Allow**.

TestFlight builds expire after 90 days. To renew, start a new build in Codemagic.

---

### Alternatives

- **GitHub Actions** (macOS runners) works too, but you'd set up signing manually. Codemagic handles it for you.
- **Rent a cloud Mac** (MacinCloud, AWS EC2 Mac) and use Xcode through remote desktop. You still need TestFlight to get the app onto your phone, because an iPhone can't plug into a remote Mac.
- A **free** Apple ID can't build this app: Network Extensions require the paid program.
