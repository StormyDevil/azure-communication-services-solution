/**
 * Azure Communication Services - TypeScript Sample Application
 * Demonstrates SMS, Email, and Chat capabilities
 *
 * Prerequisites:
 *   npm install @azure/communication-sms @azure/communication-email
 *   npm install @azure/communication-chat @azure/communication-identity
 *   npm install @azure/identity @azure/keyvault-secrets
 *
 * Configuration:
 *   Set environment variables:
 *   - ACS_CONNECTION_STRING: Your ACS connection string
 *   - ACS_ENDPOINT: Your ACS endpoint URL
 *   - KEY_VAULT_URL: (Optional) Key Vault URL for secrets
 */

import { SmsClient, SmsSendRequest } from "@azure/communication-sms";
import { EmailClient, EmailMessage } from "@azure/communication-email";
import { ChatClient, ChatParticipant } from "@azure/communication-chat";
import {
  CommunicationIdentityClient,
  CommunicationUserToken,
} from "@azure/communication-identity";
import { AzureCommunicationTokenCredential } from "@azure/communication-common";
import { DefaultAzureCredential } from "@azure/identity";
import { SecretClient } from "@azure/keyvault-secrets";

// =============================================================================
// Configuration
// =============================================================================

interface AcsConfig {
  connectionString: string | undefined;
  endpoint: string | undefined;
}

async function loadConfiguration(): Promise<AcsConfig> {
  let connectionString = process.env.ACS_CONNECTION_STRING;
  let endpoint = process.env.ACS_ENDPOINT;

  // If not found, try Key Vault
  if (!connectionString) {
    const keyVaultUrl = process.env.KEY_VAULT_URL;
    if (keyVaultUrl) {
      try {
        const credential = new DefaultAzureCredential();
        const secretClient = new SecretClient(keyVaultUrl, credential);

        const connStringSecret = await secretClient.getSecret(
          "acs-connection-string"
        );
        const endpointSecret = await secretClient.getSecret("acs-endpoint");

        connectionString = connStringSecret.value;
        endpoint = endpointSecret.value;

        console.log(`✅ Configuration loaded from Key Vault: ${keyVaultUrl}`);
      } catch (error) {
        console.log(`⚠️ Could not load from Key Vault: ${error}`);
      }
    }
  }

  return { connectionString, endpoint };
}

// =============================================================================
// SMS Service
// =============================================================================

interface SmsSendResult {
  success: boolean;
  messageId?: string;
  to?: string;
  httpStatusCode?: number;
  error?: string;
}

class SmsService {
  private client: SmsClient;

  constructor(connectionString: string) {
    this.client = new SmsClient(connectionString);
  }

  /**
   * Send an SMS message to a single recipient.
   */
  async sendSms(
    fromNumber: string,
    toNumber: string,
    message: string,
    enableDeliveryReport: boolean = true,
    tag?: string
  ): Promise<SmsSendResult> {
    try {
      const sendResults = await this.client.send({
        from: fromNumber,
        to: [toNumber],
        message: message,
      }, {
        enableDeliveryReport: enableDeliveryReport,
        tag: tag,
      });

      const result = sendResults[0];
      return {
        success: result.successful,
        messageId: result.messageId,
        to: result.to,
        httpStatusCode: result.httpStatusCode,
      };
    } catch (error) {
      return {
        success: false,
        error: String(error),
      };
    }
  }

  /**
   * Send SMS to multiple recipients.
   */
  async sendBulkSms(
    fromNumber: string,
    toNumbers: string[],
    message: string,
    enableDeliveryReport: boolean = true
  ): Promise<SmsSendResult[]> {
    try {
      const sendResults = await this.client.send({
        from: fromNumber,
        to: toNumbers,
        message: message,
      }, {
        enableDeliveryReport: enableDeliveryReport,
      });

      return sendResults.map((result) => ({
        success: result.successful,
        messageId: result.messageId,
        to: result.to,
        httpStatusCode: result.httpStatusCode,
      }));
    } catch (error) {
      return toNumbers.map(() => ({
        success: false,
        error: String(error),
      }));
    }
  }
}

// =============================================================================
// Email Service
// =============================================================================

interface EmailSendResult {
  success: boolean;
  messageId?: string;
  status?: string;
  error?: string;
}

