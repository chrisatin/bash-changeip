# Change IPv4 Address

A small Windows batch utility that:

1. Asks for **administrator permissions** (a UAC prompt appears).
2. **Detects the active network interface** (default gateway, lowest metric), shows it, and lets you **press ENTER to accept it or type another interface name**.
3. Shows the IPv4 addresses currently assigned to that interface.
4. **Removes** the IPv4 address chosen by the user (the preferred/primary one) — and verifies it is really gone before continuing.
5. **Assigns a new IPv4 address** — typed by the user — together with its subnet mask, and verifies it exists before declaring success.

It is designed for Windows systems where **multiple IPv4 addresses are enabled** on the same interface and you want to swap the preferred one for another.

## Requirements

- Windows 10 or 11 (`netsh` and PowerShell's `Get-NetIP*` cmdlets are included with Windows, no extra installations needed).
- Administrator rights on the computer (the script elevates itself via UAC).

## Usage

1. Double-click `change-ipv4.bat`.
2. Accept the UAC prompt (*"Do you want to allow this app to make changes to your device?"*).
3. The script shows `Detected active interface: "<name>"`:
   - Press **ENTER** to use it, or **type another interface name** (e.g. `Ethernet`) if you want a different one.
   - If automatic detection fails, it lists the available interfaces and asks for the name.
4. Type the **IPv4 address to remove** (the preferred one currently assigned).
   - If that address is not assigned to the interface, the script warns you and asks whether to continue anyway.
5. Type the **new IPv4 address** and its **subnet mask** (press ENTER to accept `255.255.255.0`).

The script validates every value (each octet between 0 and 255) before touching the configuration.

## How success is checked

`netsh` exit codes are not always reliable — for example, deleting a DHCP-assigned address can return an error even when the address was actually removed. Because of that, the script **re-queries the real configuration with `Get-NetIPAddress`** after every change:

- If the old address is gone → proceed to add the new one.
- If the old address is still there → stop and show the error (nothing else is changed).
- If the new address does not appear after `netsh add` → report failure and try to restore the old address.

Interface and address checks use PowerShell cmdlets instead of parsing `netsh` output, so the script also works on non-English versions of Windows.

## What it runs under the hood

Detecting the active interface:

```bat
powershell -NoProfile -Command "(Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway } | Sort-Object { (Get-NetIPInterface -InterfaceIndex $_.InterfaceIndex -AddressFamily IPv4).InterfaceMetric } | Select-Object -First 1).InterfaceAlias"
```

Changing the address (PowerShell cmdlets wrapped inside the batch file):

```bat
powershell -NoProfile -ExecutionPolicy Bypass -Command "Remove-NetIPAddress -InterfaceAlias '<iface>' -IPAddress <old-ip> -Confirm:$false"
powershell -NoProfile -ExecutionPolicy Bypass -Command "New-NetIPAddress    -InterfaceAlias '<iface>' -IPAddress <new-ip> -PrefixLength <n>"
```

The subnet mask typed by the user is converted to a prefix length inside PowerShell
(`255.255.255.0` -> `24`).

Verifying (after each change):

```bat
powershell -NoProfile -Command "Get-NetIPAddress -InterfaceAlias '<interface>' -IPAddress '<ip>' ..."
```

## Warnings

- Changing the IP address of the interface you are connected through **will drop your current connection** for a moment. If you are connected remotely (RDP, SSH), keep a secondary way of accessing the machine.
- Make sure the **new address is not already used** by another device or interface on the network.
- The script only changes the **IP address and subnet mask**. If the removed address was also holding the default gateway or DNS settings, you may need to reconfigure them separately with `netsh`.
- The script works on disconnected interfaces too (useful for configuring an adapter whose cable is not plugged in yet).

## Files

| File              | Description                                                                            |
| ----------------- | -------------------------------------------------------------------------------------- |
| `change-ipv4.bat` | The script: elevates, lets you pick the interface, removes the old IP, adds the new one. |
