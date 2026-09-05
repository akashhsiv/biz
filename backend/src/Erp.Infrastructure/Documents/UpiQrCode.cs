using QRCoder;

namespace Erp.Infrastructure.Documents;

/// <summary>Builds a UPI deep link (`upi://pay?...`) and renders it as a QR PNG, embedded in
/// generated PDFs the same base64 way the shop logo already is. Dynamic (includes the document's
/// amount) so the customer's UPI app pre-fills it on scan, confirmed decision 2026-08-28.</summary>
public static class UpiQrCode
{
    public static string GeneratePngBase64(string upiId, string payeeName, decimal amount)
    {
        var uri = $"upi://pay?pa={Uri.EscapeDataString(upiId)}&pn={Uri.EscapeDataString(payeeName)}&am={amount:0.00}&cu=INR";

        using var generator = new QRCodeGenerator();
        using var data = generator.CreateQrCode(uri, QRCodeGenerator.ECCLevel.M);
        using var pngQr = new PngByteQRCode(data);
        var bytes = pngQr.GetGraphic(10);

        return Convert.ToBase64String(bytes);
    }
}
