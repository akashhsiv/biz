using System.Text;

namespace Erp.Infrastructure.Documents;

public record TemplateParty(string Name, string? GstNumber, string? Address, string? Phone = null, string? State = null);
public record TemplateLine(string Description, decimal Quantity, decimal Rate, decimal Discount, decimal TaxRatePercent, decimal Cgst, decimal Sgst, decimal Igst, decimal LineTotal, string? HsnCode = null);
public record TemplateExtraRow(string Label, string Value);
public record TemplateBankDetails(string? BankName, string? AccountNumber, string? IfscCode, string? Branch)
{
    public bool HasAny => BankName is not null || AccountNumber is not null || IfscCode is not null || Branch is not null;
}

/// <summary>
/// Plain HTML+CSS templates, kept out of controllers/business logic — see ARCHITECTURE.md §35.
/// No external assets (fonts/CDN) so rendering stays fully offline. Layout modeled on a reference
/// invoice/estimate sample the shop provided: a bordered letterhead box, a two-column party/document-
/// details box, a numbered line-item table with an HSN-wise tax summary and amount-in-words below it,
/// then Terms &amp; Conditions and Bank Details/Signature boxes.
/// </summary>
public static class HtmlTemplates
{
    /// <summary>HTML-encodes free text before interpolation — every value passed into this
    /// template originates from user-entered data (customer/item names, shop details, and now
    /// admin-edited Terms & Conditions/footer text), so raw interpolation would both corrupt the
    /// layout on ordinary characters like "&" and "&lt;" and, for the free-text template fields
    /// specifically, inject arbitrary HTML into a Chromium-rendered PDF.</summary>
    private static string E(string? s) => System.Net.WebUtility.HtmlEncode(s) ?? "";

    /// <summary>Same as <see cref="E"/> but preserves line breaks the admin typed into a
    /// multi-line Terms &amp; Conditions/footer field — otherwise they'd collapse to one line.</summary>
    private static string EMultiline(string? s) => E(s).Replace("\n", "<br/>");

