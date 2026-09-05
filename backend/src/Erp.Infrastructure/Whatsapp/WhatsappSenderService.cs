using System.Net.Http.Headers;
using System.Text;

namespace Erp.Infrastructure.Whatsapp;

/// <summary>
/// The actual "POST this payload to the bridge's /send endpoint" logic, shared by
/// WhatsappController (immediate send-on-request, and the standalone test-send tool) and
/// WhatsappOutboxWorker (background retry of anything that couldn't be sent immediately) — one
/// place owns the HTTP call instead of two slightly-different copies of it.
/// </summary>
public class WhatsappSenderService(IHttpClientFactory httpClientFactory, WhatsappBridgeLocator bridgeLocator)
{
    public async Task<(bool Success, string? Error)> TrySendAsync(string payloadJson, CancellationToken ct)
    {
        var baseUrl = bridgeLocator.BaseUrl;
        if (string.IsNullOrWhiteSpace(baseUrl))
            return (false, "Could not resolve the WhatsApp bridge's URL.");

        try
        {
            var client = httpClientFactory.CreateClient();
            // A PDF-attached send has to upload the document to WhatsApp's media servers (not just
            // deliver a text stanza), which routinely takes longer than a plain text message.
            client.Timeout = TimeSpan.FromSeconds(45);

            var content = new StringContent(payloadJson, Encoding.UTF8);
            content.Headers.ContentType = new MediaTypeHeaderValue("application/json");
            var response = await client.PostAsync($"{baseUrl.TrimEnd('/')}/send", content, ct);

            if (response.IsSuccessStatusCode) return (true, null);

            var body = await response.Content.ReadAsStringAsync(ct);
            return (false, $"HTTP {(int)response.StatusCode}\n{body}");
        }
        catch (Exception ex)
        {
            return (false, ex.Message);
        }
    }
}
