"""
Azure Communication Services - Python Sample Application
Demonstrates SMS, Email, and Chat capabilities

Prerequisites:
    pip install azure-communication-sms azure-communication-email azure-communication-chat azure-communication-identity azure-identity

Usage:
    # Set environment variables
    export ACS_CONNECTION_STRING="endpoint=https://your-acs.communication.azure.com/;accesskey=your-key"
    export ACS_ENDPOINT="https://your-acs.communication.azure.com"
    
    # Or use Key Vault reference
    export KEY_VAULT_URL="https://your-keyvault.vault.azure.net"
    
    # Run the sample
    python acs_sample.py
"""

import os
import asyncio
from datetime import datetime
from typing import Optional

# Azure Identity for Key Vault access
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

# Azure Communication Services SDKs
from azure.communication.sms import SmsClient
from azure.communication.email import EmailClient
from azure.communication.chat import ChatClient, CommunicationTokenCredential
from azure.communication.identity import CommunicationIdentityClient


class ACSConfiguration:
    """Configuration manager for Azure Communication Services."""
    
    def __init__(self):
        self.connection_string: Optional[str] = None
        self.endpoint: Optional[str] = None
        self._load_configuration()
    
    def _load_configuration(self):
        """Load configuration from environment variables or Key Vault."""
        # Try environment variables first
        self.connection_string = os.environ.get("ACS_CONNECTION_STRING")
        self.endpoint = os.environ.get("ACS_ENDPOINT")
        
        # If not found, try Key Vault
        if not self.connection_string:
            key_vault_url = os.environ.get("KEY_VAULT_URL")
            if key_vault_url:
                self._load_from_key_vault(key_vault_url)
    
    def _load_from_key_vault(self, key_vault_url: str):
        """Load secrets from Azure Key Vault using managed identity."""
        try:
            credential = DefaultAzureCredential()
            secret_client = SecretClient(vault_url=key_vault_url, credential=credential)
            
            self.connection_string = secret_client.get_secret("acs-connection-string").value
            self.endpoint = secret_client.get_secret("acs-endpoint").value
            
            print(f"✅ Configuration loaded from Key Vault: {key_vault_url}")
        except Exception as e:
            print(f"⚠️ Could not load from Key Vault: {e}")


# =============================================================================
# SMS Service
# =============================================================================

class SMSService:
    """
    Azure Communication Services SMS functionality.
    
    Supports:
    - Single recipient SMS
    - Bulk SMS (multiple recipients)
    - Delivery reports
    """
    
    def __init__(self, connection_string: str):
        self.client = SmsClient.from_connection_string(connection_string)
    
    def send_sms(
        self,
        from_number: str,
        to_number: str,
        message: str,
        enable_delivery_report: bool = True,
        tag: Optional[str] = None
    ) -> dict:
        """
        Send an SMS message to a single recipient.
        
        Args:
            from_number: ACS phone number (E.164 format, e.g., +14255550123)
            to_number: Recipient phone number (E.164 format)
            message: SMS message content
            enable_delivery_report: Enable delivery status notifications
            tag: Optional tag for tracking
        
        Returns:
            Response containing message ID and status
        """
        try:
            response = self.client.send(
                from_=from_number,
                to=to_number,
                message=message,
                enable_delivery_report=enable_delivery_report,
                tag=tag
            )
            
            return {
                "success": True,
                "message_id": response.message_id,
                "to": response.to,
                "http_status_code": response.http_status_code,
                "successful": response.successful
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }
    
    def send_bulk_sms(
        self,
        from_number: str,
        to_numbers: list[str],
        message: str,
        enable_delivery_report: bool = True
    ) -> list[dict]:
        """
        Send SMS to multiple recipients.
        
        Args:
            from_number: ACS phone number
            to_numbers: List of recipient phone numbers
            message: SMS message content
            enable_delivery_report: Enable delivery status notifications
        
        Returns:
            List of responses for each recipient
        """
        results = []
        for to_number in to_numbers:
            result = self.send_sms(from_number, to_number, message, enable_delivery_report)
            results.append(result)
        return results


# =============================================================================
# Email Service
# =============================================================================

