# Azure Communication Services Python Sample

## Prerequisites

```bash
pip install azure-communication-sms \
            azure-communication-email \
            azure-communication-chat \
            azure-communication-identity \
            azure-identity
```

## Configuration

### Option 1: Environment Variables

```bash
export ACS_CONNECTION_STRING="endpoint=https://your-acs.communication.azure.com/;accesskey=your-key"
export ACS_ENDPOINT="https://your-acs.communication.azure.com"
```

### Option 2: Key Vault (Recommended for Production)

```bash
export KEY_VAULT_URL="https://your-keyvault.vault.azure.net"
```

## Usage

```python
from acs_sample import SMSService, EmailService, ChatService, ACSConfiguration

# Load configuration
config = ACSConfiguration()

# SMS
sms = SMSService(config.connection_string)
sms.send_sms(
    from_number="+14255550123",
    to_number="+14255550124", 
    message="Hello from ACS!"
)

# Email
email = EmailService(config.connection_string)
email.send_email(
    sender_address="DoNotReply@your-domain.azurecomm.net",
    recipient_address="user@example.com",
    subject="Welcome!",
    body="Hello from Azure Communication Services!"
)

# Chat
chat = ChatService(config.endpoint, config.connection_string)
user = chat.create_user_and_token()
chat.initialize_chat_client(user["token"])
thread = chat.create_chat_thread("Support Chat", [user["user_id"]])
chat.send_message(thread["thread_id"], "Hello!", "Support Agent")
```

## Run Demo

```bash
python acs_sample.py
```
