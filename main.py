import subprocess
import time
import os
import signal

# Configuration
NUM_PROXIES = 10  # Number of mitmdump instances
START_PORT = 8080  # Base port for proxies
PROXY_FILE = "proxies.txt"
SCRIPT_NAME = "ws_mon.py"

# Store running processes
processes = []

def start_mitmproxy_instances():
    """Start multiple mitmdump instances on different ports and attach monitoring script."""
    proxies = []
    env = os.environ.copy()  # Ensure environment variables are inherited

    for i in range(NUM_PROXIES):
        port = START_PORT + i
        log_file = open(f"mitmproxy_{port}.log", "w")  # Separate log for each instance
        command = f"mitmdump -s {SCRIPT_NAME} -p {port} --set block_global=false"

        print(f"Starting mitmdump on port {port}...")

        # Start process with Popen to allow multiple instances
        process = subprocess.Popen(command, shell=True, env=env, stdout=log_file, stderr=log_file)
        processes.append(process)

        # Store proxy info
        proxies.append(f"127.0.0.1:{port}")

        time.sleep(0.5)  # Small delay for stability

    # Write proxies to file
    with open(PROXY_FILE, "w") as f:
        f.write("\n".join(proxies))

    print(f"Proxies saved to {PROXY_FILE}")

def cleanup_processes():
    """Terminate all running mitmdump instances."""
    print("\nStopping all mitmdump processes...")
    for process in processes:
        process.kill()  # Use kill instead of terminate for better cleanup

    time.sleep(1)  # Give processes time to exit

    # Cross-platform process cleanup
    if os.name == "nt":  # Windows
        os.system("taskkill /F /IM mitmdump.exe")
    else:  # Linux/Mac
        os.system("pkill -f mitmdump")

    print("All proxies stopped.")

# Run script
try:
    start_mitmproxy_instances()
    print("Press Ctrl+C to stop all proxies.")
    while True:
        time.sleep(1)
except KeyboardInterrupt:
    cleanup_processes()
    print("All proxies stopped.")
