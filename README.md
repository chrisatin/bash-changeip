# Change IPv4 Address

A small Windows batch utility that:

1. Asks for **administrator permissions** (a UAC prompt appears).
2. **Auto-detects the active network interface** (the one with the default gateway and the lowest metric). If it cannot be detected, it asks for the interface name.
3. Shows the IPv4 addresses currently assigned to that interface.
4. **Removes** the IPv4 address chosen by the user (the preferred/primary one).
5. **Assigns a new IPv4 address** — typed by the user — together with its subnet mask.

It is designed for Windows systems where **multiple IPv4 addresses are enabled** on the same interface and you want to swap the preferred one for another.

## Requirements

- Windows 10 or 11 (`netsh` and PowerShell's `Get-NetIPConfiguration` are included with Windows, no extra installations needed).
- Administrator rights on the computer (the script elevates itself via UAC).

## Usage

1. Double-click `change-ipv4.bat`.
2. Accept the UAC prompt (*"Do you want to allow this app to make changes to your device?"*).
3. The script detects the active interface and lists its IPv4 addresses.
   - If detection fails (for example, no default gateway), it shows the available interfaces and asks for the name.
4. Type the **IPv4 address to remove** (the preferred one currently assigned).
5. Type the **new IPv4 address** and its **subnet mask** (press ENTER to accept `255.255.255.0`).

The script validates that every value is a well-formed IPv4 address (each octet between 0 and 255) before touching the configuration, and it tries to restore the previous address if adding the new one fails.

## What it runs under the hood

Detecting the active interface:

```bat
powershell -NoProfile -Command "(Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway } | Sort-Object { (Get-NetIPInterface -InterfaceIndex $_.InterfaceIndex -AddressFamily IPv4).InterfaceMetric } | Select-Object -First 1).InterfaceAlias"
```

Changing the address:

```bat
netsh interface ipv4 show addresses   name="<interface>"
netsh interface ipv4 delete address   name="<interface>" addr=<old-ip>
netsh interface ipv4 add address      name="<interface>" addr=<new-ip> mask=<subnet-mask>
```

## Warnings

- Changing the IP address of the interface you are connected through **will drop your current connection** for a moment. If you are connected remotely (RDP, SSH), keep a secondary way of accessing the machine.
- The script only changes the **IP address and subnet mask**. If the removed address was also holding the default gateway or DNS settings, you may need to reconfigure them separately with `netsh`.
- Run the script only on interfaces you are supposed to configure.

## Files

| File              | Description                                                              |
| ----------------- | ------------------------------------------------------------------------ |
| `change-ipv4.bat` | The script: elevates, auto-detects the interface, removes the old IP, adds the new one. |