class EmailService {
  private client: EmailClient;

  constructor(connectionString: string) {
    this.client = new EmailClient(connectionString);
  }

  /**
   * Send an email message.
   */
  async sendEmail(
    senderAddress: string,
    recipientAddress: string,
    subject: string,
    body: string,
    isHtml: boolean = false
  ): Promise<EmailSendResult> {
    try {
      const emailMessage: EmailMessage = {
        senderAddress: senderAddress,
        content: {
          subject: subject,
          ...(isHtml ? { html: body } : { plainText: body }),
        },
        recipients: {
          to: [{ address: recipientAddress }],
        },
      };

      // Send email (long-running operation)
      const poller = await this.client.beginSend(emailMessage);
      const result = await poller.pollUntilDone();

      return {
        success: true,
        messageId: result.id,
        status: result.status,
      };
    } catch (error) {
      return {
        success: false,
        error: String(error),
      };
    }
  }

  /**
   * Send an HTML formatted email.
   */
  async sendHtmlEmail(
    senderAddress: string,
    recipientAddress: string,
    subject: string,
    htmlBody: string
  ): Promise<EmailSendResult> {
    return this.sendEmail(senderAddress, recipientAddress, subject, htmlBody, true);
  }
}

// =============================================================================
// Chat Service
// =============================================================================

interface UserTokenResult {
  success: boolean;
  userId?: string;
  token?: string;
  expiresOn?: Date;
  error?: string;
}

interface ChatThreadResult {
  success: boolean;
  threadId?: string;
  topic?: string;
  error?: string;
}

interface ChatMessageResult {
  success: boolean;
  messageId?: string;
  error?: string;
}

class ChatService {
  private endpoint: string;
  private identityClient: CommunicationIdentityClient;
  private chatClient?: ChatClient;

  constructor(endpoint: string, connectionString: string) {
    this.endpoint = endpoint;
    this.identityClient = new CommunicationIdentityClient(connectionString);
  }

  /**
   * Create a new communication user and access token.
   */
  async createUserAndToken(): Promise<UserTokenResult> {
    try {
      const result = await this.identityClient.createUserAndToken(["chat"]);

      return {
        success: true,
        userId: result.user.communicationUserId,
        token: result.token,
        expiresOn: result.expiresOn,
      };
    } catch (error) {
      return {
        success: false,
        error: String(error),
      };
    }
  }

  /**
   * Initialize the chat client with user credentials.
   */
  initializeChatClient(accessToken: string): void {
    const tokenCredential = new AzureCommunicationTokenCredential(accessToken);
    this.chatClient = new ChatClient(this.endpoint, tokenCredential);
  }

  /**
   * Create a new chat thread.
   */
  async createChatThread(
    topic: string,
    participantIds: string[]
  ): Promise<ChatThreadResult> {
    if (!this.chatClient) {
      return { success: false, error: "Chat client not initialized" };
    }

    try {
      const participants: ChatParticipant[] = participantIds.map((id, index) => ({
        id: { communicationUserId: id },
        displayName: `User-${index + 1}`,
      }));

      const result = await this.chatClient.createChatThread(
        { topic },
        { participants }
      );

      return {
        success: true,
        threadId: result.chatThread?.id,
        topic: result.chatThread?.topic,
      };
    } catch (error) {
      return {
        success: false,
        error: String(error),
      };
    }
  }

  /**
   * Send a message to a chat thread.
   */
  async sendMessage(
    threadId: string,
    content: string,
    senderDisplayName: string = "User"
  ): Promise<ChatMessageResult> {
    if (!this.chatClient) {
      return { success: false, error: "Chat client not initialized" };
    }

    try {
      const threadClient = this.chatClient.getChatThreadClient(threadId);

      const result = await threadClient.sendMessage(
        { content },
        { senderDisplayName }
      );

      return {
        success: true,
        messageId: result.id,
      };
    } catch (error) {
      return {
        success: false,
        error: String(error),
      };
    }
  }

