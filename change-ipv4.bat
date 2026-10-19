@echo off
setlocal EnableDelayedExpansion
title Change IPv4 Address
color 0A

:: ===========================================================================
::  CHANGE IPv4 ADDRESS
::
::  Removes the IPv4 address currently assigned to the active network
::  interface (the preferred/primary one) and assigns a new address typed
::  by the user, together with its subnet mask.
::
::  The active interface is auto-detected (the one with the default
::  gateway and the lowest metric). If it cannot be detected, the script
::  asks for its name.
::
::  Designed for Windows systems where multiple IPv4 addresses are enabled
::  on the same interface and you want to swap the preferred one.
::
::  The script requests administrator privileges through the UAC prompt.
:: ===========================================================================

:: --------------------------------- elevate ----------------------------------
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting administrator privileges, please accept the UAC prompt...
    powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: ------------------------ auto-detect active interface ----------------------
set "IFACE="
for /f "tokens=*" %%i in ('powershell.exe -NoProfile -Command "(Get-NetIPConfiguration ^| Where-Object { $_.IPv4DefaultGateway } ^| Sort-Object { (Get-NetIPInterface -InterfaceIndex $_.InterfaceIndex -AddressFamily IPv4).InterfaceMetric } ^| Select-Object -First 1).InterfaceAlias"') do set "IFACE=%%i"

if defined IFACE goto SHOW_CURRENT

:: ------------------------------ fallback path -------------------------------
echo [WARN] Could not auto-detect the active interface.
echo.
echo Available interfaces:
echo.
netsh interface show interface
echo.

:ASK_IFACE
set "IFACE="
set /p "IFACE=Type the name of the interface (example: Ethernet or Wi-Fi): "
if not defined IFACE (
    echo [ERROR] The interface name cannot be empty.
    echo.
    goto ASK_IFACE
)
netsh interface ipv4 show addresses name="!IFACE!" 2>&1 | findstr /i /c:"Configuration for interface" >nul
if errorlevel 1 (
    echo [ERROR] Interface "!IFACE!" was not found. Check the list above and try again.
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

echo.
echo Removing address !OLDIP! from interface "!IFACE!"...
netsh interface ipv4 delete address name="!IFACE!" addr=!OLDIP!
if errorlevel 1 (
    echo.
    echo [ERROR] The address !OLDIP! could not be removed.
    echo         Make sure it is assigned to the interface "!IFACE!".
    echo.
    pause
    exit /b 1
)
echo [OK] Address !OLDIP! removed.

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
if "!NEWIP!"=="!OLDIP!" (
    echo [ERROR] The new address is the same as the one just removed. Type a different address.
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
if errorlevel 1 (
    echo.
    echo [ERROR] The new address could not be assigned.
    echo         Restoring the previous address !OLDIP! as a best effort...
    netsh interface ipv4 add address name="!IFACE!" addr=!OLDIP! >nul 2>&1
    echo.
    pause
    exit /b 1
)

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
