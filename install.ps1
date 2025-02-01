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

# Required pip modules (excluding built-ins)
$REQUIRED_PIP_PACKAGES = @(
    "mitmproxy", "requests", "cryptography", "urllib3"
)

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

# Verify Python accessibility
try {
    python --version
} catch {
    Write-Host "Python installation failed!"
    exit 1
}

# ======================== GET PRE-INSTALLED PYTHON MODULES ========================
$preInstalledModules = python -c "import sys; print(','.join(sys.builtin_module_names))" 2>$null
$builtInModules = $preInstalledModules -split ','

# Filter out pre-installed modules from the required list
$filteredPipPackages = $REQUIRED_PIP_PACKAGES | Where-Object { $_ -notin $builtInModules }

# ======================== INSTALL PIP PACKAGES ========================
Write-Host "Installing required pip packages..."
python -m pip install --upgrade pip
foreach ($pkg in $filteredPipPackages) {
    if (-not (python -m pip show $pkg 2>$null)) {
        Write-Host "Installing: $pkg..."
        python -m pip install $pkg
    } else {
        Write-Host "$pkg is already installed."
    }
}

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

# ======================== FINAL CHECK ========================
Write-Host "Python and dependencies installed successfully!"
python -m pip list
Pause
