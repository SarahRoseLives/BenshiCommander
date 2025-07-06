# 📻 Benshi Commander

> **⚡️ Benshi Commander** is a modern, cross-platform app for exploring and programming radios using the [@khusmann/benlink](https://github.com/khusmann/benlink) protocol.
>
> **Credit:** Full protocol and reverse engineering credit goes to [@khusmann/benlink](https://github.com/khusmann/benlink). This project would not exist without that amazing work!

---

## 🚦 Status

- **Current:** Can read your radio's entire memory/code plug and export it to [CHIRP](https://chirp.danplanet.com/) CSV format over Wi-Fi.
- **In Progress:** Write support, in-app and in-browser memory editing, radio reference and RepeaterBook import, and more!
- **UI:** Some screens are placeholders for planned features – see below for details.

---

## ⚠️ Warning – You Might Brick Your Radio!

> 🧨 **This is experimental software.**
>
> - It talks to your radio at a low level.
> - It may or may not work with your specific device.
> - You **assume all risk** by using it. I am **not responsible** for damaged, bricked, or inoperable hardware.

---

## ✨ Features

- **🧠 Reads the Radio's Memory**  
  - Loads the full channel map ("code plug") from your radio over Bluetooth.
  - Automatically detects device info and channel count.
- **💾 One-Click Export to CHIRP**  
  - Simple local web server lets you download your entire code plug as a CHIRP-compatible CSV file.
  - No cables or drivers required—just connect and go!
- **🔒 Modern Flutter UI**  
  - Material Design 3 with pretty icons, dark mode, and responsive layout.
- **🔧 Modular Code**  
  - Protocol logic separated into reusable Dart files.
  - Easy to extend for new commands or radios.

---

## 🛠️ Planned & Upcoming Features

- **📝 Write Code Plug to Radio** (coming soon!)  
  Save your changes back to the radio, safely.
- **🌐 In-App/Browser Editor**  
  Edit channels and settings directly in your browser or in-app before writing.
- **📡 RadioReference & RepeaterBook Import**  
  Easily import repeater/channel lists from popular online sources.
- **📱 More UI Screens**  
  - **Dashboard:** Live device status, quick controls (planned)
  - **Scanner:** Channel scan, activity log (planned)
  - **Programmer:** (currently CSV export only; write and edit support coming)
- **🦺 Safer Write/Verify Procedures**  
  To minimize risk of bricking, with lots of warnings.

---

## 🗂️ Project Structure

```txt
├── benshi/
│   ├── protocol.dart          # Protocol, serialization, parsing, and radio commands
│   └── radio_controller.dart  # Orchestrates Bluetooth and protocol communication
├── main.dart                  # App entrypoint
├── screens/
│   ├── connection_screen.dart # Bluetooth pairing and connect
│   ├── dashboard_view.dart    # (Planned) Live status/controls
│   ├── main_screen.dart       # Navigation and main page
│   ├── programmer_view.dart   # Chirp export (write/edit planned)
│   └── scanner_view.dart      # (Planned) Channel scan/log
└── services/
    └── chirp_exporter.dart    # Chirp CSV export via web server
```

---

## 🎨 Screenshots

> _Add your screenshots here!_  
> _(Not included yet. Pull requests welcome!)_

---

## 🤖 How It Works

- **Bluetooth Serial**: Uses [flutter_bluetooth_serial](https://pub.dev/packages/flutter_bluetooth_serial) to connect to your radio.
- **Benlink Protocol**: Implements the full frame/command structure, but **currently only reads memory**.
- **Web Export**: Spins up a local server using [shelf](https://pub.dev/packages/shelf) so you can download your memory dump as a CHIRP-compatible CSV.
- **Safe By Default**: No writing to the radio yet, so it's (relatively) safe!

---

## 📝 Usage

- **No install guide yet!**  
  This project is for advanced users and developers.  
  If you have to ask how to run it, you probably shouldn't (yet)! 😉

---

## 💡 Roadmap

- [ ] Full write-back support with in-app editing
- [ ] Online import (RadioReference, RepeaterBook)
- [ ] UI polish and full-featured screens
- [ ] Multi-radio support
- [ ] More safety checks

---

## 🙏 Credits

- Protocol: [@khusmann/benlink](https://github.com/khusmann/benlink)
- CHIRP: [chirp.danplanet.com](https://chirp.danplanet.com/)
- Flutter/Dart/Material: [flutter.dev](https://flutter.dev/)

---

## 🦺 License & Disclaimer

- **This is NOT an official tool for any radio brand.**
- Use at your own risk. You are responsible for your hardware and data.
- See `LICENSE` for details.

---

> _Have fun, experiment, and help improve open radio!_  
> _PRs/issues welcome. Stay tuned for more!_
