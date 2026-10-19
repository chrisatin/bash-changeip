@echo off
setlocal EnableDelayedExpansion
title Change IPv4 Address
color 0A

:: ===========================================================================
::  CHANGE IPv4 ADDRESS
::
::  Runs exactly:
::    netsh interface ipv4 delete address "Interface" OldIP
::    netsh interface ipv4 add address    "Interface" NewIP SubnetMask
:: ===========================================================================

:: --------------------------------- elevate ----------------------------------
fltmc >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting administrator privileges, please accept the UAC prompt...
    powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: ------------------------------- interface ---------------------------------
set "IFACE=Ethernet"
set /p "IFACE=Interface name [press ENTER for Ethernet]: "
if "!IFACE!"=="" set "IFACE=Ethernet"

call :InterfaceExists "!IFACE!"
if errorlevel 1 (
    echo [ERROR] Interface "!IFACE!" was not found.
    pause
    exit /b 1
)

echo.
netsh interface ipv4 show addresses name="!IFACE!"
echo.

:: ------------------------------- old IP ------------------------------------
set "OLDIP="
set /p "OLDIP=Type the IPv4 address to DELETE: "
if not defined OLDIP (
    echo [ERROR] The IP address cannot be empty.
    pause
    exit /b 1
)
call :ValidateIPv4 "!OLDIP!"
if errorlevel 1 (
    pause
    exit /b 1
)

:: ------------------------------- new IP ------------------------------------
set "NEWIP="
set /p "NEWIP=Type the NEW IPv4 address to ADD: "
if not defined NEWIP (
    echo [ERROR] The IP address cannot be empty.
    pause
    exit /b 1
)
call :ValidateIPv4 "!NEWIP!"
if errorlevel 1 (
    pause
    exit /b 1
)

:: ------------------------------- subnet mask -------------------------------
set "MASK=255.255.255.0"
set /p "MASK=Subnet mask [press ENTER for 255.255.255.0]: "
if "!MASK!"=="" set "MASK=255.255.255.0"
call :ValidateIPv4 "!MASK!"
if errorlevel 1 (
    pause
    exit /b 1
)

:: ------------------------------- execute -----------------------------------
echo.
echo Executing the following commands:
echo   netsh interface ipv4 delete address "!IFACE!" !OLDIP!
echo   netsh interface ipv4 add address    "!IFACE!" !NEWIP! !MASK!
echo.

netsh interface ipv4 delete address "!IFACE!" !OLDIP!
ping -n 1 127.0.0.1 >nul

netsh interface ipv4 add address "!IFACE!" !NEWIP! !MASK!
ping -n 1 127.0.0.1 >nul

:: ------------------------------- verify -------------------------------------
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
:: ===========================================================================
:InterfaceExists
powershell.exe -NoProfile -Command "if (Get-NetIPInterface -InterfaceAlias '%~1' -AddressFamily IPv4 -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }" >nul 2>&1
exit /b %errorlevel%

:: ===========================================================================
::  ValidateIPv4 <address>
::  Returns 0 if valid a.b.c.d (0-255), 1 otherwise.
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
