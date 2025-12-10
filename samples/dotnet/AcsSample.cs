/*
 * Azure Communication Services - .NET Sample Application
 * Demonstrates SMS, Email, and Chat capabilities
 *
 * Prerequisites:
 *   dotnet add package Azure.Communication.Sms
 *   dotnet add package Azure.Communication.Email
 *   dotnet add package Azure.Communication.Chat
 *   dotnet add package Azure.Communication.Identity
 *   dotnet add package Azure.Identity
 *   dotnet add package Azure.Security.KeyVault.Secrets
 *
 * Configuration:
 *   Set environment variables:
 *   - ACS_CONNECTION_STRING: Your ACS connection string
 *   - ACS_ENDPOINT: Your ACS endpoint URL
 *   - KEY_VAULT_URL: (Optional) Key Vault URL for secrets
 */

using Azure;
using Azure.Communication;
using Azure.Communication.Chat;
using Azure.Communication.Email;
using Azure.Communication.Identity;
using Azure.Communication.Sms;
using Azure.Identity;
using Azure.Security.KeyVault.Secrets;

namespace AcsSample;

/// <summary>
/// Configuration manager for Azure Communication Services.
/// </summary>
public class AcsConfiguration
{
    public string? ConnectionString { get; private set; }
    public string? Endpoint { get; private set; }

    public AcsConfiguration()
    {
        LoadConfiguration();
    }

    private void LoadConfiguration()
    {
        // Try environment variables first
        ConnectionString = Environment.GetEnvironmentVariable("ACS_CONNECTION_STRING");
        Endpoint = Environment.GetEnvironmentVariable("ACS_ENDPOINT");

        // If not found, try Key Vault
        if (string.IsNullOrEmpty(ConnectionString))
        {
            var keyVaultUrl = Environment.GetEnvironmentVariable("KEY_VAULT_URL");
            if (!string.IsNullOrEmpty(keyVaultUrl))
            {
                LoadFromKeyVault(keyVaultUrl);
            }
        }
    }

    private void LoadFromKeyVault(string keyVaultUrl)
    {
        try
        {
            var credential = new DefaultAzureCredential();
            var secretClient = new SecretClient(new Uri(keyVaultUrl), credential);

            ConnectionString = secretClient.GetSecret("acs-connection-string").Value.Value;
            Endpoint = secretClient.GetSecret("acs-endpoint").Value.Value;

            Console.WriteLine($"✅ Configuration loaded from Key Vault: {keyVaultUrl}");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"⚠️ Could not load from Key Vault: {ex.Message}");
        }
    }
}

// =============================================================================
// SMS Service
// =============================================================================

/// <summary>
/// Azure Communication Services SMS functionality.
/// </summary>
public class SmsService
{
    private readonly SmsClient _client;

    public SmsService(string connectionString)
    {
        _client = new SmsClient(connectionString);
    }

    /// <summary>
    /// Send an SMS message to a single recipient.
    /// </summary>
    /// <param name="fromNumber">ACS phone number (E.164 format)</param>
    /// <param name="toNumber">Recipient phone number (E.164 format)</param>
    /// <param name="message">SMS message content</param>
    /// <param name="enableDeliveryReport">Enable delivery status notifications</param>
    /// <returns>SMS send result</returns>
    public async Task<SmsSendResult> SendSmsAsync(
        string fromNumber,
        string toNumber,
        string message,
        bool enableDeliveryReport = true)
    {
        var options = new SmsSendOptions(enableDeliveryReport);
        
        var response = await _client.SendAsync(
            from: fromNumber,
            to: toNumber,
            message: message,
            options: options);

        return response.Value;
    }

    /// <summary>
    /// Send SMS to multiple recipients.
    /// </summary>
    public async Task<IEnumerable<SmsSendResult>> SendBulkSmsAsync(
        string fromNumber,
        IEnumerable<string> toNumbers,
        string message,
        bool enableDeliveryReport = true)
    {
        var options = new SmsSendOptions(enableDeliveryReport);

        var response = await _client.SendAsync(
            from: fromNumber,
            to: toNumbers,
            message: message,
            options: options);

        return response.Value;
    }
}

// =============================================================================
// Email Service
// =============================================================================

/// <summary>
/// Azure Communication Services Email functionality.
/// </summary>
public class EmailService
{
    private readonly EmailClient _client;

    public EmailService(string connectionString)
    {
        _client = new EmailClient(connectionString);
    }