  /**
   * Retrieve messages from a chat thread.
   */
  async getMessages(threadId: string, maxMessages: number = 20): Promise<any[]> {
    if (!this.chatClient) {
      throw new Error("Chat client not initialized");
    }

    const threadClient = this.chatClient.getChatThreadClient(threadId);
    const messages: any[] = [];

    for await (const message of threadClient.listMessages()) {
      if (messages.length >= maxMessages) break;
      messages.push({
        id: message.id,
        type: message.type,
        content: message.content?.message,
        senderId: message.sender
          ? (message.sender as any).communicationUserId
          : null,
        createdOn: message.createdOn,
      });
    }

    return messages;
  }
}

// =============================================================================
// Main Demo
// =============================================================================

function printSection(title: string): void {
  console.log(`\n${"=".repeat(60)}`);
  console.log(`  ${title}`);
  console.log(`${"=".repeat(60)}\n`);
}

async function main(): Promise<void> {
  console.log(`
    ╔═══════════════════════════════════════════════════════════╗
    ║   Azure Communication Services - TypeScript Sample        ║
    ╚═══════════════════════════════════════════════════════════╝
  `);

  // Load configuration
  const config = await loadConfiguration();

  if (!config.connectionString) {
    console.log("❌ Error: ACS_CONNECTION_STRING not configured");
    console.log("   Set the environment variable or KEY_VAULT_URL");
    return;
  }

  console.log("✅ Configuration loaded");
  console.log(`   Endpoint: ${config.endpoint || "Using connection string"}`);

  // ==========================================================================
  // SMS Demo
  // ==========================================================================
  printSection("SMS Service Demo");

  const smsService = new SmsService(config.connectionString);

  console.log("📱 SMS Service initialized");
  console.log("   To send SMS, you need:");
  console.log("   1. A provisioned phone number in ACS");
  console.log("   2. Valid recipient phone number");
  console.log();
  console.log("   Example usage:");
  console.log("   const result = await smsService.sendSms(");
  console.log('       "+14255550123",');
  console.log('       "+14255550124",');
  console.log('       "Hello from ACS!"');
  console.log("   );");

  // ==========================================================================
  // Email Demo
  // ==========================================================================
  printSection("Email Service Demo");

  const emailService = new EmailService(config.connectionString);

  console.log("📧 Email Service initialized");
  console.log("   To send email, you need:");
  console.log("   1. An Email Communication Service resource");
  console.log("   2. A verified domain (Azure-managed or custom)");
  console.log();
  console.log("   Example usage:");
  console.log("   const result = await emailService.sendEmail(");
  console.log('       "DoNotReply@your-domain.azurecomm.net",');
  console.log('       "user@example.com",');
  console.log('       "Welcome!",');
  console.log('       "Hello from Azure Communication Services!"');
  console.log("   );");

  // ==========================================================================
  // Chat Demo
  // ==========================================================================
  printSection("Chat Service Demo");

  if (config.endpoint) {
    const chatService = new ChatService(config.endpoint, config.connectionString);

    console.log("💬 Chat Service initialized");
    console.log();

    // Create a user and get token
    console.log("Creating chat user...");
    const userResult = await chatService.createUserAndToken();

    if (userResult.success && userResult.token) {
      console.log(`   ✅ User created: ${userResult.userId?.substring(0, 50)}...`);
      console.log(`   ✅ Token expires: ${userResult.expiresOn}`);

      // Initialize chat client with the token
      chatService.initializeChatClient(userResult.token);
      console.log("   ✅ Chat client initialized");
    } else {
      console.log(`   ❌ Error: ${userResult.error}`);
    }
  } else {
    console.log("⚠️ Chat Service requires ACS_ENDPOINT to be set");
  }

  // ==========================================================================
  // Summary
  // ==========================================================================
  printSection("Summary");

  console.log("Available Services:");
  console.log("   ✅ SMS Service - Send text messages");
  console.log("   ✅ Email Service - Send transactional emails");
  console.log("   ✅ Chat Service - Real-time messaging");
  console.log();
  console.log("Next Steps:");
  console.log("   1. Provision phone numbers for SMS/Voice");
  console.log("   2. Link email domain to Communication Services");
  console.log("   3. Implement Event Grid webhooks for delivery reports");
  console.log("   4. Integrate with your application");
  console.log();
  console.log("Documentation: https://learn.microsoft.com/azure/communication-services/");
}

// Run the demo
main().catch(console.error);