class EmailService:
    """
    Azure Communication Services Email functionality.
    
    Supports:
    - Plain text emails
    - HTML emails
    - Multiple recipients (To, CC, BCC)
    - Attachments
    """
    
    def __init__(self, connection_string: str):
        self.client = EmailClient.from_connection_string(connection_string)
    
    def send_email(
        self,
        sender_address: str,
        recipient_address: str,
        subject: str,
        body: str,
        is_html: bool = False,
        cc: Optional[list[str]] = None,
        bcc: Optional[list[str]] = None,
        reply_to: Optional[str] = None
    ) -> dict:
        """
        Send an email message.
        
        Args:
            sender_address: Email sender (must be from verified domain)
            recipient_address: Primary recipient email
            subject: Email subject line
            body: Email body content
            is_html: Whether body is HTML formatted
            cc: CC recipients
            bcc: BCC recipients
            reply_to: Reply-to address
        
        Returns:
            Response containing message ID and status
        """
        try:
            # Build message content
            content = {}
            if is_html:
                content["html"] = body
            else:
                content["plainText"] = body
            
            # Build recipients
            recipients = {
                "to": [{"address": recipient_address}]
            }
            
            if cc:
                recipients["cc"] = [{"address": addr} for addr in cc]
            if bcc:
                recipients["bcc"] = [{"address": addr} for addr in bcc]
            
            # Build message
            message = {
                "senderAddress": sender_address,
                "recipients": recipients,
                "content": {
                    "subject": subject,
                    **content
                }
            }
            
            if reply_to:
                message["replyTo"] = [{"address": reply_to}]
            
            # Send email (this is a long-running operation)
            poller = self.client.begin_send(message)
            result = poller.result()
            
            return {
                "success": True,
                "message_id": result.id,
                "status": result.status
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }
    
    def send_html_email(
        self,
        sender_address: str,
        recipient_address: str,
        subject: str,
        html_body: str
    ) -> dict:
        """Send an HTML formatted email."""
        return self.send_email(
            sender_address=sender_address,
            recipient_address=recipient_address,
            subject=subject,
            body=html_body,
            is_html=True
        )


# =============================================================================
# Chat Service
# =============================================================================

class ChatService:
    """
    Azure Communication Services Chat functionality.
    
    Supports:
    - Creating chat threads
    - Sending messages
    - Adding/removing participants
    - Message history
    """
    
    def __init__(self, endpoint: str, connection_string: str):
        self.endpoint = endpoint
        self.identity_client = CommunicationIdentityClient.from_connection_string(connection_string)
        self.chat_client: Optional[ChatClient] = None
    
    def create_user_and_token(self) -> dict:
        """
        Create a new communication user and access token.
        
        Returns:
            User ID and access token for chat authentication
        """
        try:
            user, token_response = self.identity_client.create_user_and_token(scopes=["chat"])
            
            return {
                "success": True,
                "user_id": user.properties["id"],
                "token": token_response.token,
                "expires_on": token_response.expires_on.isoformat()
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }
    
    def initialize_chat_client(self, access_token: str):
        """Initialize the chat client with user credentials."""
        credential = CommunicationTokenCredential(access_token)
        self.chat_client = ChatClient(self.endpoint, credential)
    
    def create_chat_thread(self, topic: str, participant_ids: list[str]) -> dict:
        """
        Create a new chat thread.
        
        Args:
            topic: Chat thread topic/name
            participant_ids: List of user IDs to add to the thread
        
        Returns:
            Thread ID and details
        """
        if not self.chat_client:
            return {"success": False, "error": "Chat client not initialized"}
        
        try:
            from azure.communication.chat import ChatParticipant
            from azure.communication.identity import CommunicationUserIdentifier
            
            participants = [
                ChatParticipant(
                    identifier=CommunicationUserIdentifier(user_id),
                    display_name=f"User-{i+1}"
                )
                for i, user_id in enumerate(participant_ids)
            ]
            
            result = self.chat_client.create_chat_thread(topic=topic, thread_participants=participants)
            
            return {
                "success": True,
                "thread_id": result.chat_thread.id,
                "topic": result.chat_thread.topic,
                "created_on": result.chat_thread.created_on.isoformat()
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }
    
    def send_message(self, thread_id: str, content: str, sender_display_name: str = "User") -> dict:
        """
        Send a message to a chat thread.
        
        Args:
            thread_id: Target chat thread ID
            content: Message content
            sender_display_name: Display name for the sender
        
        Returns:
            Message ID and details
        """
        if not self.chat_client:
            return {"success": False, "error": "Chat client not initialized"}
        
        try:
            thread_client = self.chat_client.get_chat_thread_client(thread_id)
            
            result = thread_client.send_message(
                content=content,
                sender_display_name=sender_display_name,
                chat_message_type="text"
            )
            
            return {
                "success": True,
                "message_id": result.id,
                "sent_at": datetime.utcnow().isoformat()
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }
    
    def get_messages(self, thread_id: str, max_messages: int = 20) -> dict:
        """
        Retrieve messages from a chat thread.
        
        Args:
            thread_id: Target chat thread ID
            max_messages: Maximum number of messages to retrieve
        
        Returns:
            List of messages
        """
        if not self.chat_client:
            return {"success": False, "error": "Chat client not initialized"}
        
        try:
            thread_client = self.chat_client.get_chat_thread_client(thread_id)
            
            messages = []
            for message in thread_client.list_messages():
                if len(messages) >= max_messages:
                    break
                messages.append({
                    "id": message.id,
                    "type": message.type,
                    "content": message.content.message if message.content else None,
                    "sender_id": message.sender_communication_identifier.properties.get("id") if message.sender_communication_identifier else None,
                    "created_on": message.created_on.isoformat() if message.created_on else None
                })
            
            return {
                "success": True,
                "messages": messages,
                "count": len(messages)
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }


