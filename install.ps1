# Ensure script runs as Administrator
$AdminCheck = [System.Security.Principal.WindowsPrincipal] [System.Security.Principal.WindowsIdentity]::GetCurrent()
$AdminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator

if (-not $AdminCheck.IsInRole($AdminRole)) {
    Write-Host "Requesting administrative privileges..."
    Start-Process powershell.exe -ArgumentList "-File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Define Python version
$PYTHON_VERSION = "3.11.6"
$PYTHON_INSTALLER = "python-$PYTHON_VERSION-amd64.exe"
$PYTHON_URL = "https://www.python.org/ftp/python/$PYTHON_VERSION/$PYTHON_INSTALLER"

# List of required pip modules
$PIP_PACKAGES = @(
    "mitmproxy", "smtplib", "ssl", "logging", "email",
    "subprocess", "time", "os", "signal", "json", "re",
    "urllib3", "cryptography"
)

# Check if Python is installed
$pythonInstalled = $false
try {
    $pythonVersion = python --version 2>$null
    if ($pythonVersion) { $pythonInstalled = $true }
} catch {}

if (-not $pythonInstalled) {
    Write-Host "Downloading Python..."
    Invoke-WebRequest -Uri $PYTHON_URL -OutFile $PYTHON_INSTALLER

    Write-Host "Installing Python..."
    Start-Process -FilePath $PYTHON_INSTALLER -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0" -Wait
    Remove-Item $PYTHON_INSTALLER -Force

    Write-Host "Python installation completed."
} else {
    Write-Host "Python is already installed."
}

# Refresh PATH (Ensures Python is recognized in current session)
$env:Path += ";C:\Python311\Scripts;C:\Python311"

# Check Python installation
try {
    python --version
} catch {
    Write-Host "Python installation failed!"
    exit 1
}

# Install required pip packages
Write-Host "Installing required pip packages..."
python -m pip install --upgrade pip
foreach ($pkg in $PIP_PACKAGES) {
    python -m pip install $pkg
}

# Verify mitmproxy installation
if (-not (Get-Command mitmdump -ErrorAction SilentlyContinue)) {
    Write-Host "❌ mitmdump not found! Installation failed."
    exit 1
}

# Download mitmproxy CA Certificate
Write-Host "Running mitmproxy to generate CA Certificate..."
Start-Process -NoNewWindow -FilePath "mitmdump" -ArgumentList "--set block_global=false"
Start-Sleep -Seconds 5
Stop-Process -Name "mitmdump" -Force

# Install mitmproxy CA Certificate
Write-Host "Installing mitmproxy CA Certificate..."
$certPath = "$env:USERPROFILE\.mitmproxy\mitmproxy-ca-cert.pem"
if (Test-Path $certPath) {
    certutil -addstore -f "ROOT" $certPath
} else {
    Write-Host "❌ mitmproxy CA Certificate not found!"
}

# Final check
Write-Host "✅ Python and dependencies installed successfully!"
python -m pip list
Pause
