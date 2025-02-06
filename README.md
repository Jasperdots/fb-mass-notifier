FB Mass Notifier - Installation & Usage Guide

Introduction

FB Mass Notifier is a tool that monitors Facebook notifications and sends email alerts when certain events occur. It uses mitmproxy to intercept network traffic and Privoxy to handle proxy configurations. This guide provides a step-by-step installation and usage manual for setting up and running the tool on Windows.

Prerequisites

System Requirements

Operating System: Windows 10 or later

Administrative Privileges: Required for installation

Python Version: 3.11.6

Internet Connection: Required to download dependencies

Dependencies

The following software components are required:

Python 3.11.6 (with pip)

Privoxy (proxy configuration tool)

mitmproxy (to intercept network traffic)

SOCKS5 Proxy (user-provided credentials)

Installation Instructions

Step 1: Clone the Repository

Open Command Prompt and run:

 git clone https://github.com/Jasperdots/fb-mass-notifier.git
 cd fb-mass-notifier

Step 2: Run the Setup Script

The tool provides a setup.bat script to automate the installation.

Run setup.bat as Administrator:

Navigate to the extracted folder

Right-click setup.bat → Select Run as Administrator

This script will:

Install Python 3.11.6 (if not installed)

Install required Python packages

Download and install Privoxy

Set up mitmproxy

Configure firewall rules

Step 3: Configure the Proxy and Email Settings

The script will prompt for:

SOCKS5 Proxy IP, Port, Username, and Password

Email SMTP configuration (Sender, Password, Receiver, SMTP Server, Port)

These credentials are saved in a .env file for later use.

Running the Application

Step 1: Start the Proxy Services

After installation, start the services using:

 python main.py

Step 2: Monitor Logs

While running, the tool logs:

Privoxy instances

mitmproxy interceptions

Notification triggers

Stopping the Application

Press CTRL + C to stop the running proxies safely. The script will terminate all Privoxy and mitmproxy instances.

Troubleshooting

Common Issues & Fixes

Issue

Solution

Setup fails due to admin privileges

Run setup.bat as Administrator

config.ini error (MissingSectionHeaderError)

Ensure it is UTF-8 without BOM

mitmproxy not intercepting traffic

Ensure firewall rules allow it

No notifications received

Verify mitmproxy is running correctly

Uninstallation

To remove the tool, delete the installation directory and manually remove Privoxy if installed:

Remove-Item -Path "C:\Program Files (x86)\Privoxy" -Recurse -Force

Conclusion

FB Mass Notifier is a powerful tool for monitoring Facebook activity in real-time. By following this guide, you can successfully install, configure, and use the application efficiently.
