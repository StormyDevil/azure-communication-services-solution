# Azure Communication Services SDK Samples

This directory contains sample applications demonstrating how to use Azure Communication Services (ACS) with different SDKs.

## Prerequisites

- An Azure subscription
- Azure Communication Services resource deployed (use the Bicep templates in the parent directory)
- The ACS connection string (stored in Key Vault after deployment)

## Sample Applications

### Python Sample (`python/`)

**Features Demonstrated:**
- SMS sending and delivery tracking
- Email sending with attachments
- Chat thread creation and messaging
- Event Grid webhook handling

**Setup:**
```bash
cd python

# Create virtual environment
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate

# Install dependencies
pip install azure-communication-sms azure-communication-email azure-communication-chat \
    azure-communication-identity azure-identity azure-keyvault-secrets

# Set environment variables
export AZURE_KEY_VAULT_URL="https://your-keyvault.vault.azure.net/"
export ACS_RESOURCE_NAME="your-acs-resource"

# Run the sample
python acs_sample.py
```

---

### .NET Sample (`dotnet/`)

**Features Demonstrated:**
- SMS client with async patterns
- Email sending with HTML content
- Chat client management
- Event Grid event processing

**Setup:**
```bash
cd dotnet

# Restore packages
dotnet restore

# Set environment variables
export AZURE_KEY_VAULT_URL="https://your-keyvault.vault.azure.net/"
export ACS_RESOURCE_NAME="your-acs-resource"

# Build and run
dotnet build
dotnet run
```

**Required .NET Version:** .NET 8.0 or later

---

### TypeScript Sample (`typescript/`)

**Features Demonstrated:**
- SMS sending with delivery reports
- Email with multiple recipients
- Chat thread management
- Identity token generation

**Setup:**
```bash
cd typescript

# Install dependencies
npm install

# Set environment variables
export AZURE_KEY_VAULT_URL="https://your-keyvault.vault.azure.net/"
export ACS_RESOURCE_NAME="your-acs-resource"

# Build and run
npm run build
npm start

# Or run in development mode
npm run dev
```

---

## Authentication

All samples use Azure Identity (DefaultAzureCredential) for authentication. This supports:

1. **Local Development:**
   - Azure CLI (`az login`)
   - Visual Studio Code Azure extension
   - Environment variables (AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_CLIENT_SECRET)

2. **Production:**
   - Managed Identity (System or User-assigned)
   - Workload Identity (AKS)

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `AZURE_KEY_VAULT_URL` | Key Vault URL containing ACS secrets | Yes |
| `ACS_RESOURCE_NAME` | Name of your ACS resource | Yes |
| `ACS_CONNECTION_STRING` | Direct connection string (alternative to Key Vault) | No |

## Retrieving the Connection String

After deploying the infrastructure, the connection string is stored in Key Vault:

```bash
# Get the connection string from Key Vault
az keyvault secret show \
    --vault-name "your-keyvault-name" \
    --name "acs-connection-string" \
    --query "value" -o tsv
```

## Event Grid Integration

For receiving delivery reports and events:

1. **Webhook Endpoint:** Deploy a publicly accessible endpoint
2. **Event Subscription:** Created automatically by the Bicep templates
3. **Event Types:**
   - `Microsoft.Communication.SMSDeliveryReportReceived`
   - `Microsoft.Communication.ChatMessageReceived`
   - `Microsoft.Communication.RecordingFileStatusUpdated`

Example Flask webhook handler (Python):

```python
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/events', methods=['POST'])
def handle_events():
    events = request.json
    for event in events:
        event_type = event.get('eventType')
        data = event.get('data')
        
        if event_type == 'Microsoft.Communication.SMSDeliveryReportReceived':
            print(f"SMS to {data['to']} - Status: {data['deliveryStatus']}")
        elif event_type == 'Microsoft.Communication.ChatMessageReceived':
            print(f"Chat message: {data['messageBody']}")
    
    return jsonify({'status': 'ok'}), 200

if __name__ == '__main__':
    app.run(port=5000)
```

## Troubleshooting

### Common Issues

1. **Authentication Errors:**
   - Ensure you're logged in with `az login`
   - Verify Key Vault access policies include your identity

2. **SMS Not Sending:**
   - Check that SMS capability is enabled on your ACS resource
   - Verify phone number format (E.164: +1XXXXXXXXXX)

3. **Email Not Sending:**
   - Confirm email domain is verified
   - Check sender username exists (DoNotReply, Notifications)

4. **Chat Errors:**
   - User access tokens expire after 24 hours by default
   - Ensure chat participants have valid identity tokens

## Additional Resources

- [ACS Documentation](https://learn.microsoft.com/azure/communication-services/)
- [ACS SDKs](https://learn.microsoft.com/azure/communication-services/concepts/sdk-options)
- [Event Grid Integration](https://learn.microsoft.com/azure/communication-services/concepts/event-handling)
- [Best Practices](https://learn.microsoft.com/azure/communication-services/concepts/best-practices)
