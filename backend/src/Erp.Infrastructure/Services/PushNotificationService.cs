using Erp.Application.Notifications;
using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace Erp.Infrastructure.Services;

/// <summary>FCM-backed mobile push. The user does not have Firebase credentials yet, so this is built
/// to be fully wired but gracefully inert until Firebase:ServiceAccountJsonPath (see appsettings.json)
/// points at a real service-account JSON file:
///   - unset/missing file: logs one warning at startup, then every SendAsync call is a silent
///     no-op (debug-level log only) — never throws, never blocks NotificationDispatcher.
///   - configured: initializes a single FirebaseApp from that service account and sends via
///     FirebaseMessaging.SendAsync.
/// Registered as a singleton in Program.cs since FirebaseApp init should happen once per process.</summary>
public class PushNotificationService : IPushNotificationService
{
    private readonly ILogger<PushNotificationService> _logger;
    private readonly FirebaseApp? _app;

    public PushNotificationService(IConfiguration configuration, ILogger<PushNotificationService> logger)
    {
        _logger = logger;

        var path = configuration["Firebase:ServiceAccountJsonPath"];
        if (string.IsNullOrWhiteSpace(path) || !File.Exists(path))
        {
            _logger.LogWarning(
                "Firebase not configured (Firebase:ServiceAccountJsonPath is unset or the file does not exist) — mobile push notifications will be queued but not delivered.");
            _app = null;
            return;
        }

        try
        {
            _app = FirebaseApp.Create(new AppOptions
            {
                Credential = GoogleCredential.FromFile(path),
            }, "erp-push");
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to initialize Firebase from {Path} — mobile push notifications will be queued but not delivered.", path);
            _app = null;
        }
    }

    public bool IsConfigured => _app is not null;

    public async Task<bool> SendAsync(string token, string title, string body, CancellationToken ct = default)
    {
        if (_app is null)
        {
            _logger.LogDebug("Skipping push send to {Token} — Firebase is not configured.", token);
            return false;
        }

        try
        {
            var messaging = FirebaseMessaging.GetMessaging(_app);
            await messaging.SendAsync(new Message
            {
                Token = token,
                Notification = new FirebaseAdmin.Messaging.Notification { Title = title, Body = body },
            }, ct);
            return true;
        }
        catch (Exception ex)
        {
            // Never let a push failure (bad/expired token, FCM outage, etc.) bubble up and abort
            // dispatch of the underlying NotificationEvent — push is best-effort.
            _logger.LogWarning(ex, "Failed to send push notification to device token {Token}", token);
            return false;
        }
    }
}
