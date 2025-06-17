# DJILib.swift

DJILib.swift is a swift-library that enables communication between your livestreaming-app and various cameras sold under
the DJI brand.

# Supported devices
- DJI Osmo Action 4
- DJI Osmo Action 5 Pro

Do you want your device supported? Consider sponsoring me so that i can purchase the device. Its not possible to support
a device i do not own myself.

# Installation
In Xcode under Project and Package Dependencies add a new pagacke and enter the following in the Search-field:
```
https://github.com/Spillmaker/DJILib.swift.git
```

# Usage
- Implement your own BluetoothManager.
- Use the static functions to identify peripheral as a supported device when you are scanning.
- Use the static functions to connect to the proper read and write characteristics.
- Create the bluetooth payloads you want with the static functions in the library and send those generated payloads to
the write characteristic.
    - After every function you use from the library that requires a countBit, you need to increment it. Use the static
    helper-function for that.
- Use the static parse-function to get structured message-payloads you then can parse.
- There may be comments on each function so make sure to read the codebase.

# Support
I dont have the capacity to provide free support. If you want me to implement this library in your application,
I may be open for work. Feel free to contact me.
