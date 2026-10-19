@echo off
setlocal EnableDelayedExpansion
title Change IPv4 Address
color 0A

:: ===========================================================================
::  CHANGE IPv4 ADDRESS
::
::  Removes the IPv4 address currently assigned to a network interface
::  (the preferred/primary one) and assigns a new address typed by the user,
::  together with its subnet mask.
::
::  Interface selection: the active interface (default gateway, lowest
::  metric) is detected and shown for confirmation. The user presses ENTER
::  to accept it or types another interface name.
::
::  Success is verified against the real configuration instead of trusting
::  netsh exit codes: netsh can report an error even when the change was
::  applied (observed deleting DHCP-assigned addresses).
::
::  Requests administrator privileges through the UAC prompt.
:: ===========================================================================

:: --------------------------------- elevate ----------------------------------
fltmc >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting administrator privileges, please accept the UAC prompt...
    powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: ------------------------ auto-detect active interface ----------------------
set "DETECTED="
for /f "tokens=*" %%i in ('powershell.exe -NoProfile -Command "(Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway } | Sort-Object { (Get-NetIPInterface -InterfaceIndex $_.InterfaceIndex -AddressFamily IPv4).InterfaceMetric } | Select-Object -First 1).InterfaceAlias"') do set "DETECTED=%%i"

if not defined DETECTED goto NO_DETECTION

echo Detected active interface: "!DETECTED!"
set "CHOICE="
set /p "CHOICE=Press ENTER to use it, or type another interface name: "
if defined CHOICE set "IFACE=!CHOICE!"
if not defined CHOICE set "IFACE=!DETECTED!"
goto VALIDATE_IFACE

:NO_DETECTION
echo [WARN] Could not detect the active interface automatically.
echo.
echo Available interfaces:
echo.
netsh interface show interface
echo.

:ASK_IFACE
set "IFACE="
set /p "IFACE=Type the name of the interface (example: Ethernet or Wi-Fi): "

:VALIDATE_IFACE
if not defined IFACE (
    echo [ERROR] The interface name cannot be empty.
    echo.
    goto ASK_IFACE
)
call :InterfaceExists "!IFACE!"
if errorlevel 1 (
    echo [ERROR] Interface "!IFACE!" was not found. Check the name and try again.
    echo.
    goto ASK_IFACE
)

:SHOW_CURRENT
echo.
echo ===========================================================================
echo    CHANGE IPv4 ADDRESS
echo ===========================================================================
echo.
echo Active interface: "!IFACE!"
echo.
echo IPv4 addresses currently assigned to "!IFACE!":
echo.
netsh interface ipv4 show addresses name="!IFACE!"
echo.

:: --------------------------- address to remove ------------------------------
:ASK_OLD_IP
set "OLDIP="
set /p "OLDIP=Type the IPv4 address you want to REMOVE (the preferred/primary one): "
if not defined OLDIP (
    echo [ERROR] The address cannot be empty.
    echo.
    goto ASK_OLD_IP
)
call :ValidateIPv4 "!OLDIP!"
if errorlevel 1 goto ASK_OLD_IP

call :AddressOnIface "!OLDIP!"
if not errorlevel 1 goto REMOVE_IT

echo.
echo [WARN] !OLDIP! is not assigned to "!IFACE!" - there is nothing to remove.
echo        The current addresses are listed above.
set "CONFIRM="
set /p "CONFIRM=Type Y to continue and only add the new address, or N to re-enter the address: "
if /i "!CONFIRM!"=="Y" goto ASK_NEW_IP
goto ASK_OLD_IP

:REMOVE_IT
echo.
echo Removing address !OLDIP! from interface "!IFACE!"...
netsh interface ipv4 delete address name="!IFACE!" addr=!OLDIP!

:: netsh exit codes are not reliable for this command: verify the real state.
ping -n 2 127.0.0.1 >nul
call :AddressOnIface "!OLDIP!"
if not errorlevel 1 goto REMOVE_FAILED
set "REMOVED=1"
echo [OK] Address !OLDIP! removed.
goto ASK_NEW_IP

