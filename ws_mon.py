import smtplib
import ssl
import logging
import json
import re
import socks
import socket
import os
from dotenv import load_dotenv
from urllib.parse import urlparse, parse_qs
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from mitmproxy import http
from logging.handlers import RotatingFileHandler

load_dotenv()

# SOCKS5 Proxy Credentials from .env
SOCKS5_PROXY = os.getenv("SOCKS5_PROXY")
SOCKS5_PORT = int(os.getenv("SOCKS5_PORT", 1080))  # Default to 1080 if not specified
SOCKS5_USER = os.getenv("SOCKS5_USER")
SOCKS5_PASS = os.getenv("SOCKS5_PASS")

# Email Configuration
EMAIL_SENDER = os.getenv("EMAIL_SENDER")
EMAIL_PASSWORD = os.getenv("EMAIL_PASSWORD")
EMAIL_RECEIVER = os.getenv("EMAIL_RECEIVER")
SMTP_SERVER = os.getenv("SMTP_SERVER")
SMTP_PORT = int(os.getenv("SMTP_PORT", 587))

logging.basicConfig(encoding="utf-8", level=logging.DEBUG)

# ========================== NETWORK REQUEST LOGGING ========================== #
network_log_handler = RotatingFileHandler("network_requests.log", maxBytes=10*1024*1024, backupCount=5)
network_logger = logging.getLogger("network_logger")
network_logger.setLevel(logging.INFO)
network_logger.addHandler(network_log_handler)

# ========================== EMAIL LOGGING CONFIGURATION ========================== #
email_log_handler = RotatingFileHandler("email_log.log", maxBytes=5*1024*1024, backupCount=3, encoding="utf-8")
email_logger = logging.getLogger("email_logger")
email_logger.setLevel(logging.DEBUG)
email_logger.addHandler(email_log_handler)

# ========================== FACEBOOK LOGGING CONFIGURATION ========================== #
fb_log_handler = RotatingFileHandler("facebook_messages.log", maxBytes=5*1024*1024, backupCount=3)
fb_logger = logging.getLogger("fb_logger")
fb_logger.setLevel(logging.INFO)
fb_logger.addHandler(fb_log_handler)



# Set up SOCKS5 proxy with DNS resolution enabled
socks.set_default_proxy(
    socks.SOCKS5, SOCKS5_PROXY, SOCKS5_PORT, username=SOCKS5_USER, password=SOCKS5_PASS, rdns=True
)
socks.wrapmodule(socket)  # Ensure mitmproxy does not break

# ========================== EMAIL CONFIGURATION ========================== #
class OutlookMailer:
    def __init__(self, sender_email, sender_password):
        self.SMTP_SERVER = SMTP_SERVER
        self.SMTP_PORT = SMTP_PORT
        self.sender_email = EMAIL_SENDER
        self.sender_password = EMAIL_PASSWORD

    def send_email(self, recipient_email, subject, html_content):
        """Send an HTML email using SMTP."""
        try:
            msg = MIMEMultipart()
            msg["From"] = f"Facebook Monitor <{self.sender_email}>"
            msg["To"] = recipient_email
            msg["Subject"] = subject
            msg.attach(MIMEText(html_content, "html"))

            # Connect using STARTTLS
            print("Connecting to SMTP server...")
            context = ssl.create_default_context()
            server = smtplib.SMTP(self.SMTP_SERVER, self.SMTP_PORT)
            server.set_debuglevel(2)
            server.starttls(context=context)
            
            print("Logging in to SMTP server...")
            server.login(self.sender_email, self.sender_password)

            # Send Email
            server.sendmail(self.sender_email, recipient_email, msg.as_string())
            server.quit()

            email_logger.info(f"Email sent successfully to {recipient_email}")
            print(f"Email sent successfully to {recipient_email}")

        except smtplib.SMTPAuthenticationError as e:
            email_logger.error(f"SMTP Authentication failed: {str(e)}")
            print(f"SMTP Authentication failed: {str(e)}")
        except smtplib.SMTPException as e:
            email_logger.error(f"SMTP Error: {str(e)}")
            print(f"SMTP Error: {str(e)}")
        except Exception as e:
            email_logger.error(f" Critical error sending email: {str(e)}", exc_info=True)
            print(f"Critical error sending email: {str(e)}")
            raise

def get_html_template(actor_id, recipient_id):
    """Generate an HTML email template with the given sender and receiver IDs."""
    return f"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>New Facebook Message</title>
        <style>
            body {{
                background-color: #121212;
                color: #c0c0c0;
                font-family: Arial, sans-serif;
                padding: 20px;
            }}
            .container {{
                max-width: 600px;
                background: #1e1e1e;
                padding: 20px;
                border-radius: 10px;
                box-shadow: 0px 4px 12px rgba(0, 0, 0, 0.3);
            }}
            .header {{
                background: linear-gradient(135deg, #6a11cb, #2575fc);
                color: #c0c0c0;
                text-align: center;
                padding: 15px;
                font-size: 22px;
                font-weight: bold;
                border-radius: 10px 10px 0 0;
            }}
            .content {{
                padding: 20px;
                text-align: center;
            }}
            .footer {{
                margin-top: 20px;
                font-size: 12px;
                color: #a0a0a0;
                text-align: center;
            }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="text-white header">📢 New Facebook Message Notification</div>
            <div class="text-white content">
                <h2>New Message Alert</h2>
                <p><b>Sender (actor_id):</b> {actor_id}</p>
                <p><b>Receiver (recipient_id):</b> {recipient_id}</p>
            </div>
            <div class="footer">This is an automated notification. Please do not reply.</div>
        </div>
    </body>
    </html>
    """



# Initialize the mailer
mailer = OutlookMailer(EMAIL_SENDER, EMAIL_PASSWORD)
EXTRACTED_MESSAGES = set()

# ========================== MITM REQUEST INTERCEPTION ========================== #
def extract_query_params(url):
    """Extract query parameters from a given URL."""
    parsed_url = urlparse(url)
    return parse_qs(parsed_url.query)

def request(flow: http.HTTPFlow) -> None:
    """Intercept all network requests and log them."""
    network_logger.info(f"REQUEST: {flow.request.method} {flow.request.url}")
    
    if "facebook.com/notifications/client/push/delivered" in flow.request.url:
        query_params = extract_query_params(flow.request.url)
        notif_type = query_params.get("notif_type", [""])[0]
        actor_id = query_params.get("actor_id", ["Unknown"])[0]
        recipient_id = query_params.get("recipient_id", ["Unknown"])[0]

        if notif_type == "msg":
            message_key = f"{actor_id}->{recipient_id}"
            if message_key not in EXTRACTED_MESSAGES:
                fb_logger.info(f"New Message Notification - Actor: {actor_id}, Recipient: {recipient_id}")
                html_email = get_html_template(actor_id, recipient_id)
                mailer.send_email(EMAIL_RECEIVER, "🚀 New Facebook Message Alert", html_email)
                EXTRACTED_MESSAGES.add(message_key)

def response(flow: http.HTTPFlow) -> None:
    """Intercept all network responses and log them."""
    network_logger.info(f"RESPONSE: {flow.request.url} - {flow.response.status_code}")
