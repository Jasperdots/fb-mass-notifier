import subprocess
import time
import os
import signal

# Configuration
NUM_PROXIES = 10  # Number of Dolphin Anty browsers
START_PORT = 8080  # Base port for proxies
PROXY_FILE = "proxies.txt"
SCRIPT_NAME = "ws_mon.py"

# Store running processes
processes = []

def start_mitmproxy_instances():
    """Start multiple mitmdump processes on different ports and attach monitoring script."""
    proxies = []
    env = os.environ.copy()  # Ensure environment variables are inherited
    log_file = open("mitmproxy.log", "w")

    for i in range(NUM_PROXIES):
        port = START_PORT + i
        command = f"mitmdump -s {SCRIPT_NAME} -p {port} --set websocket=true -v"
        print(f"Starting mitmdump on port {port}...")

        # Start process
        subprocess.run(command, shell=True, env=env)
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
        process.terminate()
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