:REMOVE_FAILED
echo.
echo [ERROR] The address !OLDIP! could not be removed from "!IFACE!".
echo         netsh reported the error shown above (if any). Nothing else was changed.
echo.
pause
exit /b 1

:: --------------------------- new address and mask ----------------------------
:ASK_NEW_IP
set "NEWIP="
set /p "NEWIP=Type the NEW IPv4 address you want to ASSIGN: "
if not defined NEWIP (
    echo [ERROR] The address cannot be empty.
    echo.
    goto ASK_NEW_IP
)
call :ValidateIPv4 "!NEWIP!"
if errorlevel 1 goto ASK_NEW_IP
call :AddressOnIface "!NEWIP!"
if not errorlevel 1 (
    echo [ERROR] !NEWIP! is already assigned to "!IFACE!". Type a different address.
    echo.
    goto ASK_NEW_IP
)

:ASK_MASK
set "MASK=255.255.255.0"
set /p "MASK=Type the subnet mask [press ENTER for 255.255.255.0]: "
call :ValidateIPv4 "!MASK!"
if errorlevel 1 goto ASK_MASK

echo.
echo Assigning !NEWIP! with mask !MASK! to interface "!IFACE!"...
netsh interface ipv4 add address name="!IFACE!" addr=!NEWIP! mask=!MASK!

:: verify the address really exists before declaring success
ping -n 2 127.0.0.1 >nul
call :AddressOnIface "!NEWIP!"
if not errorlevel 1 goto ADD_OK

echo.
echo [ERROR] The new address !NEWIP! could not be assigned to "!IFACE!".
if defined REMOVED (
    echo         Restoring the previous address !OLDIP! as a best effort...
    netsh interface ipv4 add address name="!IFACE!" addr=!OLDIP! >nul 2>&1
)
echo.
pause
exit /b 1

:ADD_OK
echo.
echo [OK] Address !NEWIP! assigned successfully.
echo.
echo Current IPv4 configuration of "!IFACE!":
echo.
netsh interface ipv4 show addresses name="!IFACE!"
echo.
echo Done. Press any key to close.
pause >nul
exit /b 0

:: ===========================================================================
::  InterfaceExists <name>
::  Returns 0 if the interface exists, 1 otherwise.
::  Uses PowerShell (not netsh output) so it works on any Windows language.
:: ===========================================================================
:InterfaceExists
powershell.exe -NoProfile -Command "if (Get-NetIPInterface -InterfaceAlias '%~1' -AddressFamily IPv4 -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }" >nul 2>&1
exit /b %errorlevel%

:: ===========================================================================
::  AddressOnIface <IPv4>
::  Returns 0 if the address is configured on !IFACE!, 1 otherwise.
:: ===========================================================================
:AddressOnIface
powershell.exe -NoProfile -Command "if (Get-NetIPAddress -InterfaceAlias '!IFACE!' -AddressFamily IPv4 -IPAddress '%~1' -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }" >nul 2>&1
exit /b %errorlevel%

:: ===========================================================================
::  ValidateIPv4 <address>
::  Returns 0 if the value has a valid a.b.c.d format (each octet 0-255),
::  returns 1 otherwise.
:: ===========================================================================
:ValidateIPv4
echo(%~1| findstr /r /c:"^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$" >nul
if errorlevel 1 (
    echo [ERROR] "%~1" is not a valid IPv4 address. Example: 192.168.1.50
    exit /b 1
)
for /f "tokens=1-4 delims=." %%a in ("%~1") do (
    if %%a gtr 255 goto InvalidIPv4
    if %%b gtr 255 goto InvalidIPv4
    if %%c gtr 255 goto InvalidIPv4
    if %%d gtr 255 goto InvalidIPv4
)
exit /b 0

:InvalidIPv4
echo [ERROR] "%~1" is not a valid IPv4 address. Each number must be between 0 and 255.
exit /b 1