    /// <summary>
    /// Send an email message.
    /// </summary>
    /// <param name="senderAddress">Email sender (must be from verified domain)</param>
    /// <param name="recipientAddress">Primary recipient email</param>
    /// <param name="subject">Email subject line</param>
    /// <param name="body">Email body content</param>
    /// <param name="isHtml">Whether body is HTML formatted</param>
    /// <returns>Email send operation result</returns>
    public async Task<EmailSendResult> SendEmailAsync(
        string senderAddress,
        string recipientAddress,
        string subject,
        string body,
        bool isHtml = false)
    {
        var emailContent = new EmailContent(subject);
        if (isHtml)
        {
            emailContent.Html = body;
        }
        else
        {
            emailContent.PlainText = body;
        }

        var emailMessage = new EmailMessage(
            senderAddress: senderAddress,
            content: emailContent,
            recipients: new EmailRecipients(
                new List<EmailAddress> { new EmailAddress(recipientAddress) }
            )
        );

        // Send email (long-running operation)
        var operation = await _client.SendAsync(
            WaitUntil.Completed,
            emailMessage);

        return operation.Value;
    }

    /// <summary>
    /// Send an HTML formatted email.
    /// </summary>
    public async Task<EmailSendResult> SendHtmlEmailAsync(
        string senderAddress,
        string recipientAddress,
        string subject,
        string htmlBody)
    {
        return await SendEmailAsync(senderAddress, recipientAddress, subject, htmlBody, isHtml: true);
    }
}

// =============================================================================
// Chat Service
// =============================================================================

/// <summary>
/// Azure Communication Services Chat functionality.
/// </summary>
public class ChatService
{
    private readonly string _endpoint;
    private readonly CommunicationIdentityClient _identityClient;
    private ChatClient? _chatClient;

    public ChatService(string endpoint, string connectionString)
    {
        _endpoint = endpoint;
        _identityClient = new CommunicationIdentityClient(connectionString);
    }

    /// <summary>
    /// Create a new communication user and access token.
    /// </summary>
    /// <returns>User information with access token</returns>
    public async Task<(CommunicationUserIdentifier User, AccessToken Token)> CreateUserAndTokenAsync()
    {
        var response = await _identityClient.CreateUserAndTokenAsync(
            scopes: new[] { CommunicationTokenScope.Chat });

        return (response.Value.User, response.Value.AccessToken);
    }

    /// <summary>
    /// Initialize the chat client with user credentials.
    /// </summary>
    public void InitializeChatClient(string accessToken)
    {
        var tokenCredential = new CommunicationTokenCredential(accessToken);
        _chatClient = new ChatClient(new Uri(_endpoint), tokenCredential);
    }

    /// <summary>
    /// Create a new chat thread.
    /// </summary>
    /// <param name="topic">Chat thread topic/name</param>
    /// <param name="participants">List of participant identifiers</param>
    /// <returns>Created chat thread information</returns>
    public async Task<CreateChatThreadResult> CreateChatThreadAsync(
        string topic,
        IEnumerable<CommunicationUserIdentifier> participants)
    {
        if (_chatClient == null)
            throw new InvalidOperationException("Chat client not initialized");

        var chatParticipants = participants.Select((p, i) => new ChatParticipant(p)
        {
            DisplayName = $"User-{i + 1}"
        });

        var result = await _chatClient.CreateChatThreadAsync(
            topic: topic,
            participants: chatParticipants);

        return result.Value;
    }

    /// <summary>
    /// Send a message to a chat thread.
    /// </summary>
    public async Task<SendChatMessageResult> SendMessageAsync(
        string threadId,
        string content,
        string senderDisplayName = "User")
    {
        if (_chatClient == null)
            throw new InvalidOperationException("Chat client not initialized");

        var threadClient = _chatClient.GetChatThreadClient(threadId);

        var result = await threadClient.SendMessageAsync(
            content: content,
            senderDisplayName: senderDisplayName);

        return result.Value;
    }

    /// <summary>
    /// Retrieve messages from a chat thread.
    /// </summary>
    public async Task<List<ChatMessage>> GetMessagesAsync(string threadId, int maxMessages = 20)
    {
        if (_chatClient == null)
            throw new InvalidOperationException("Chat client not initialized");

        var threadClient = _chatClient.GetChatThreadClient(threadId);

        var messages = new List<ChatMessage>();
        await foreach (var message in threadClient.GetMessagesAsync())
        {
            if (messages.Count >= maxMessages) break;
            messages.Add(message);
        }

        return messages;
    }
}

// =============================================================================
// Main Program
// =============================================================================

