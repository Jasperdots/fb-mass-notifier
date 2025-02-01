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

# List of required pip modules
$PIP_PACKAGES = @(
    "mitmproxy", "requests", "smtplib", "ssl", "logging", "email",
    "subprocess", "time", "os", "signal", "json", "re",
    "urllib3", "cryptography"
)

# ======================== INSTALL PYTHON ========================
$pythonInstalled = $false
try {
    $pythonVersion = python --version 2>$null
    if ($pythonVersion) { $pythonInstalled = $true }
} catch {}

if (-not $pythonInstalled) {
    Write-Host "Python is missing! Please install Python $PYTHON_VERSION manually."
    exit 1
} else {
    Write-Host "✅ Python is already installed."
}

# Refresh PATH (Ensures Python is recognized in current session)
$env:Path += ";C:\Python311\Scripts;C:\Python311"

# Check Python installation
try {
    python --version
} catch {
    Write-Host "❌ Python installation failed!"
    exit 1
}

# ======================== INSTALL PIP PACKAGES ========================
Write-Host "📦 Installing required pip packages..."
python -m pip install --upgrade pip
foreach ($pkg in $PIP_PACKAGES) {
    python -m pip install $pkg
}

# Verify mitmproxy installation
if (-not (Get-Command mitmdump -ErrorAction SilentlyContinue)) {
    Write-Host "❌ mitmdump not found! Installation failed."
    exit 1
} else {
    Write-Host "✅ mitmproxy installed successfully."
}

# ======================== INSTALL MITMPROXY CERTIFICATE ========================
Write-Host "🔑 Running mitmproxy to generate CA Certificate..."
Start-Process -NoNewWindow -FilePath "mitmdump" -ArgumentList "--set block_global=false"
Start-Sleep -Seconds 5
Stop-Process -Name "mitmdump" -Force

Write-Host "🔏 Installing mitmproxy CA Certificate..."
$certPath = "$env:USERPROFILE\.mitmproxy\mitmproxy-ca-cert.pem"
if (Test-Path $certPath) {
    certutil -addstore -f "ROOT" $certPath
    Write-Host "✅ mitmproxy CA Certificate installed successfully."
} else {
    Write-Host "❌ mitmproxy CA Certificate not found!"
}

# ======================== FINAL CHECK ========================
Write-Host "🎉 Python and dependencies installed successfully!"
python -m pip list
Pause
