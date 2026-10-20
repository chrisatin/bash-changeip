@echo off
setlocal EnableDelayedExpansion
title Change IPv4 Address
color 0A

:: ===========================================================================
::  CHANGE IPv4 ADDRESS
::
::  Uses PowerShell cmdlets (Remove-NetIPAddress / New-NetIPAddress) wrapped
::  inside this batch file, which are more reliable than netsh for deleting
::  addresses (netsh can fail on DHCP-assigned or "preferred" addresses).
::
::  Runs:
::    Remove-NetIPAddress -InterfaceAlias "<iface>" -IPAddress <old-ip>
::    New-NetIPAddress    -InterfaceAlias "<iface>" -IPAddress <new-ip> -PrefixLength <n>
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
echo Running PowerShell commands...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$iface='!IFACE!'; $oldip='!OLDIP!'; $newip='!NEWIP!'; $mask='!MASK!'; " ^
  "Write-Host ('Removing ' + $oldip + ' from ' + $iface); " ^
  "try { Remove-NetIPAddress -InterfaceAlias $iface -IPAddress $oldip -Confirm:$false -ErrorAction Stop; Write-Host '  removed.' } catch { Write-Host ('  FAILED: ' + $_.Exception.Message); if ($_.Exception.Message -match 'DHCP') { Write-Host '  Hint: this address may be DHCP-assigned. Try: ipconfig /release' } }; " ^
  "Start-Sleep -Seconds 1; " ^
  "$bytes = ([System.Net.IPAddress]::Parse($mask)).GetAddressBytes(); " ^
  "$prefix = (($bytes | ForEach-Object { [Convert]::ToString($_,2).PadLeft(8,'0') }) -join '').TrimEnd('0').Length; " ^
  "Write-Host ('Adding ' + $newip + '/' + $prefix + ' to ' + $iface); " ^
  "try { New-NetIPAddress -InterfaceAlias $iface -IPAddress $newip -PrefixLength $prefix -ErrorAction Stop | Out-Null; Write-Host '  added.' } catch { Write-Host ('  FAILED: ' + $_.Exception.Message) }; " ^
  "Write-Host ''; Write-Host ('Current IPv4 on ' + $iface + ':'); " ^
  "Get-NetIPAddress -InterfaceAlias $iface -AddressFamily IPv4 | Select-Object -ExpandProperty IPAddress"

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