    public static string Document(
        string documentTitle, string documentNumber, DateTime date,
        TemplateParty shop, string partyLabel, TemplateParty party,
        IEnumerable<TemplateLine> lines,
        decimal subtotal, decimal overallDiscountAmount, decimal taxTotal, decimal grandTotal,
        IEnumerable<TemplateExtraRow>? extraRows = null,
        TemplateBankDetails? bankDetails = null,
        string? logoBase64 = null,
        string? termsAndConditions = null,
        string? footerNote = null,
        bool showSignatureBlock = false,
        string? upiQrBase64 = null,
        string? signatureBase64 = null,
        string? placeOfSupply = null,
        string? notes = null)
    {
        var lineList = lines.ToList();
        var placeOfSupplyDisplay = string.IsNullOrWhiteSpace(placeOfSupply) ? "-" : placeOfSupply;

        var sb = new StringBuilder();

        sb.Append($$"""
            <html>
            <head>
            <meta charset="utf-8" />
            <style>
                body { font-family: Arial, Helvetica, sans-serif; font-size: 11px; color: #222; margin: 16px; }
                h1.title { text-align: center; font-size: 20px; margin: 0 0 12px 0; }
                .box { border: 1px solid #999; margin-bottom: 12px; }
                .box-header { background: #eee; font-weight: bold; padding: 4px 8px; border-bottom: 1px solid #999; }
                .letterhead { display: flex; gap: 14px; align-items: flex-start; padding: 10px 12px; }
                .letterhead .shop-name { font-size: 18px; font-weight: bold; margin: 0 0 2px 0; }
                .letterhead .muted { color: #555; }
                .letterhead .row { margin-top: 2px; }
                .two-col { display: flex; }
                .two-col > div { width: 50%; padding: 8px 12px; font-size: 11px; }
                .two-col > div:first-child { border-right: 1px solid #999; }
                table.items { width: 100%; border-collapse: collapse; }
                table.items th, table.items td { border: 1px solid #999; padding: 5px 7px; font-size: 10.5px; text-align: left; vertical-align: top; }
                table.items th { background: #eee; }
                table.items td.num, table.items th.num { text-align: right; }
                table.items tr.total-row td { font-weight: bold; background: #f5f5f5; }
                .summary-wrap { display: flex; gap: 12px; align-items: flex-start; margin-bottom: 12px; }
                table.tax-summary { width: 60%; border-collapse: collapse; }
                table.tax-summary th, table.tax-summary td { border: 1px solid #999; padding: 4px 7px; font-size: 10px; text-align: right; }
                table.tax-summary th:first-child, table.tax-summary td:first-child { text-align: left; }
                table.tax-summary tr.total td { font-weight: bold; background: #f5f5f5; }
                .totals-box { width: 40%; border: 1px solid #999; }
                .totals-box .row { display: flex; justify-content: space-between; padding: 5px 8px; border-bottom: 1px solid #ccc; }
                .totals-box .row.grand { font-weight: bold; border-bottom: none; }
                .totals-box .words { padding: 6px 8px; font-size: 10px; border-top: 1px solid #999; }
                .words b { display: block; margin-bottom: 2px; }
                .terms { padding: 8px 12px; font-size: 10px; color: #333; white-space: normal; }
                .signature-cell { text-align: center; }
                .signature-cell img { max-height: 45px; max-width: 170px; object-fit: contain; }
                .signature-cell .line { margin-top: 36px; border-top: 1px solid #333; padding-top: 4px; }
                .qr-cell { text-align: center; }
                .qr-cell img { width: 90px; height: 90px; }
                .qr-cell .caption { font-size: 9px; color: #666; margin-top: 2px; }
                .footer { margin-top: 16px; font-size: 9.5px; color: #666; text-align: center; }
            </style>
            </head>
            <body>
                <h1 class="title">{{E(documentTitle)}}</h1>

                <div class="box letterhead">
                    {{(logoBase64 is null ? "" : $"""<img src="data:image/png;base64,{logoBase64}" style="max-height:56px; max-width:150px; object-fit:contain;" />""")}}
                    <div>
                        <div class="shop-name">{{E(shop.Name)}}</div>
                        {{(shop.Address is null ? "" : $"""<div class="muted">{E(shop.Address)}</div>""")}}
                        <div class="row">
                            {{(shop.Phone is null ? "" : $"Phone: <b>{E(shop.Phone)}</b>")}}
                        </div>
                        <div class="row">
                            GSTIN: <b>{{E(shop.GstNumber)}}</b>&nbsp;&nbsp;&nbsp;State: <b>{{E(shop.State)}}</b>
                        </div>
                    </div>
                </div>

                <div class="box two-col">
                    <div>
                        <div style="font-weight:bold; margin-bottom:4px;">{{E(partyLabel)}}</div>
                        <div>{{E(party.Name)}}</div>
                        {{(party.Address is null ? "" : $"""<div class="muted">{E(party.Address)}</div>""")}}
                        <div class="muted">GSTIN: {{E(party.GstNumber ?? "-")}}</div>
                        {{(party.Phone is null ? "" : $"""<div class="muted">Contact No: {E(party.Phone)}</div>""")}}
                    </div>
                    <div>
                        <div style="font-weight:bold; margin-bottom:4px;">Document Details</div>
                        <div>No.: <b>{{E(documentNumber)}}</b></div>
                        <div>Date: <b>{{date:dd/MM/yyyy}}</b></div>
                        <div>Place Of Supply: <b>{{E(placeOfSupplyDisplay)}}</b></div>
            """);

        if (extraRows is not null)
        {
            foreach (var row in extraRows)
                sb.Append($"""<div>{E(row.Label)}: <b>{E(row.Value)}</b></div>""");
        }

        sb.Append("""
                    </div>
                </div>

                <table class="items">
                    <thead>
                        <tr>
                            <th style="width:24px;">#</th><th>Item</th><th>HSN/SAC</th><th class="num">Qty</th>
                            <th class="num">Rate</th><th class="num">Discount</th><th class="num">Tax</th><th class="num">Amount</th>
                        </tr>
                    </thead>
                    <tbody>
            """);

        var n = 0;
        foreach (var line in lineList)
        {
            n++;
            var lineTax = line.Cgst + line.Sgst + line.Igst;
            sb.Append($"""
                        <tr>
                            <td>{n}</td>
                            <td>{E(line.Description)}</td>
                            <td>{E(line.HsnCode ?? "-")}</td>
                            <td class="num">{line.Quantity:0.###}</td>
                            <td class="num">₹{line.Rate:0.00}</td>
                            <td class="num">₹{line.Discount:0.00}</td>
                            <td class="num">₹{lineTax:0.00} ({line.TaxRatePercent:0.##}%)</td>
                            <td class="num">₹{line.LineTotal:0.00}</td>
                        </tr>
            """);
        }

        var totalQty = lineList.Sum(l => l.Quantity);
        sb.Append($$"""
                        <tr class="total-row">
                            <td colspan="3">Total</td>
                            <td class="num">{{totalQty:0.###}}</td>
                            <td colspan="2"></td>
                            <td class="num">₹{{taxTotal:0.00}}</td>
                            <td class="num">₹{{grandTotal:0.00}}</td>
                        </tr>
                    </tbody>
                </table>
            """);

        // HSN-wise tax breakdown, same underlying per-line CGST/SGST/IGST this document's own
        // total already sums - grouped here purely for the summary table, not recomputed.
        var hsnGroups = lineList
            .GroupBy(l => l.HsnCode ?? "-")
            .Select(g => (
                Hsn: g.Key,
                Taxable: g.Sum(l => l.Rate * l.Quantity - l.Discount),
                Cgst: g.Sum(l => l.Cgst),
                Sgst: g.Sum(l => l.Sgst),
                Igst: g.Sum(l => l.Igst)))
            .OrderBy(g => g.Hsn)
            .ToList();
        var hasCgstSgst = hsnGroups.Any(g => g.Cgst > 0 || g.Sgst > 0);
        var hasIgst = hsnGroups.Any(g => g.Igst > 0);

        sb.Append("""
            <div class="summary-wrap">
                <table class="tax-summary">
                    <thead>
                        <tr>
                            <th>HSN/SAC</th><th>Taxable (₹)</th>
            """);
        if (hasCgstSgst) sb.Append("<th>CGST (₹)</th><th>SGST (₹)</th>");
        if (hasIgst) sb.Append("<th>IGST (₹)</th>");
        sb.Append("""<th>Total Tax (₹)</th></tr></thead><tbody>""");

        foreach (var g in hsnGroups)
        {
            sb.Append($"""<tr><td>{E(g.Hsn)}</td><td>{g.Taxable:0.00}</td>""");
            if (hasCgstSgst) sb.Append($"""<td>{g.Cgst:0.00}</td><td>{g.Sgst:0.00}</td>""");
            if (hasIgst) sb.Append($"""<td>{g.Igst:0.00}</td>""");
            sb.Append($"""<td>{(g.Cgst + g.Sgst + g.Igst):0.00}</td></tr>""");
        }

        var totalTaxable = hsnGroups.Sum(g => g.Taxable);
        sb.Append($$"""<tr class="total"><td>Total</td><td>{{totalTaxable:0.00}}</td>""");
        if (hasCgstSgst) sb.Append($$"""<td>{{hsnGroups.Sum(g => g.Cgst):0.00}}</td><td>{{hsnGroups.Sum(g => g.Sgst):0.00}}</td>""");
        if (hasIgst) sb.Append($$"""<td>{{hsnGroups.Sum(g => g.Igst):0.00}}</td>""");
        sb.Append($$"""<td>{{taxTotal:0.00}}</td></tr></tbody></table>""");

        sb.Append($$"""
                <div class="totals-box">
                    <div class="row"><span>Subtotal</span><span>₹{{subtotal:0.00}}</span></div>
                    {{(overallDiscountAmount > 0 ? $"""<div class="row"><span>Overall Discount</span><span>-₹{overallDiscountAmount:0.00}</span></div>""" : "")}}
                    <div class="row"><span>Tax</span><span>₹{{taxTotal:0.00}}</span></div>
                    <div class="row grand"><span>Grand Total</span><span>₹{{grandTotal:0.00}}</span></div>
                    <div class="words"><b>Amount in Words:</b>{{E(AmountInWords.Convert(grandTotal))}} </div>
                </div>
            </div>
            """);

        if (!string.IsNullOrWhiteSpace(notes))
        {
            sb.Append($$"""
                <div class="box">
                    <div class="box-header">Notes</div>
                    <div class="terms">{{EMultiline(notes)}}</div>
                </div>
                """);
        }

        if (!string.IsNullOrWhiteSpace(termsAndConditions))
        {
            sb.Append($$"""
                <div class="box">
                    <div class="box-header">Terms &amp; Conditions</div>
                    <div class="terms">{{EMultiline(termsAndConditions)}}</div>
                </div>
                """);
        }

        if (bankDetails is { HasAny: true } || upiQrBase64 is not null || showSignatureBlock)
        {
            sb.Append("""<div class="box two-col">""");

            sb.Append("<div>");
            if (bankDetails is { HasAny: true })
            {
                sb.Append("""<div style="font-weight:bold; margin-bottom:4px;">Bank Details</div>""");
                if (bankDetails.BankName is not null) sb.Append($"""<div>Name: <b>{E(bankDetails.BankName)}</b></div>""");
                if (bankDetails.AccountNumber is not null) sb.Append($"""<div>Account No.: <b>{E(bankDetails.AccountNumber)}</b></div>""");
                if (bankDetails.IfscCode is not null) sb.Append($"""<div>IFSC: <b>{E(bankDetails.IfscCode)}</b></div>""");
                if (bankDetails.Branch is not null) sb.Append($"""<div>Branch: <b>{E(bankDetails.Branch)}</b></div>""");
            }
            if (upiQrBase64 is not null)
            {
                sb.Append($"""
                    <div class="qr-cell" style="margin-top:8px;">
                        <img src="data:image/png;base64,{upiQrBase64}" />
                        <div class="caption">Scan to pay via UPI</div>
                    </div>
                    """);
            }
            sb.Append("</div>");

            sb.Append("<div class=\"signature-cell\">");
            if (showSignatureBlock)
            {
                sb.Append($"""<div style="font-weight:bold; margin-bottom:4px;">For {E(shop.Name)}</div>""");
                if (signatureBase64 is not null) sb.Append($"""<img src="data:image/png;base64,{signatureBase64}" />""");
                sb.Append("""<div class="line">Authorized Signatory</div>""");
            }
            sb.Append("</div>");

            sb.Append("</div>");
        }

        var effectiveFooterNote = string.IsNullOrWhiteSpace(footerNote)
            ? "Generated by the ERP system. This document was produced entirely offline."
            : footerNote;

        sb.Append($$"""
                <div class="footer">{{EMultiline(effectiveFooterNote)}}</div>
            </body>
            </html>
            """);

        return sb.ToString();
    }
}