public class Program
{
    public static async Task Main(string[] args)
    {
        Console.WriteLine(@"
    ╔═══════════════════════════════════════════════════════════╗
    ║   Azure Communication Services - .NET Sample              ║
    ╚═══════════════════════════════════════════════════════════╝
        ");

        // Load configuration
        var config = new AcsConfiguration();

        if (string.IsNullOrEmpty(config.ConnectionString))
        {
            Console.WriteLine("❌ Error: ACS_CONNECTION_STRING not configured");
            Console.WriteLine("   Set the environment variable or KEY_VAULT_URL");
            return;
        }

        Console.WriteLine($"✅ Configuration loaded");
        Console.WriteLine($"   Endpoint: {config.Endpoint ?? "Using connection string"}");

        // ==========================================================================
        // SMS Demo
        // ==========================================================================
        PrintSection("SMS Service Demo");

        var smsService = new SmsService(config.ConnectionString);

        Console.WriteLine("📱 SMS Service initialized");
        Console.WriteLine("   To send SMS, you need:");
        Console.WriteLine("   1. A provisioned phone number in ACS");
        Console.WriteLine("   2. Valid recipient phone number");
        Console.WriteLine();
        Console.WriteLine("   Example usage:");
        Console.WriteLine("   var result = await smsService.SendSmsAsync(");
        Console.WriteLine("       fromNumber: \"+14255550123\",");
        Console.WriteLine("       toNumber: \"+14255550124\",");
        Console.WriteLine("       message: \"Hello from ACS!\");");

        // ==========================================================================
        // Email Demo
        // ==========================================================================
        PrintSection("Email Service Demo");

        var emailService = new EmailService(config.ConnectionString);

        Console.WriteLine("📧 Email Service initialized");
        Console.WriteLine("   To send email, you need:");
        Console.WriteLine("   1. An Email Communication Service resource");
        Console.WriteLine("   2. A verified domain (Azure-managed or custom)");
        Console.WriteLine();
        Console.WriteLine("   Example usage:");
        Console.WriteLine("   var result = await emailService.SendEmailAsync(");
        Console.WriteLine("       senderAddress: \"DoNotReply@your-domain.azurecomm.net\",");
        Console.WriteLine("       recipientAddress: \"user@example.com\",");
        Console.WriteLine("       subject: \"Welcome!\",");
        Console.WriteLine("       body: \"Hello from Azure Communication Services!\");");

        // ==========================================================================
        // Chat Demo
        // ==========================================================================
        PrintSection("Chat Service Demo");

        if (!string.IsNullOrEmpty(config.Endpoint))
        {
            var chatService = new ChatService(config.Endpoint, config.ConnectionString);

            Console.WriteLine("💬 Chat Service initialized");
            Console.WriteLine();

            // Create a user and get token
            Console.WriteLine("Creating chat user...");
            try
            {
                var (user, token) = await chatService.CreateUserAndTokenAsync();
                Console.WriteLine($"   ✅ User created: {user.Id[..Math.Min(50, user.Id.Length)]}...");
                Console.WriteLine($"   ✅ Token expires: {token.ExpiresOn}");

                // Initialize chat client with the token
                chatService.InitializeChatClient(token.Token);
                Console.WriteLine("   ✅ Chat client initialized");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"   ❌ Error: {ex.Message}");
            }
        }
        else
        {
            Console.WriteLine("⚠️ Chat Service requires ACS_ENDPOINT to be set");
        }

        // ==========================================================================
        // Summary
        // ==========================================================================
        PrintSection("Summary");

        Console.WriteLine("Available Services:");
        Console.WriteLine("   ✅ SMS Service - Send text messages");
        Console.WriteLine("   ✅ Email Service - Send transactional emails");
        Console.WriteLine("   ✅ Chat Service - Real-time messaging");
        Console.WriteLine();
        Console.WriteLine("Next Steps:");
        Console.WriteLine("   1. Provision phone numbers for SMS/Voice");
        Console.WriteLine("   2. Link email domain to Communication Services");
        Console.WriteLine("   3. Implement Event Grid webhooks for delivery reports");
        Console.WriteLine("   4. Integrate with your application");
        Console.WriteLine();
        Console.WriteLine("Documentation: https://learn.microsoft.com/azure/communication-services/");
    }

    private static void PrintSection(string title)
    {
        Console.WriteLine($"\n{"".PadLeft(60, '=')}");
        Console.WriteLine($"  {title}");
        Console.WriteLine($"{"".PadLeft(60, '=')}\n");
    }
}
