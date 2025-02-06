import subprocess
import time
import os
import signal
import sys
import configparser
from dotenv import load_dotenv

config = configparser.ConfigParser()
config.read("config.ini")

# Configuration
NUM_PROXIES = 10  # Number of instances
START_MITMPROXY_PORT = 8081  # mitmproxy ports
START_PRIVOXY_PORT = 8118  # Privoxy ports
PRIVOXY_CONFIG_DIR = "C:\\Program Files (x86)\\Privoxy"
PRIVOXY_EXECUTABLE = os.path.join(PRIVOXY_CONFIG_DIR, "privoxy.exe")

# SOCKS5 Proxy Credentials from config.ini
try:
    SOCKS5_PROXY = config["SOCKS5"]["PROXY"]
    SOCKS5_PORT = int(config["SOCKS5"]["PORT"])
    SOCKS5_USER = config["SOCKS5"].get("USER", "")
    SOCKS5_PASS = config["SOCKS5"].get("PASS", "")
except KeyError as e:
    print(f"ERROR: Missing SOCKS5 config value: {e}")
    exit(1)

# Email Configuration from config.ini
try:
    EMAIL_SENDER = config["EMAIL"]["SENDER"]
    EMAIL_PASSWORD = config["EMAIL"]["PASSWORD"]
    EMAIL_RECEIVER = config["EMAIL"]["RECEIVER"]
    SMTP_SERVER = config["EMAIL"]["SMTP_SERVER"]
    SMTP_PORT = int(config["EMAIL"]["SMTP_PORT"])
except KeyError as e:
    print(f"ERROR: Missing EMAIL config value: {e}")
    exit(1)


# Store running processes
mitmproxy_processes = []
privoxy_processes = []

def generate_privoxy_config(port):
    """Generates a unique Privoxy configuration file for each instance."""
    config_content = f"""
accept-intercepted-requests 1
listen-address  127.0.0.1:{port}
forward-socks5 / {SOCKS5_USER}:{SOCKS5_PASS}@{SOCKS5_PROXY}:{SOCKS5_PORT} .
    """.strip()

    config_path = os.path.join(PRIVOXY_CONFIG_DIR, f"config-{port}.txt")
    with open(config_path, "w") as f:
        f.write(config_content)

    return config_path

def start_privoxy_instances():
    """Start multiple Privoxy instances with different configurations."""
    print("Starting Privoxy instances...")

    for i in range(NUM_PROXIES):
        privoxy_port = START_PRIVOXY_PORT + i
        config_path = generate_privoxy_config(privoxy_port)

        # Start Privoxy with the specific config file
        command = f'"{PRIVOXY_EXECUTABLE}" --config-file "{config_path}"'
        process = subprocess.Popen(command, shell=True)

        privoxy_processes.append(process)
        print(f"Privoxy started on port {privoxy_port} using {config_path}")

def start_mitmproxy_instances():
    """Start multiple mitmdump instances, each using a different Privoxy instance."""
    print("Starting mitmproxy instances...")

    for i in range(NUM_PROXIES):
        mitmproxy_port = START_MITMPROXY_PORT + i
        privoxy_port = START_PRIVOXY_PORT + i
        log_file = open(f"mitmproxy_{mitmproxy_port}.log", "w")

        # Mitmproxy command with upstream Privoxy proxy
        command = f"mitmdump -s ws_mon.py -p {mitmproxy_port} --set websocket=true --mode upstream:http://127.0.0.1:{privoxy_port}"
        process = subprocess.Popen(command, shell=True, stdout=log_file, stderr=log_file)

        mitmproxy_processes.append(process)
        print(f"mitmproxy started on port {mitmproxy_port}, using Privoxy on {privoxy_port}")

def cleanup_processes(signum=None, frame=None):
    """Terminate all running mitmdump and Privoxy instances gracefully."""
    print("\n[!] Stopping all proxies...")

    for process in mitmproxy_processes:
        try:
            process.terminate()
        except Exception as e:
            print(f"Error stopping mitmproxy: {e}")

    for process in privoxy_processes:
        try:
            process.terminate()
        except Exception as e:
            print(f"Error stopping privoxy: {e}")

    time.sleep(1)

    os.system("taskkill /F /IM mitmdump.exe >nul 2>&1")
    os.system("taskkill /F /IM privoxy.exe >nul 2>&1")

    print("[✔] All proxies stopped.")
    sys.exit(0)

# Handle Ctrl+C and termination signals
signal.signal(signal.SIGINT, cleanup_processes)
signal.signal(signal.SIGTERM, cleanup_processes)

# Run script
try:
    start_privoxy_instances()
    time.sleep(2)  # Small delay to allow Privoxy to start
    start_mitmproxy_instances()

    print("[*] Proxies running. Press Ctrl+C to stop.")
    while True:
        time.sleep(1)
except KeyboardInterrupt:
    cleanup_processes()
