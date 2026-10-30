# One-time project setup. Run from this folder:
#   powershell -ExecutionPolicy Bypass -File setup.ps1
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host 'Flutter is not installed or not on PATH. Follow SETUP.md steps 1-2 first.' -ForegroundColor Red
    exit 1
}

Write-Host '1/4  Generating the Android project files...' -ForegroundColor Cyan
# Only creates missing files; our lib/ code and pubspec.yaml are kept.
flutter create --org com.nosignal --project-name nosignal_sos --platforms android .

# The template's sample test refers to a widget we don't have.
if (Test-Path 'test\widget_test.dart') { Remove-Item 'test\widget_test.dart' }

Write-Host '2/4  Adding Bluetooth / Wi-Fi / location permissions...' -ForegroundColor Cyan
$manifestPath = 'android\app\src\main\AndroidManifest.xml'
$manifest = [IO.File]::ReadAllText((Resolve-Path $manifestPath))
if ($manifest -notmatch 'BLUETOOTH_SCAN') {
    $permissions = @'
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
    <uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
    <uses-permission android:name="android.permission.NEARBY_WIFI_DEVICES" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />

'@
    $manifest = ([regex]'<application').Replace($manifest, $permissions + '    <application', 1)
    [IO.File]::WriteAllText((Resolve-Path $manifestPath), $manifest, (New-Object Text.UTF8Encoding $false))
}

Write-Host '3/4  Downloading packages...' -ForegroundColor Cyan
flutter pub get

Write-Host '4/4  Checking your setup...' -ForegroundColor Cyan
flutter doctor

Write-Host ''
Write-Host 'Done! Next: put your Firebase URL in lib\config.dart, then follow SETUP.md step 6.' -ForegroundColor Green
