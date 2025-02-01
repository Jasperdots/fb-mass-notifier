import smtplib
import ssl
import logging
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

class OutlookMailer:    
    def __init__(self, sender_email, sender_password):
        self.SMTP_SERVER = "mail.bashirtopgshizznes.store"
        self.SMTP_PORT = 465
        self.sender_email = sender_email
        self.sender_password = sender_password

    def send_email(self, recipient_email, subject, html_content):
        try:
            msg = MIMEMultipart()
            msg["From"] = self.sender_email
            msg["To"] = recipient_email
            msg["Subject"] = subject
            msg.attach(MIMEText(html_content, "html"))

            context = ssl.create_default_context()
            server = smtplib.SMTP_SSL(self.SMTP_SERVER, self.SMTP_PORT, context=context) 
            server.set_debuglevel(1)
            server.login(self.sender_email, self.sender_password)

            server.sendmail(self.sender_email, recipient_email, msg.as_string())
            server.quit()

            logging.info(f"✅ Email sent successfully to {recipient_email}")
            print(f"✅ Email sent successfully to {recipient_email}")

        except Exception as e:
            logging.error(f"❌ Failed to send email: {e}")
            print(f"❌ Failed to send email: {e}")

def get_html_template(user_ID, message_content):
    """Generate an HTML email template with the given user_ID."""
    return f"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Outlook SMTP Email</title>
        <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">

        <style>
            body {{
                background-color: #121212; /* Dark background */
                color: #c0c0c0; /* Silver text */
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
                background: linear-gradient(135deg, #6a11cb, #2575fc); /* Blue-purple gradient */
                color: #c0c0c0; /* Silver text */
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

            .btn-custom {{
                background: linear-gradient(135deg, #6a11cb, #2575fc);
                border: none;
                color: white;
                padding: 10px 20px;
                border-radius: 5px;
                text-decoration: none;
                font-weight: bold;
            }}

            .btn-custom:hover {{
                background: linear-gradient(135deg, #5b0fb0, #1f5fc0);
                color: white;
            }}
        </style>
    </head>
    <body>

        <div class="container">
            <div class="header">📢 New Message </div>
            <div class="content">
                <h2>Notice</h2>
                <p>New message for account: <b>{user_ID}</b></p>
                <p><b>Let's get that cash! 🚀</b></p>
            </div>
            <div class="footer">This is an automated message. Please do not reply.</div>
            <div class="footer">2025 Copyright &#169;</div>
            <div class="footer"><p>Made by:</p> <a href="https://digimoula.com">Dots Digi</a></div>
        </div>

    </body>
    </html>
    """
