# Ensure script runs as Administrator
$AdminCheck = [System.Security.Principal.WindowsPrincipal] [System.Security.Principal.WindowsIdentity]::GetCurrent()
$AdminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator

if (-not $AdminCheck.IsInRole($AdminRole)) {
    Write-Host "Requesting administrative privileges..."
    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# ======================== CONFIGURATION ========================
$PYTHON_VERSION = "3.11.6"
$PYTHON_INSTALLER = "python-$PYTHON_VERSION-amd64.exe"
$PYTHON_URL = "https://www.python.org/ftp/python/$PYTHON_VERSION/$PYTHON_INSTALLER"
$PYTHON_INSTALL_PATH = "C:\Python311"

# Required pip modules (including socks5 support)
$REQUIRED_PIP_PACKAGES = @("mitmproxy", "requests", "cryptography", "urllib3", "pysocks", "python-dotenv")

# Privoxy Configuration
$PRIVOXY_URL = "https://www.privoxy.org/sf-download-mirror/Win32/4.0.0%20%28stable%29/privoxy_setup_4.0.0.exe"
$PRIVOXY_INSTALLER = "$env:TEMP\privoxy_setup.exe"
$PRIVOXY_INSTALL_PATH = "C:\Privoxy"

# Mitmproxy Configuration
$NUM_INSTANCES = 10
$MITM_START_PORT = 8081
$PRIVOXY_START_PORT = 8118
$ENV_FILE = ".env"

# ======================== PROMPT FOR SOCKS5 CREDENTIALS ========================
Write-Host "Enter SOCKS5 Proxy Credentials (Press Enter to use existing values):"

# Load existing values from .env if it exists
if (Test-Path $ENV_FILE) {
    $envVars = Get-Content $ENV_FILE | Where-Object { $_ -match "=" } | ForEach-Object {
        $parts = $_ -split "=", 2
        $name = $parts[0].Trim()
        $value = $parts[1].Trim()
        Set-Content -Path env:\$name -Value $value
    }
}

# Prompt user for SOCKS5 Proxy details
$SOCKS5_PROXY = Read-Host "Enter SOCKS5 Proxy IP" -Default $env:SOCKS5_PROXY
$SOCKS5_PORT = Read-Host "Enter SOCKS5 Port" -Default $env:SOCKS5_PORT
$SOCKS5_USER = Read-Host "Enter SOCKS5 Username" -Default $env:SOCKS5_USER
$SOCKS5_PASS = Read-Host "Enter SOCKS5 Password" -Default $env:SOCKS5_PASS -AsSecureString
$SOCKS5_PASS = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SOCKS5_PASS))

# Store credentials in .env file
Write-Host "Saving credentials to .env file..."
@"
SOCKS5_PROXY=$SOCKS5_PROXY
SOCKS5_PORT=$SOCKS5_PORT
SOCKS5_USER=$SOCKS5_USER
SOCKS5_PASS=$SOCKS5_PASS
"@ | Set-Content -Path $ENV_FILE -Encoding UTF8

Write-Host "Credentials saved successfully!"

# ======================== INSTALL PRIVOXY ========================
if (-not (Test-Path "$PRIVOXY_INSTALL_PATH\privoxy.exe")) {
    Write-Host "Downloading Privoxy..."
    Invoke-WebRequest -Uri $PRIVOXY_URL -OutFile $PRIVOXY_INSTALLER
    Write-Host "Installing Privoxy..."
    Start-Process -FilePath $PRIVOXY_INSTALLER -ArgumentList "/S" -Wait
} else {
    Write-Host "Privoxy is already installed."
}

# ======================== CONFIGURE PRIVOXY FOR MULTIPLE PORTS ========================
Write-Host "Configuring Privoxy..."
$PrivoxyConfig = @()

for ($i = 0; $i -lt $NUM_INSTANCES; $i++) {
    $port = $PRIVOXY_START_PORT + $i
    $PrivoxyConfig += @"
listen-address 127.0.0.1:$port
forward-socks5 / ${SOCKS5_PROXY}:${SOCKS5_PORT} .
"@
}

$PrivoxyConfig -join "`n" | Set-Content -Path "$PRIVOXY_INSTALL_PATH\config" -Encoding UTF8
Write-Host "Privoxy configured to use multiple ports."

# Start Privoxy Service
Write-Host "Starting Privoxy service..."
Start-Process -NoNewWindow -FilePath "$PRIVOXY_INSTALL_PATH\privoxy.exe"

# ======================== VERIFY MITMPROXY INSTALLATION ========================
if (-not (Get-Command mitmdump -ErrorAction SilentlyContinue)) {
    Write-Host "mitmdump not found! Installation failed."
    exit 1
} else {
    Write-Host "mitmproxy installed successfully."
}

# ======================== INSTALL MITMPROXY CERTIFICATE ========================
Write-Host "Running mitmproxy to generate CA Certificate..."
Start-Process -NoNewWindow -FilePath "mitmdump" -ArgumentList "--set block_global=false"
Start-Sleep -Seconds 5
Stop-Process -Name "mitmdump" -Force -ErrorAction SilentlyContinue

Write-Host "Installing mitmproxy CA Certificate..."
$certPath = "$env:USERPROFILE\.mitmproxy\mitmproxy-ca-cert.pem"
if (Test-Path $certPath) {
    Start-Process -NoNewWindow -FilePath "certutil" -ArgumentList "-addstore -f ROOT `"$certPath`"" -Wait
    Write-Host "mitmproxy CA Certificate installed successfully."
} else {
    Write-Host "mitmproxy CA Certificate not found!"
}

# ======================== START MULTIPLE MITMPROXY INSTANCES ========================
Write-Host "Starting multiple mitmproxy instances..."
for ($i = 0; $i -lt $NUM_INSTANCES; $i++) {
    $mitmPort = $MITM_START_PORT + $i
    $privoxyPort = $PRIVOXY_START_PORT + $i
    Start-Process -NoNewWindow -FilePath "mitmdump" -ArgumentList "-s ws_mon.py --mode upstream:http://127.0.0.1:$privoxyPort -p $mitmPort"
    Write-Host "Started mitmproxy on port $mitmPort using Privoxy on $privoxyPort"
}

# ======================== FINAL CHECK ========================
Write-Host "Setup completed successfully!"
Write-Host "Mitmproxy instances running on ports 8081-8090"
Write-Host "Privoxy instances running on ports 8118-8127"
Pause
