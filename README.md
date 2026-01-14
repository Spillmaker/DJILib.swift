# Prerelease warning
This is currently in a prerelease. The versioning is still not stable so if you are implementing this version of it,
be warned that stuff may change drasticly. Feel free to wait until the tagged version is 1.0.0 or above, or until
this message is gone from the readme.

# DJILib.swift

DJILib.swift is a swift-library that enables communication between your livestreaming-app and various cameras sold under
the DJI brand.

# Supported devices
- DJI Osmo Action 4
- DJI Osmo Action 5 Pro

# Allegedly supported devices
These are devices that i personally does not own, but ive gotten reported that they work. But as i cant test myself, these are unsupported by me.
- DJI Osmo Pocket 3
- Xtra Edge
- Xtra Edge Pro
- Xtra Muse

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
Open a ticket, and maybe i can look into it. But please check the list of supported devices.
If you want me to implement this library in your application,i may be open for work. Feel free to contact me.
