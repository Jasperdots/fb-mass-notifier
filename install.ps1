# Ensure script runs as Administrator
$AdminCheck = [System.Security.Principal.WindowsPrincipal] [System.Security.Principal.WindowsIdentity]::GetCurrent()
$AdminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator

if (-not $AdminCheck.IsInRole($AdminRole)) {
    if (-not $env:ADMIN_ELEVATED) {
        Write-Host "Requesting administrative privileges..."
        Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`" -NoProfile -WindowStyle Hidden -Command `$env:ADMIN_ELEVATED=1; & `"$PSCommandPath`"" -Verb RunAs
        exit
    }
}


# ======================== CONFIGURATION ========================
# ======================== CONFIGURATION ========================
$PYTHON_VERSION = "3.11.6"
$PYTHON_INSTALLER = "C:\Users\Administrator\Desktop\inst\python-$PYTHON_VERSION-amd64.exe"
$PYTHON_URL = "https://www.python.org/ftp/python/$PYTHON_VERSION/python-$PYTHON_VERSION-amd64.exe"
$PYTHON_INSTALL_PATH = "C:\Python311"
$REQUIRED_PIP_PACKAGES = @("mitmproxy", "requests", "cryptography", "urllib3", "pysocks", "python-dotenv", "configparser")


# Privoxy Configuration
$PRIVOXY_URL = "https://www.privoxy.org/sf-download-mirror/Win32/4.0.0%20%28stable%29/privoxy_setup_4.0.0.exe"
$PRIVOXY_INSTALLER = "$env:TEMP\privoxy_setup.exe"
$PRIVOXY_INSTALL_PATH = "C:\Program Files (x86)\Privoxy"

# Mitmproxy Configuration
$NUM_INSTANCES = 10
$MITM_START_PORT = 8081
$PRIVOXY_START_PORT = 8118
$ENV_FILE = "config.ini"


# Disable Windows Store Python Alias via Registry
Write-Host "Disabling Windows Store Python alias (if exists)..."
$PythonAliasPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\python.exe"
if (Test-Path $PythonAliasPath) {
    Remove-Item -Path $PythonAliasPath -Force
    Write-Host "Windows Store Python alias disabled."
} else {
    Write-Host "No Windows Store Python alias found."
}

# ======================== INSTALL PYTHON ========================
Write-Host "Checking if Python is installed..."
$PythonInstalled = $false
$PythonExecutable = $null

# Detect Python Installation
try {
    $DetectedPython = (Get-Command python -ErrorAction SilentlyContinue).Source
    if ($DetectedPython -and $DetectedPython -notmatch "WindowsApps") {
        $PythonExecutable = $DetectedPython
        $PythonInstalled = $true
    }
} catch { }

# Check Common Install Locations
$PythonPaths = @(
    "C:\Python311\python.exe",
    "C:\Program Files\Python311\python.exe",
    "C:\Program Files (x86)\Python311\python.exe"
)

foreach ($path in $PythonPaths) {
    if (Test-Path $path) {
        $PythonExecutable = $path
        $PythonInstalled = $true
        break
    }
}

# Try Installing with Windows Store (Winget)
if (-not $PythonInstalled) {
    Write-Host "Python not found. Attempting to install via Windows Store..."

    $WingetAvailable = $false
    try {
        $wingetCheck = winget --version 2>$null
        if ($wingetCheck) { $WingetAvailable = $true }
    } catch { }

    if ($WingetAvailable) {
        Write-Host "Winget detected. Installing Python via Windows Store..."
        winget install -e --id Python.Python.3.11 --silent
        Start-Sleep -Seconds 10  # Allow installation time

        # **🔹 FIX: Re-check if Python was installed via Winget**
        $PythonExecutable = (Get-Command python -ErrorAction SilentlyContinue).Source
        if ($PythonExecutable -and (Test-Path $PythonExecutable) -and $PythonExecutable -notmatch "WindowsApps") {
            $PythonInstalled = $true
            Write-Host "Python installed successfully via Windows Store: $PythonExecutable"
        } else {
            Write-Host "Winget installation failed or Python not detected yet, falling back to manual install..."
        }
    } else {
        Write-Host "Winget is not available. Falling back to manual installation..."
    }
}

