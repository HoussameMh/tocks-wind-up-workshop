# Deploying to itch.io

How to put Tock's Wind-Up Workshop on [itch.io](https://itch.io) and sell it. Publishing is
free; by default itch.io keeps 10% of each sale, and you can change that share.
The store text is in [itch-store-page.md](itch-store-page.md) and the cover is
[cover.png](cover.png).

## 1. Build the game

Godot's export templates must be installed once: in the Godot editor, use
Editor, then Manage Export Templates, then Download and Install. Then, from the project folder:

```bash
godot --headless --path . --export-release "Windows Desktop" builds/windows/TocksWindUpWorkshop.exe
```

```bash
godot --headless --path . --export-release "Web" builds/web/index.html
```

Zip each build for upload. In PowerShell:

```powershell
Compress-Archive -Path builds\web\* -DestinationPath builds\tocks-wind-up-workshop-web.zip -Force
```

```powershell
Compress-Archive -Path builds\windows\TocksWindUpWorkshop.exe -DestinationPath builds\tocks-wind-up-workshop-windows.zip -Force
```

The web zip must have `index.html` at its top level, not inside a folder, which the first
command does. The `builds/` folder is not committed to Git.

## 2. Create the project page

1. Sign up or sign in at itch.io, then open your dashboard and choose **Create new project**.
2. Fill in the fields from [itch-store-page.md](itch-store-page.md), and upload `cover.png` as the cover image.
3. Set **Kind of project** to **HTML**, so the game can be played in the page.
4. Under **Uploads**:
   - Upload `tocks-wind-up-workshop-web.zip` and tick **This file will be played in the browser**.
   - Upload `tocks-wind-up-workshop-windows.zip` and tick **Windows** for it.
5. Under **Embed options**, set the viewport to **1280 by 720**, and tick **Fullscreen button**. The
   web build doesn't use threads, so leave **SharedArrayBuffer support** off.
6. Add screenshots, set the price, and save as **Draft** first. Open the page, play the browser
   version and download the Windows version before you make it **Public**.

## 3. Get paid

Under your account's **Settings**, then **Payment**, choose how itch.io pays you, either
through PayPal or Stripe directly, or collected by itch.io and paid out later. Paid projects also need the
tax information itch.io asks for there. Only you can enter payment and tax details.

## 4. Things players will see

- **Windows SmartScreen warning:** the `.exe` is not code-signed, so Windows may say it "protected
  your PC" on first launch. Players choose **More info**, then **Run anyway**. Code-signing
  certificates remove this but cost money every year.
- **Graphics:** the game starts on Low on integrated Intel graphics and in the browser, and on
  High elsewhere. Players can change it under Options.
- **Saves:** the Windows version saves in `%APPDATA%\Godot\app_userdata\Tock's Wind-Up Workshop`.
  The browser version saves in the browser's storage for itch.io, so clearing site data erases it.

## 5. Updating the game

Rebuild, re-zip and replace the files under **Uploads**. For frequent updates, itch.io's command
line tool [butler](https://itch.io/docs/butler/) uploads only what changed:

```bash
butler push builds/web <your-itch-name>/tocks-wind-up-workshop:html5
```

```bash
butler push builds/windows <your-itch-name>/tocks-wind-up-workshop:windows
```

## Other stores, later

- **Steam:** a one-time $100 fee per game, then Steam keeps 30% of sales. Worth it once the game
  has player reviews and more content.
- **Browser game portals** such as CrazyGames or Poki: free, paid through ad revenue, but they
  review and choose which games they accept, and they need their own ad code added.
