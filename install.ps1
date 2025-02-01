# Ensure script runs as Administrator
$AdminCheck = [System.Security.Principal.WindowsPrincipal] [System.Security.Principal.WindowsIdentity]::GetCurrent()
$AdminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator

if (-not $AdminCheck.IsInRole($AdminRole)) {
    Write-Host "Requesting administrative privileges..."
    Start-Process powershell.exe -ArgumentList "-File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# ======================== CONFIGURATION ========================
$PYTHON_VERSION = "3.11.6"
$PYTHON_INSTALLER = "python-$PYTHON_VERSION-amd64.exe"
$PYTHON_URL = "https://www.python.org/ftp/python/$PYTHON_VERSION/$PYTHON_INSTALLER"
$PYTHON_INSTALL_PATH = "C:\Python311"

# ProxyChains Configuration
$PROXYCHAINS_URL = "https://github.com/shunf4/proxychains-windows/releases/download/4.1/proxychains-4.1.zip"
$PROXYCHAINS_FOLDER = "C:\ProxyChains4"
$PROXYCHAINS_CONF = "$PROXYCHAINS_FOLDER\proxychains.conf"

# SOCKS5 Proxy Settings
$SOCKS5_PROXY = "5.161.23.7"
$SOCKS5_PORT = "15729"
$SOCKS5_USER = "bsktiger8288"
$SOCKS5_PASS = "Natashakhan000"

# Required pip modules
$REQUIRED_PIP_PACKAGES = @("mitmproxy", "requests", "cryptography", "urllib3")

# ======================== VERIFY PYTHON INSTALLATION ========================
$pythonInstalled = $false
$pythonPath = ""

try {
    $pythonPath = (Get-Command python -ErrorAction SilentlyContinue).Source
    if ($pythonPath) { $pythonInstalled = $true }
} catch {}

if (-not $pythonInstalled) {
    Write-Host "Python is missing! Downloading and installing Python $PYTHON_VERSION..."

    # Download Python Installer
    $installerPath = "$env:TEMP\$PYTHON_INSTALLER"
    Invoke-WebRequest -Uri $PYTHON_URL -OutFile $installerPath

    # Run Python Installer Silently
    Start-Process -FilePath $installerPath -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0" -Wait

    # Verify Installation
    $pythonPath = (Get-Command python -ErrorAction SilentlyContinue).Source
    if (-not $pythonPath) {
        Write-Host "Python installation failed!"
        exit 1
    } else {
        Write-Host "Python installed successfully at $pythonPath."
    }
} else {
    Write-Host "Python is already installed at $pythonPath."
}

# Refresh PATH to ensure Python & Scripts directory are accessible
$env:Path += ";$PYTHON_INSTALL_PATH;$PYTHON_INSTALL_PATH\Scripts"

# ======================== INSTALL PIP PACKAGES ========================
Write-Host "Installing required pip packages..."
python -m pip install --upgrade pip
foreach ($pkg in $REQUIRED_PIP_PACKAGES) {
    if (-not (python -m pip show $pkg 2>$null)) {
        Write-Host "Installing: $pkg..."
        python -m pip install $pkg
    } else {
        Write-Host "$pkg is already installed."
    }
}

# ======================== INSTALL PROXYCHAINS4 ========================
if (-not (Test-Path $PROXYCHAINS_FOLDER)) {
    Write-Host "Downloading ProxyChains4 for Windows..."
    $ZipFile = "$env:TEMP\proxychains4.zip"
    
    Invoke-WebRequest -Uri $PROXYCHAINS_URL -OutFile $ZipFile -ErrorAction Stop
    Write-Host "ProxyChains4 downloaded."

    Expand-Archive -Path $ZipFile -DestinationPath $PROXYCHAINS_FOLDER -Force
    Remove-Item -Path $ZipFile -Force
    Write-Host " ProxyChains4 extracted to: $PROXYCHAINS_FOLDER"
} else {
    Write-Host " ProxyChains4 is already installed."
}

# ======================== ADD PROXYCHAINS TO SYSTEM PATH ========================
$CurrentPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
if ($CurrentPath -notlike "*$PROXYCHAINS_FOLDER*") {
    Write-Host " Adding ProxyChains4 to system PATH..."
    [System.Environment]::SetEnvironmentVariable("Path", "$CurrentPath;$PROXYCHAINS_FOLDER", "Machine")
    Write-Host "ProxyChains4 added to PATH. Restart your terminal for changes to take effect."
} else {
    Write-Host " ProxyChains4 is already in system PATH."
}

# ======================== CONFIGURE PROXYCHAINS4 ========================
Write-Host "⚙ Configuring ProxyChains4..."
@"
strict_chain
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000

[ProxyList]
socks5  $SOCKS5_PROXY  $SOCKS5_PORT  $SOCKS5_USER  $SOCKS5_PASS
"@ | Set-Content -Path $PROXYCHAINS_CONF -Encoding UTF8

Write-Host "ProxyChains4 configuration updated."

# ======================== VERIFY MITMPROXY INSTALLATION ========================
if (-not (Get-Command mitmdump -ErrorAction SilentlyContinue)) {
    Write-Host " mitmdump not found! Installation failed."
    exit 1
} else {
    Write-Host " mitmproxy installed successfully."
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
    Write-Host " mitmproxy CA Certificate installed successfully."
} else {
    Write-Host " mitmproxy CA Certificate not found!"
}

# ======================== FINAL CHECK ========================
Write-Host "ProxyChains4, Python, and dependencies installed successfully!"
python -m pip list
Write-Host " You can now use ProxyChains without specifying the full path!"
Write-Host " Example command:"
Write-Host "proxychains4 python your_script.py"
Pause