# If Windows Store Install Fails, Download Python Manually
if (-not $PythonInstalled) {
    Write-Host "Downloading Python installer..."
    if (-not (Test-Path $PYTHON_INSTALLER)) {
        Invoke-WebRequest -Uri $PYTHON_URL -OutFile $PYTHON_INSTALLER

        if (-not (Test-Path $PYTHON_INSTALLER)) {
            Write-Host "Python installer failed to download. Check the URL!"
            exit 1
        }
    }

    Write-Host "Installing Python..."
    Start-Process -FilePath $PYTHON_INSTALLER -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1" -NoNewWindow -Wait
}

# Install PIP Packages
Write-Host "Installing pip packages..."
& $PythonExecutable -m pip install --upgrade pip
& $PythonExecutable -m pip install $REQUIRED_PIP_PACKAGES -join " "

Write-Host "Python setup completed successfully!"

# Ensure Python is in PATH
$env:Path += ";$PYTHON_INSTALL_PATH;$PYTHON_INSTALL_PATH\Scripts"

Write-Host "Verifying Python installation..."
$PythonVersion = & $PythonExecutable --version 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Python installation is not recognized. Try restarting PowerShell."
    exit 1
} else {
    Write-Host "Python installed successfully: $PythonVersion"
}

Write-Host "Installing pip packages..."
$REQUIRED_PIP_PACKAGES | ForEach-Object { & $PythonExecutable -m pip install $_ }

Write-Host "Python setup completed successfully!"

# ======================== PROMPT FOR SOCKS5 CREDENTIALS ========================
Write-Host "Enter SOCKS5 Proxy Credentials & Email Configs (Press Enter to use existing values):"

if (Test-Path $ENV_FILE) {
    $envVars = Get-Content $ENV_FILE | Where-Object { $_ -match "=" } | ForEach-Object {
        $parts = $_ -split "=", 2
        $name = $parts[0].Trim()
        $value = $parts[1].Trim()
        Set-Content -Path env:\$name -Value $value
    }
}

$SOCKS5_PROXY = Read-Host "Enter SOCKS5 Proxy IP" -Default $env:SOCKS5_PROXY
$SOCKS5_PORT = Read-Host "Enter SOCKS5 Port" -Default $env:SOCKS5_PORT
$SOCKS5_USER = Read-Host "Enter SOCKS5 Username" -Default $env:SOCKS5_USER
$SOCKS5_PASS = Read-Host "Enter SOCKS5 Password" -Default $env:SOCKS5_PASS -AsSecureString
$SOCKS5_PASS = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SOCKS5_PASS))

$SENDER = Read-Host "Enter E-mail Sender" -Default $env:SENDER
$M_PASSWORD = Read-Host "Enter E-mail Sender Password" -Default $env:M_PASSWORD - AsSecureString
$M_PASSWORD = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($M_PASSWORD))
$RECEIVER = Read-Host "Enter the Email you want to receive notifications" -Default $env:RECEIVER
$SMTP_SERVER = Read-Host "Enter SMTP Server" -Default $env:SMTP_SERVER
$SMTP_PORT = Read-Host "Enter SMTP Server (567)" -Default $env:SMTP_PORT



Write-Host "Saving credentials to .env file..."
@"
[SOCKS5]
PROXY=$SOCKS5_PROXY
PORT=$SOCKS5_PORT
USER=$SOCKS5_USER
PASS=$SOCKS5_PASS

[EMAIL]
SENDER=$SENDER
PASSWORD=$M_PASSWORD
RECEIVER=$RECEIVER
SMTP_SERVER=$SMTP_SERVER
SMTP_PORT=$SMTP_PORT
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

Write-Host "Starting Privoxy service..."
Start-Process -NoNewWindow -FilePath "$PRIVOXY_INSTALL_PATH\privoxy.exe"

if (-not (Get-Command mitmdump -ErrorAction SilentlyContinue)) {
    Write-Host "mitmdump not found! Installation failed."
    exit 1
} else {
    Write-Host "mitmproxy installed successfully."
}

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

Write-Host "Starting multiple mitmproxy instances..."
for ($i = 0; $i -lt $NUM_INSTANCES; $i++) {
    $mitmPort = $MITM_START_PORT + $i
    $privoxyPort = $PRIVOXY_START_PORT + $i
    Start-Process -NoNewWindow -FilePath "mitmdump" -ArgumentList "-s ws_mon.py --mode upstream:http://127.0.0.1:$privoxyPort -p $mitmPort"
    Write-Host "Started mitmproxy on port $mitmPort using Privoxy on $privoxyPort"
}

Write-Host "Setup completed successfully!"
Pause