# =============================================================================
# Main Demo
# =============================================================================

def print_section(title: str):
    """Print a formatted section header."""
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}\n")


def main():
    """Main demonstration function."""
    print("""
    ╔═══════════════════════════════════════════════════════════╗
    ║   Azure Communication Services - Python Sample            ║
    ╚═══════════════════════════════════════════════════════════╝
    """)
    
    # Load configuration
    config = ACSConfiguration()
    
    if not config.connection_string:
        print("❌ Error: ACS_CONNECTION_STRING not configured")
        print("   Set the environment variable or KEY_VAULT_URL")
        return
    
    print(f"✅ Configuration loaded")
    print(f"   Endpoint: {config.endpoint or 'Using connection string'}")
    
    # ==========================================================================
    # SMS Demo
    # ==========================================================================
    print_section("SMS Service Demo")
    
    sms_service = SMSService(config.connection_string)
    
    # Note: You need to provision a phone number in Azure Portal first
    print("📱 SMS Service initialized")
    print("   To send SMS, you need:")
    print("   1. A provisioned phone number in ACS")
    print("   2. Valid recipient phone number")
    print()
    print("   Example usage:")
    print('   result = sms_service.send_sms(')
    print('       from_number="+14255550123",')
    print('       to_number="+14255550124",')
    print('       message="Hello from ACS!"')
    print('   )')
    
    # ==========================================================================
    # Email Demo
    # ==========================================================================
    print_section("Email Service Demo")
    
    email_service = EmailService(config.connection_string)
    
    print("📧 Email Service initialized")
    print("   To send email, you need:")
    print("   1. An Email Communication Service resource")
    print("   2. A verified domain (Azure-managed or custom)")
    print()
    print("   Example usage:")
    print('   result = email_service.send_email(')
    print('       sender_address="DoNotReply@your-domain.azurecomm.net",')
    print('       recipient_address="user@example.com",')
    print('       subject="Welcome!",')
    print('       body="Hello from Azure Communication Services!"')
    print('   )')
    
    # ==========================================================================
    # Chat Demo
    # ==========================================================================
    print_section("Chat Service Demo")
    
    if config.endpoint:
        chat_service = ChatService(config.endpoint, config.connection_string)
        
        print("💬 Chat Service initialized")
        print()
        
        # Create a user and get token
        print("Creating chat user...")
        user_result = chat_service.create_user_and_token()
        
        if user_result["success"]:
            print(f"   ✅ User created: {user_result['user_id'][:50]}...")
            print(f"   ✅ Token expires: {user_result['expires_on']}")
            
            # Initialize chat client with the token
            chat_service.initialize_chat_client(user_result["token"])
            print("   ✅ Chat client initialized")
        else:
            print(f"   ❌ Error: {user_result['error']}")
    else:
        print("⚠️ Chat Service requires ACS_ENDPOINT to be set")
    
    # ==========================================================================
    # Summary
    # ==========================================================================
    print_section("Summary")
    
    print("Available Services:")
    print("   ✅ SMS Service - Send text messages")
    print("   ✅ Email Service - Send transactional emails")
    print("   ✅ Chat Service - Real-time messaging")
    print()
    print("Next Steps:")
    print("   1. Provision phone numbers for SMS/Voice")
    print("   2. Link email domain to Communication Services")
    print("   3. Implement Event Grid webhooks for delivery reports")
    print("   4. Integrate with your application")
    print()
    print("Documentation: https://learn.microsoft.com/azure/communication-services/")


if __name__ == "__main__":
    main()
