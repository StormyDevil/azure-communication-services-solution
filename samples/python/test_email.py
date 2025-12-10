"""
Quick Email Test Script
Send a test email using the deployed Azure Communication Services
"""

import os
from azure.communication.email import EmailClient

# Configuration
connection_string = os.environ.get("ACS_CONNECTION_STRING")
sender_domain = "ded12d28-4098-4503-9e93-c1ef110d16f1.azurecomm.net"

def send_test_email(recipient_email: str):
    """Send a test email to verify the ACS Email service is working."""
    
    if not connection_string:
        print("❌ ACS_CONNECTION_STRING environment variable not set")
        return
    
    client = EmailClient.from_connection_string(connection_string)
    
    message = {
        "senderAddress": f"DoNotReply@{sender_domain}",
        "recipients": {
            "to": [{"address": recipient_email}]
        },
        "content": {
            "subject": "Azure Communication Services - Test Email",
            "plainText": "Hello!\n\nThis is a test email from Azure Communication Services.\n\nYour ACS deployment is working correctly!\n\nBest regards,\nACS Sample Application",
            "html": """
            <html>
                <body style="font-family: Arial, sans-serif; padding: 20px;">
                    <h1 style="color: #0078d4;">Azure Communication Services</h1>
                    <p>Hello!</p>
                    <p>This is a test email from <strong>Azure Communication Services</strong>.</p>
                    <p style="color: green;">✅ Your ACS deployment is working correctly!</p>
                    <hr>
                    <p style="color: gray; font-size: 12px;">
                        Sent from: ACS Sample Application<br>
                        Resource: acs-acssoln-dev-lvhkfz
                    </p>
                </body>
            </html>
            """
        }
    }
    
    print(f"📧 Sending test email to: {recipient_email}")
    print(f"   From: DoNotReply@{sender_domain}")
    
    try:
        poller = client.begin_send(message)
        result = poller.result()
        
        print(f"✅ Email sent successfully!")
        print(f"   Message ID: {result['id']}")
        print(f"   Status: {result['status']}")
        
    except Exception as e:
        print(f"❌ Failed to send email: {e}")


if __name__ == "__main__":
    import sys
    
    if len(sys.argv) < 2:
        print("Usage: python test_email.py <recipient_email>")
        print("Example: python test_email.py your.email@example.com")
        sys.exit(1)
    
    recipient = sys.argv[1]
    send_test_email(recipient)
