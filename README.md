# Change IPv4 Address

A small Windows batch utility that:

1. Asks for **administrator permissions** (a UAC prompt appears).
2. Shows the current IPv4 configuration of every network adapter.
3. **Removes** the IPv4 address currently assigned to a chosen adapter (the preferred/primary one).
4. **Assigns a new IPv4 address** — typed by the user — together with its subnet mask.

It is designed for Windows systems where **multiple IPv4 addresses are enabled** on the same adapter and you want to swap the preferred one for another.

## Requirements

- Windows 10 or 11 (`netsh` is included with Windows, no extra installations needed).
- Administrator rights on the computer (the script elevates itself via UAC).

## Usage

1. Double-click `change-ipv4.bat`.
2. Accept the UAC prompt (*"Do you want to allow this app to make changes to your device?"*).
3. The script lists the current IPv4 configuration.
4. Type the **name of the adapter** (for example `Ethernet` or `Wi-Fi`).
5. Type the **IPv4 address to remove** (the preferred one currently assigned).
6. Type the **new IPv4 address** and its **subnet mask** (press ENTER to accept `255.255.255.0`).

The script validates that every value is a well-formed IPv4 address (each octet between 0 and 255) before touching the configuration, and it tries to restore the previous address if adding the new one fails.

## What it runs under the hood

```bat
netsh interface ipv4 show addresses
netsh interface ipv4 delete address name="%ADAPTER%" addr=<old-ip>
netsh interface ipv4 add address    name="%ADAPTER%" addr=<new-ip> mask=<subnet-mask>
```

## Warnings

- Changing the IP address of the adapter you are connected through **will drop your current connection** for a moment. If you are connected remotely (RDP, SSH), keep a secondary way of accessing the machine.
- The script only changes the **IP address and subnet mask**. If the removed address was also holding the default gateway or DNS settings, you may need to reconfigure them separately with `netsh`.
- Run the script only on adapters you are supposed to configure.

## Files

| File              | Description                                          |
| ----------------- | ---------------------------------------------------- |
| `change-ipv4.bat` | The script: elevates, removes the old IP, adds the new one. |
