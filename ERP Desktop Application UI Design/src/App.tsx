import { useState, useRef, useEffect } from "react";

// ── Types ──────────────────────────────────────────────────────────────────────
type Screen =
  | "dashboard" | "customers" | "items" | "quotations" | "proformas"
  | "sales-invoices" | "deposits" | "purchases" | "stock" | "returns"
  | "finance" | "users" | "reports" | "whatsapp" | "settings";

type StatusChipVariant =
  | "draft" | "issued" | "paid" | "overdue" | "converted"
  | "cancelled" | "active" | "inactive" | "pending" | "received";

type Tab = string;

// ── Design Tokens ──────────────────────────────────────────────────────────────
const C = {
  primary: "#3F51B5",
  primaryLight: "#E8EAF6",
  primaryDark: "#303F9F",
  sidebar: "#1E2A5E",
  sidebarText: "rgba(255,255,255,0.75)",
  sidebarTextActive: "#ffffff",
  sidebarHover: "rgba(255,255,255,0.07)",
  sidebarActive: "rgba(255,255,255,0.14)",
  surface: "#FAFAFA",
  card: "#ffffff",
  border: "#E0E0E0",
  text: "#1A1A2E",
  textSec: "#616161",
  textMuted: "#9E9E9E",
  success: "#2E7D32",
  successLight: "#E8F5E9",
  successText: "#1B5E20",
  warning: "#B45309",
  warningLight: "#FEF3C7",
  warningText: "#92400E",
  error: "#B91C1C",
  errorLight: "#FEE2E2",
  errorText: "#7F1D1D",
  amber: "#D97706",
  amberLight: "#FFFBEB",
};

// ── Shared Components ──────────────────────────────────────────────────────────

function StatusChip({ variant }: { variant: StatusChipVariant }) {
  const map: Record<StatusChipVariant, { label: string; bg: string; text: string }> = {
    draft:     { label: "Draft",     bg: "#F3F4F6", text: "#374151" },
    issued:    { label: "Issued",    bg: C.primaryLight, text: C.primaryDark },
    paid:      { label: "Paid",      bg: C.successLight, text: C.successText },
    overdue:   { label: "Overdue",   bg: C.errorLight, text: C.errorText },
    converted: { label: "Converted", bg: "#EDE9FE", text: "#5B21B6" },
    cancelled: { label: "Cancelled", bg: "#F3F4F6", text: "#6B7280" },
    active:    { label: "Active",    bg: C.successLight, text: C.successText },
    inactive:  { label: "Inactive",  bg: "#F3F4F6", text: "#6B7280" },
    pending:   { label: "Pending",   bg: C.warningLight, text: C.warningText },
    received:  { label: "Received",  bg: "#DBEAFE", text: "#1D4ED8" },
  };
  const { label, bg, text } = map[variant];
  return (
    <span style={{
      background: bg, color: text,
      fontSize: 11, fontWeight: 600, letterSpacing: "0.04em",
      padding: "2px 9px", borderRadius: 100, display: "inline-block",
      textTransform: "uppercase",
    }}>
      {label}
    </span>
  );
}

function FAB({ onClick, label = "Add New" }: { onClick: () => void; label?: string }) {
  return (
    <button
      onClick={onClick}
      title={label}
      style={{
        position: "fixed", bottom: 32, right: 32,
        width: 56, height: 56, borderRadius: "50%",
        background: C.primary, color: "#fff", border: "none",
        boxShadow: "0 4px 16px rgba(63,81,181,0.45)",
        cursor: "pointer", display: "flex", alignItems: "center",
        justifyContent: "center", fontSize: 26, fontWeight: 300,
        transition: "transform 0.15s, box-shadow 0.15s",
        zIndex: 40,
      }}
      onMouseEnter={e => {
        (e.currentTarget as HTMLButtonElement).style.transform = "scale(1.08)";
        (e.currentTarget as HTMLButtonElement).style.boxShadow = "0 6px 24px rgba(63,81,181,0.55)";
      }}
      onMouseLeave={e => {
        (e.currentTarget as HTMLButtonElement).style.transform = "scale(1)";
        (e.currentTarget as HTMLButtonElement).style.boxShadow = "0 4px 16px rgba(63,81,181,0.45)";
      }}
    >
      +
    </button>
  );
}

function Card({ children, style }: { children: React.ReactNode; style?: React.CSSProperties }) {
  return (
    <div style={{
      background: C.card, borderRadius: 10, padding: "20px 24px",
      boxShadow: "0 1px 4px rgba(0,0,0,0.08), 0 0 1px rgba(0,0,0,0.06)",
      border: `1px solid ${C.border}`, ...style
    }}>
      {children}
    </div>
  );
}

function PageHeader({
  title, children,
}: { title: string; children?: React.ReactNode }) {
  return (
    <div style={{
      display: "flex", alignItems: "center", justifyContent: "space-between",
      padding: "18px 28px 0", marginBottom: 20,
    }}>
      <h1 style={{ fontSize: 22, fontWeight: 700, color: C.text, margin: 0 }}>{title}</h1>
      <div style={{ display: "flex", alignItems: "center", gap: 10 }}>{children}</div>
    </div>
  );
}

function IconBtn({ title, onClick, children }: {
  title: string; onClick?: () => void; children: React.ReactNode;
}) {
  return (
    <button
      title={title} onClick={onClick}
      style={{
        background: "none", border: `1px solid ${C.border}`, borderRadius: 8,
        padding: "6px 10px", cursor: "pointer", color: C.textSec,
        display: "flex", alignItems: "center", gap: 6, fontSize: 13,
        transition: "background 0.12s",
      }}
      onMouseEnter={e => (e.currentTarget.style.background = "#F5F5F5")}
      onMouseLeave={e => (e.currentTarget.style.background = "none")}
    >
      {children}
    </button>
  );
}

function SearchBar({ placeholder, value, onChange }: {
  placeholder?: string; value: string; onChange: (v: string) => void;
}) {
  return (
    <div style={{ position: "relative", flex: 1, maxWidth: 320 }}>
      <span style={{
        position: "absolute", left: 10, top: "50%", transform: "translateY(-50%)",
        color: C.textMuted, fontSize: 15, pointerEvents: "none",
      }}>🔍</span>
      <input
        value={value} onChange={e => onChange(e.target.value)}
        placeholder={placeholder || "Search…"}
        style={{
          width: "100%", paddingLeft: 34, paddingRight: 12,
          paddingTop: 8, paddingBottom: 8,
          border: `1px solid ${C.border}`, borderRadius: 8,
          fontSize: 13, color: C.text, background: "#fff",
          outline: "none", fontFamily: "inherit",
        }}
        onFocus={e => (e.target.style.borderColor = C.primary)}
        onBlur={e => (e.target.style.borderColor = C.border)}
      />
    </div>
  );
}

function Tabs({ tabs, active, onChange }: {
  tabs: Tab[]; active: Tab; onChange: (t: Tab) => void;
}) {
  return (
    <div style={{
      display: "flex", borderBottom: `2px solid ${C.border}`,
      marginBottom: 20, gap: 0,
    }}>
      {tabs.map(tab => (
        <button key={tab} onClick={() => onChange(tab)} style={{
          padding: "10px 20px", background: "none", border: "none",
          cursor: "pointer", fontSize: 13, fontWeight: active === tab ? 600 : 400,
          color: active === tab ? C.primary : C.textSec,
          borderBottom: active === tab ? `2px solid ${C.primary}` : "2px solid transparent",
          marginBottom: -2, transition: "color 0.12s",
          fontFamily: "inherit",
        }}>
          {tab}
        </button>
      ))}
    </div>
  );
}

// ── Modal Dialog ───────────────────────────────────────────────────────────────
function Modal({
  open, title, onClose, onSave, children, maxWidth = 440, saveLabel = "Save",
}: {
  open: boolean; title: string; onClose: () => void; onSave?: () => void;
  children: React.ReactNode; maxWidth?: number; saveLabel?: string;
}) {
  if (!open) return null;
  return (
    <div style={{
      position: "fixed", inset: 0, background: "rgba(0,0,0,0.35)",
      display: "flex", alignItems: "center", justifyContent: "center",
      zIndex: 200, backdropFilter: "blur(2px)",
    }}
      onClick={e => { if (e.target === e.currentTarget) onClose(); }}
    >
      <div style={{
        background: "#fff", borderRadius: 12, width: "100%", maxWidth,
        maxHeight: "90vh", display: "flex", flexDirection: "column",
        boxShadow: "0 8px 40px rgba(0,0,0,0.18)",
        animation: "dialogIn 0.18s ease",
      }}>
        <style>{`@keyframes dialogIn { from { opacity:0; transform:translateY(-8px) scale(0.98); } to { opacity:1; transform:none; } }`}</style>
        <div style={{
          padding: "20px 24px 16px", borderBottom: `1px solid ${C.border}`,
          display: "flex", alignItems: "center", justifyContent: "space-between",
        }}>
          <span style={{ fontSize: 16, fontWeight: 700, color: C.text }}>{title}</span>
          <button onClick={onClose} style={{
            background: "none", border: "none", cursor: "pointer",
            color: C.textMuted, fontSize: 20, lineHeight: 1,
          }}>×</button>
        </div>
        <div style={{ padding: "20px 24px", overflowY: "auto", flex: 1 }}>
          {children}
        </div>
        <div style={{
          padding: "14px 24px", borderTop: `1px solid ${C.border}`,
          display: "flex", gap: 10, justifyContent: "flex-end",
        }}>
          <button onClick={onClose} style={{
            padding: "8px 20px", borderRadius: 8, border: `1px solid ${C.border}`,
            background: "none", cursor: "pointer", fontSize: 13, fontFamily: "inherit",
            color: C.textSec,
          }}>Cancel</button>
          {onSave && (
            <button onClick={onSave} style={{
              padding: "8px 20px", borderRadius: 8, border: "none",
              background: C.primary, color: "#fff", cursor: "pointer",
              fontSize: 13, fontWeight: 600, fontFamily: "inherit",
            }}>{saveLabel}</button>
          )}
        </div>
      </div>
    </div>
  );
}

function FormField({
  label, required, children, error,
}: { label: string; required?: boolean; children: React.ReactNode; error?: string }) {
  return (
    <div style={{ marginBottom: 16 }}>
      <label style={{ display: "block", fontSize: 12, fontWeight: 600, color: C.textSec, marginBottom: 5 }}>
        {label}{required && <span style={{ color: C.error }}> *</span>}
      </label>
      {children}
      {error && <div style={{ color: C.error, fontSize: 11, marginTop: 4 }}>{error}</div>}
    </div>
  );
}

function TextInput({
  value, onChange, placeholder, type = "text",
}: { value: string; onChange: (v: string) => void; placeholder?: string; type?: string }) {
  return (
    <input
      type={type} value={value} onChange={e => onChange(e.target.value)}
      placeholder={placeholder}
      style={{
        width: "100%", padding: "8px 12px", border: `1px solid ${C.border}`,
        borderRadius: 8, fontSize: 13, color: C.text, fontFamily: "inherit",
        outline: "none", background: "#fff",
      }}
      onFocus={e => (e.target.style.borderColor = C.primary)}
      onBlur={e => (e.target.style.borderColor = C.border)}
    />
  );
}

function Select({
  value, onChange, options,
}: { value: string; onChange: (v: string) => void; options: { value: string; label: string }[] }) {
  return (
    <select
      value={value} onChange={e => onChange(e.target.value)}
      style={{
        width: "100%", padding: "8px 12px", border: `1px solid ${C.border}`,
        borderRadius: 8, fontSize: 13, color: C.text, fontFamily: "inherit",
        outline: "none", background: "#fff", cursor: "pointer",
      }}
      onFocus={e => (e.target.style.borderColor = C.primary)}
      onBlur={e => (e.target.style.borderColor = C.border)}
    >
      {options.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
    </select>
  );
}

// ── Keyboard Shortcuts Overlay ─────────────────────────────────────────────────
const SHORTCUTS = [
  ["F1", "Show keyboard shortcuts"],
  ["Ctrl+N", "New record (FAB action)"],
  ["Ctrl+F", "Focus search bar"],
  ["Ctrl+R", "Refresh current screen"],
  ["Ctrl+P", "Print current document"],
  ["Ctrl+S", "Save form / dialog"],
  ["Enter / ↓", "Next field in form"],
  ["↑", "Previous field in form"],
  ["Escape", "Close dialog"],
  ["Ctrl+1…9", "Switch sidebar section"],
  ["Ctrl+D", "Go to Dashboard"],
  ["Ctrl+L", "Logout"],
  ["Ctrl+W", "WhatsApp pairing"],
  ["Ctrl+I", "Items list"],
  ["Ctrl+Q", "Quotations list"],
];

function ShortcutsOverlay({ onClose }: { onClose: () => void }) {
  return (
    <Modal open title="Keyboard Shortcuts" onClose={onClose} maxWidth={480}>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "6px 24px" }}>
        {SHORTCUTS.map(([key, desc]) => (
          <div key={key} style={{ display: "flex", alignItems: "baseline", gap: 8, padding: "5px 0" }}>
            <span style={{
              fontFamily: "JetBrains Mono, monospace", fontSize: 11, fontWeight: 500,
              background: C.primaryLight, color: C.primaryDark, padding: "2px 7px",
              borderRadius: 5, whiteSpace: "nowrap", flexShrink: 0,
            }}>{key}</span>
            <span style={{ fontSize: 12, color: C.textSec }}>{desc}</span>
          </div>
        ))}
      </div>
    </Modal>
  );
}

// ── Connectivity Banner ────────────────────────────────────────────────────────
function ConnBanner({ show }: { show: boolean }) {
  if (!show) return null;
  return (
    <div style={{
      background: "#FEF3C7", borderBottom: `1px solid #FDE68A`,
      padding: "6px 28px", display: "flex", alignItems: "center", gap: 8,
      fontSize: 12, color: "#92400E",
    }}>
      <span>⚠️</span>
      <span>Connection to local server is degraded — data may be stale. Retrying…</span>
    </div>
  );
}

// ── Sidebar ────────────────────────────────────────────────────────────────────
type NavItem = { id: Screen; icon: string; label: string };

const NAV_ITEMS: NavItem[] = [
  { id: "dashboard",      icon: "⊞",  label: "Dashboard" },
  { id: "customers",      icon: "👥", label: "Customers" },
  { id: "items",          icon: "📦", label: "Items" },
  { id: "quotations",     icon: "📋", label: "Quotations" },
  { id: "proformas",      icon: "📄", label: "Proformas" },
  { id: "sales-invoices", icon: "🧾", label: "Sales Invoices" },
  { id: "deposits",       icon: "💰", label: "Deposits" },
  { id: "purchases",      icon: "🛒", label: "Purchases" },
  { id: "stock",          icon: "🏗",  label: "Stock" },
  { id: "returns",        icon: "↩️",  label: "Returns" },
  { id: "finance",        icon: "📊", label: "Finance" },
  { id: "users",          icon: "🔐", label: "Users & Roles" },
  { id: "reports",        icon: "📈", label: "Reports" },
  { id: "whatsapp",       icon: "💬", label: "WhatsApp" },
  { id: "settings",       icon: "⚙️",  label: "Shop Settings" },
];

function Sidebar({
  active, onNavigate, onShortcuts,
}: { active: Screen; onNavigate: (s: Screen) => void; onShortcuts: () => void }) {
  return (
    <aside style={{
      width: 220, minWidth: 220, height: "100%",
      background: C.sidebar, display: "flex", flexDirection: "column",
      borderRight: "none", flexShrink: 0,
    }}>
      {/* Shop header */}
      <div style={{
        padding: "18px 16px 14px", borderBottom: "1px solid rgba(255,255,255,0.08)",
      }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <div style={{
            width: 36, height: 36, borderRadius: 8, background: C.primary,
            display: "flex", alignItems: "center", justifyContent: "center",
            fontSize: 16, flexShrink: 0, border: "2px solid rgba(255,255,255,0.2)",
          }}>🏪</div>
          <div>
            <div style={{ color: "#fff", fontWeight: 700, fontSize: 13, lineHeight: 1.2 }}>Sharma Traders</div>
            <div style={{ color: "rgba(255,255,255,0.45)", fontSize: 10, marginTop: 2 }}>GSTIN: 29AAACS1234A1Z5</div>
          </div>
        </div>
      </div>

      {/* Nav items */}
      <nav style={{ flex: 1, overflowY: "auto", padding: "8px 0" }}>
        {NAV_ITEMS.map(item => {
          const isActive = active === item.id;
          return (
            <button
              key={item.id}
              onClick={() => onNavigate(item.id)}
              style={{
                width: "100%", display: "flex", alignItems: "center", gap: 11,
                padding: "9px 16px", background: isActive ? C.sidebarActive : "none",
                border: "none", cursor: "pointer", textAlign: "left",
                transition: "background 0.12s",
                borderLeft: isActive ? `3px solid ${C.primary}` : "3px solid transparent",
              }}
              onMouseEnter={e => { if (!isActive) e.currentTarget.style.background = C.sidebarHover; }}
              onMouseLeave={e => { if (!isActive) e.currentTarget.style.background = "none"; }}
            >
              <span style={{ fontSize: 15, width: 20, textAlign: "center", flexShrink: 0 }}>{item.icon}</span>
              <span style={{
                fontSize: 13, fontWeight: isActive ? 600 : 400,
                color: isActive ? C.sidebarTextActive : C.sidebarText,
              }}>{item.label}</span>
            </button>
          );
        })}
      </nav>

      {/* Bottom actions */}
      <div style={{ borderTop: "1px solid rgba(255,255,255,0.08)", padding: "10px 16px", display: "flex", gap: 8 }}>
        <button
          onClick={onShortcuts}
          title="Keyboard shortcuts (F1)"
          style={{
            flex: 1, padding: "8px 6px", background: C.sidebarHover, border: "1px solid rgba(255,255,255,0.1)",
            borderRadius: 7, cursor: "pointer", color: "rgba(255,255,255,0.6)",
            fontSize: 11, fontFamily: "inherit", display: "flex", alignItems: "center",
            justifyContent: "center", gap: 5,
          }}
          onMouseEnter={e => (e.currentTarget.style.background = "rgba(255,255,255,0.12)")}
          onMouseLeave={e => (e.currentTarget.style.background = C.sidebarHover)}
        >
          ⌨️ <span>Shortcuts</span>
        </button>
        <button
          title="Logout"
          style={{
            padding: "8px 10px", background: C.sidebarHover, border: "1px solid rgba(255,255,255,0.1)",
            borderRadius: 7, cursor: "pointer", color: "rgba(255,255,255,0.6)",
            fontSize: 15, fontFamily: "inherit",
          }}
          onMouseEnter={e => (e.currentTarget.style.background = "rgba(220,50,50,0.2)")}
          onMouseLeave={e => (e.currentTarget.style.background = C.sidebarHover)}
        >
          🚪
        </button>
      </div>
    </aside>
  );
}

// ── Dashboard Screen ───────────────────────────────────────────────────────────
function KpiCard({ icon, label, value, sub, color = C.primary, trend }: {
  icon: string; label: string; value: string; sub?: string; color?: string; trend?: string;
}) {
  return (
    <Card>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
        <div>
          <div style={{ fontSize: 12, fontWeight: 500, color: C.textSec, textTransform: "uppercase", letterSpacing: "0.06em", marginBottom: 8 }}>{label}</div>
          <div style={{ fontSize: 28, fontWeight: 700, color: C.text, lineHeight: 1, marginBottom: 4 }}>{value}</div>
          {sub && <div style={{ fontSize: 12, color: C.textMuted, marginTop: 4 }}>{sub}</div>}
        </div>
        <div style={{
          width: 44, height: 44, borderRadius: 10, display: "flex",
          alignItems: "center", justifyContent: "center",
          background: color + "18", fontSize: 22,
        }}>{icon}</div>
      </div>
      {trend && (
        <div style={{
          marginTop: 12, paddingTop: 12, borderTop: `1px solid ${C.border}`,
          fontSize: 11, color: trend.startsWith("+") ? C.success : C.error,
          fontWeight: 500,
        }}>{trend} vs yesterday</div>
      )}
    </Card>
  );
}

const RECENT_ACTIVITY = [
  { type: "invoice", doc: "INV-2024-0382", customer: "Ravi Enterprises", amount: "₹14,500", status: "paid" as StatusChipVariant, time: "2 min ago" },
  { type: "quotation", doc: "QUO-2024-0218", customer: "Nisha General Store", amount: "₹8,200", status: "issued" as StatusChipVariant, time: "18 min ago" },
  { type: "purchase", doc: "PO-2024-0091", customer: "Agro Supplies Ltd", amount: "₹32,000", status: "received" as StatusChipVariant, time: "1 hr ago" },
  { type: "invoice", doc: "INV-2024-0381", customer: "Mahesh & Co", amount: "₹6,750", status: "overdue" as StatusChipVariant, time: "3 hr ago" },
  { type: "deposit", doc: "DEP-2024-0055", customer: "Krishna Traders", amount: "₹5,000", status: "paid" as StatusChipVariant, time: "5 hr ago" },
  { type: "returns", doc: "RET-2024-0012", customer: "Ganesh Stores", amount: "₹1,200", status: "pending" as StatusChipVariant, time: "Yesterday" },
];

const LOW_STOCK = [
  { name: "Basmati Rice 5kg", sku: "SKU-0023", stock: 4, unit: "bag", reorder: 20 },
  { name: "Saffola Gold Oil 1L", sku: "SKU-0047", stock: 2, unit: "bottle", reorder: 12 },
  { name: "Toor Dal 1kg", sku: "SKU-0061", stock: 7, unit: "kg", reorder: 30 },
];

function DashboardScreen() {
  return (
    <div style={{ padding: "0 28px 32px" }}>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(4,1fr)", gap: 16, marginBottom: 24 }}>
        <KpiCard icon="🧾" label="Today's Sales" value="₹42,810" sub="23 invoices" color={C.primary} trend="+12.4%" />
        <KpiCard icon="⏳" label="Outstanding Dues" value="₹1,24,500" sub="17 customers" color={C.amber} trend="+3.1%" />
        <KpiCard icon="⚠️" label="Low Stock Alerts" value="3 items" sub="Below reorder level" color={C.error} />
        <KpiCard icon="💰" label="Shop Balance" value="₹2,38,640" sub="As of today" color={C.success} trend="+₹8,200" />
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "1.6fr 1fr", gap: 20 }}>
        <Card>
          <div style={{ fontWeight: 700, fontSize: 14, marginBottom: 16, color: C.text }}>Recent Activity</div>
          <table style={{ width: "100%", borderCollapse: "collapse" }}>
            <thead>
              <tr>
                {["Document", "Customer", "Amount", "Status", "Time"].map(h => (
                  <th key={h} style={{ textAlign: "left", fontSize: 11, fontWeight: 600, color: C.textMuted, padding: "0 0 10px", textTransform: "uppercase", letterSpacing: "0.06em" }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {RECENT_ACTIVITY.map((row, i) => (
                <tr key={i} style={{ borderTop: `1px solid ${C.border}` }}>
                  <td style={{ padding: "10px 0", fontSize: 13, fontFamily: "JetBrains Mono, monospace", color: C.primaryDark, fontWeight: 500 }}>{row.doc}</td>
                  <td style={{ padding: "10px 0", fontSize: 13, color: C.text }}>{row.customer}</td>
                  <td style={{ padding: "10px 0", fontSize: 13, fontWeight: 600, color: C.text }}>{row.amount}</td>
                  <td style={{ padding: "10px 0" }}><StatusChip variant={row.status} /></td>
                  <td style={{ padding: "10px 0", fontSize: 11, color: C.textMuted }}>{row.time}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </Card>

        <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
          <Card>
            <div style={{ fontWeight: 700, fontSize: 14, marginBottom: 14, color: C.text }}>Low Stock Alerts</div>
            {LOW_STOCK.map((item, i) => (
              <div key={i} style={{
                display: "flex", alignItems: "center", justifyContent: "space-between",
                padding: "10px 0", borderTop: i > 0 ? `1px solid ${C.border}` : "none",
              }}>
                <div>
                  <div style={{ fontSize: 13, fontWeight: 500, color: C.text }}>{item.name}</div>
                  <div style={{ fontSize: 11, color: C.textMuted, fontFamily: "JetBrains Mono, monospace" }}>{item.sku}</div>
                </div>
                <div style={{ textAlign: "right" }}>
                  <div style={{
                    fontSize: 15, fontWeight: 700,
                    color: item.stock <= 3 ? C.error : C.amber,
                  }}>{item.stock} {item.unit}</div>
                  <div style={{ fontSize: 11, color: C.textMuted }}>min {item.reorder}</div>
                </div>
              </div>
            ))}
          </Card>

          <Card>
            <div style={{ fontWeight: 700, fontSize: 14, marginBottom: 14, color: C.text }}>Quick Actions</div>
            <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
              {[
                { label: "New Sales Invoice", icon: "🧾" },
                { label: "New Quotation", icon: "📋" },
                { label: "Record Purchase", icon: "🛒" },
                { label: "Adjust Stock", icon: "🏗" },
              ].map(({ label, icon }) => (
                <button key={label} style={{
                  display: "flex", alignItems: "center", gap: 10,
                  padding: "9px 12px", borderRadius: 8, border: `1px solid ${C.border}`,
                  background: "none", cursor: "pointer", fontSize: 13, color: C.text,
                  fontFamily: "inherit", textAlign: "left", transition: "background 0.1s",
                }}
                  onMouseEnter={e => (e.currentTarget.style.background = C.primaryLight)}
                  onMouseLeave={e => (e.currentTarget.style.background = "none")}
                >
                  <span>{icon}</span> {label}
                </button>
              ))}
            </div>
          </Card>
        </div>
      </div>
    </div>
  );
}

// ── Items Screen ───────────────────────────────────────────────────────────────
const ITEMS_DATA = [
  { name: "Basmati Rice 5kg", sku: "SKU-0023", unit: "bag", kind: "Stock", stock: 4, price: 420, tax: 5 },
  { name: "Saffola Gold Oil 1L", sku: "SKU-0047", unit: "bottle", kind: "Stock", stock: 2, price: 185, tax: 5 },
  { name: "Toor Dal 1kg", sku: "SKU-0061", unit: "kg", kind: "Stock", stock: 7, price: 120, tax: 5 },
  { name: "Packing Charges", sku: "SKU-0088", unit: "pcs", kind: "Non-Stock", stock: 0, price: 25, tax: 18 },
  { name: "Aashirvaad Atta 10kg", sku: "SKU-0012", unit: "bag", kind: "Stock", stock: 42, price: 460, tax: 5 },
  { name: "Amul Butter 500g", sku: "SKU-0031", unit: "pcs", kind: "Stock", stock: 18, price: 275, tax: 12 },
  { name: "Fortune Sunflower Oil 5L", sku: "SKU-0019", unit: "can", kind: "Stock", stock: 11, price: 750, tax: 5 },
  { name: "Nescafe Classic 200g", sku: "SKU-0054", unit: "jar", kind: "Stock", stock: 9, price: 450, tax: 18 },
];

function ItemsScreen() {
  const [search, setSearch] = useState("");
  const [showAdd, setShowAdd] = useState(false);
  const [form, setForm] = useState({
    sku: "", name: "", hsn: "", unit: "pcs", kind: "Stock",
    purchasePrice: "", sellingPrice: "", taxRate: "", batchTracked: false,
  });
  const [errors, setErrors] = useState<Record<string, string>>({});

  const filtered = ITEMS_DATA.filter(i =>
    i.name.toLowerCase().includes(search.toLowerCase()) ||
    i.sku.toLowerCase().includes(search.toLowerCase())
  );

  function validate() {
    const e: Record<string, string> = {};
    if (!form.sku.trim()) e.sku = "SKU is required";
    if (!form.name.trim()) e.name = "Name is required";
    if (!form.sellingPrice.trim()) e.sellingPrice = "Selling price is required";
    setErrors(e);
    return Object.keys(e).length === 0;
  }

  function handleSave() {
    if (validate()) setShowAdd(false);
  }

  return (
    <>
      <PageHeader title="Items">
        <SearchBar placeholder="Search by name or SKU…" value={search} onChange={setSearch} />
        <IconBtn title="Refresh"><span>🔄</span> Refresh</IconBtn>
        <IconBtn title="Filter"><span>▼</span> Filter</IconBtn>
      </PageHeader>

      <div style={{ padding: "0 28px" }}>
        <Card style={{ padding: 0 }}>
          <table style={{ width: "100%", borderCollapse: "collapse" }}>
            <thead>
              <tr style={{ background: "#F8F9FF" }}>
                {["SKU", "Name", "Unit", "Kind", "Stock", "Selling Price", "Tax %"].map(h => (
                  <th key={h} style={{
                    textAlign: "left", fontSize: 11, fontWeight: 600, color: C.textMuted,
                    padding: "12px 16px", textTransform: "uppercase", letterSpacing: "0.06em",
                    borderBottom: `1px solid ${C.border}`,
                  }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filtered.map((item, i) => {
                const lowStock = item.kind === "Stock" && item.stock < 10;
                return (
                  <tr key={i} style={{ borderBottom: `1px solid ${C.border}`, cursor: "pointer" }}
                    onMouseEnter={e => (e.currentTarget.style.background = "#F8F9FF")}
                    onMouseLeave={e => (e.currentTarget.style.background = "none")}
                  >
                    <td style={{ padding: "12px 16px", fontFamily: "JetBrains Mono, monospace", fontSize: 12, color: C.primaryDark }}>{item.sku}</td>
                    <td style={{ padding: "12px 16px", fontSize: 13, fontWeight: 500, color: C.text }}>{item.name}</td>
                    <td style={{ padding: "12px 16px", fontSize: 13, color: C.textSec }}>{item.unit}</td>
                    <td style={{ padding: "12px 16px" }}>
                      <span style={{
                        fontSize: 11, fontWeight: 600, padding: "2px 8px", borderRadius: 100,
                        background: item.kind === "Stock" ? C.primaryLight : "#F3F4F6",
                        color: item.kind === "Stock" ? C.primaryDark : "#6B7280",
                      }}>{item.kind}</span>
                    </td>
                    <td style={{ padding: "12px 16px", fontSize: 13, fontWeight: 600, color: lowStock ? C.error : C.text }}>
                      {item.kind === "Non-Stock" ? "—" : item.stock}
                      {lowStock && <span style={{ fontSize: 10, color: C.error, marginLeft: 4 }}>⚠ Low</span>}
                    </td>
                    <td style={{ padding: "12px 16px", fontSize: 13, fontFamily: "JetBrains Mono, monospace", color: C.text }}>₹{item.price.toLocaleString()}</td>
                    <td style={{ padding: "12px 16px", fontSize: 13, color: C.textSec }}>{item.tax}%</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
          <div style={{ padding: "12px 16px", borderTop: `1px solid ${C.border}`, fontSize: 12, color: C.textMuted }}>
            Showing {filtered.length} of {ITEMS_DATA.length} items
          </div>
        </Card>
      </div>

      <FAB onClick={() => { setForm({ sku: "", name: "", hsn: "", unit: "pcs", kind: "Stock", purchasePrice: "", sellingPrice: "", taxRate: "", batchTracked: false }); setErrors({}); setShowAdd(true); }} />

      <Modal open={showAdd} title="Add New Item" onClose={() => setShowAdd(false)} onSave={handleSave} maxWidth={460}>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "0 16px" }}>
          <FormField label="SKU" required error={errors.sku}>
            <TextInput value={form.sku} onChange={v => setForm(f => ({ ...f, sku: v }))} placeholder="e.g. SKU-0089" />
          </FormField>
          <FormField label="HSN / SAC Code">
            <TextInput value={form.hsn} onChange={v => setForm(f => ({ ...f, hsn: v }))} placeholder="e.g. 1006" />
          </FormField>
        </div>
        <FormField label="Item Name" required error={errors.name}>
          <TextInput value={form.name} onChange={v => setForm(f => ({ ...f, name: v }))} placeholder="Full product name" />
        </FormField>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "0 16px" }}>
          <FormField label="Unit">
            <Select value={form.unit} onChange={v => setForm(f => ({ ...f, unit: v }))} options={[
              { value: "pcs", label: "Pieces (pcs)" },
              { value: "kg", label: "Kilogram (kg)" },
              { value: "g", label: "Gram (g)" },
              { value: "ltr", label: "Litre (ltr)" },
              { value: "ml", label: "Millilitre (ml)" },
              { value: "box", label: "Box" },
              { value: "dozen", label: "Dozen" },
              { value: "meter", label: "Meter" },
              { value: "pair", label: "Pair" },
              { value: "set", label: "Set" },
            ]} />
          </FormField>
          <FormField label="Kind">
            <Select value={form.kind} onChange={v => setForm(f => ({ ...f, kind: v }))} options={[
              { value: "Stock", label: "Stock" },
              { value: "Non-Stock", label: "Non-Stock" },
            ]} />
          </FormField>
        </div>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: "0 12px" }}>
          <FormField label="Purchase Price (₹)">
            <TextInput value={form.purchasePrice} onChange={v => setForm(f => ({ ...f, purchasePrice: v }))} placeholder="0.00" type="number" />
          </FormField>
          <FormField label="Selling Price (₹)" required error={errors.sellingPrice}>
            <TextInput value={form.sellingPrice} onChange={v => setForm(f => ({ ...f, sellingPrice: v }))} placeholder="0.00" type="number" />
          </FormField>
          <FormField label="Tax Rate (%)">
            <TextInput value={form.taxRate} onChange={v => setForm(f => ({ ...f, taxRate: v }))} placeholder="e.g. 5" type="number" />
          </FormField>
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 10, marginTop: 4 }}>
          <input
            type="checkbox" id="batchTracked"
            checked={form.batchTracked}
            onChange={e => setForm(f => ({ ...f, batchTracked: e.target.checked }))}
            style={{ accentColor: C.primary, width: 16, height: 16, cursor: "pointer" }}
          />
          <label htmlFor="batchTracked" style={{ fontSize: 13, color: C.textSec, cursor: "pointer" }}>
            Batch-tracked item
          </label>
        </div>
      </Modal>
    </>
  );
}

// ── Quotations Screen ──────────────────────────────────────────────────────────
const QUOTATIONS_DATA = [
  { doc: "QUO-2024-0218", customer: "Nisha General Store", date: "22 Aug 2024", total: "₹8,200", status: "issued" as StatusChipVariant },
  { doc: "QUO-2024-0217", customer: "Patel Kirana", date: "21 Aug 2024", total: "₹3,450", status: "converted" as StatusChipVariant },
  { doc: "QUO-2024-0216", customer: "Ravi Enterprises", date: "20 Aug 2024", total: "₹18,750", status: "draft" as StatusChipVariant },
  { doc: "QUO-2024-0215", customer: "Sunita Shops", date: "19 Aug 2024", total: "₹6,100", status: "cancelled" as StatusChipVariant },
  { doc: "QUO-2024-0214", customer: "Arjun Wholesale", date: "18 Aug 2024", total: "₹22,400", status: "issued" as StatusChipVariant },
];

const QUOTE_LINES = [
  { name: "Basmati Rice 5kg", qty: 10, unit: "bag", rate: 420, taxPct: 5, hsn: "1006" },
  { name: "Toor Dal 1kg", qty: 20, unit: "kg", rate: 120, taxPct: 5, hsn: "0713" },
  { name: "Aashirvaad Atta 10kg", qty: 5, unit: "bag", rate: 460, taxPct: 5, hsn: "1101" },
];

function QuotationsScreen() {
  const [search, setSearch] = useState("");
  const [selected, setSelected] = useState<typeof QUOTATIONS_DATA[0] | null>(null);
  const [showConvertConfirm, setShowConvertConfirm] = useState(false);

  const filtered = QUOTATIONS_DATA.filter(q =>
    q.customer.toLowerCase().includes(search.toLowerCase()) ||
    q.doc.toLowerCase().includes(search.toLowerCase())
  );

  const subtotal = QUOTE_LINES.reduce((s, l) => s + l.qty * l.rate, 0);
  const cgst = QUOTE_LINES.reduce((s, l) => s + l.qty * l.rate * l.taxPct / 200, 0);
  const sgst = cgst;
  const total = subtotal + cgst + sgst;

  return (
    <>
      <PageHeader title="Quotations">
        <SearchBar placeholder="Search quotations…" value={search} onChange={setSearch} />
        <IconBtn title="Refresh"><span>🔄</span> Refresh</IconBtn>
        <IconBtn title="Filter"><span>▼</span> Status</IconBtn>
      </PageHeader>

      <div style={{ padding: "0 28px", display: "grid", gridTemplateColumns: selected ? "1fr 1.2fr" : "1fr", gap: 20 }}>
        <Card style={{ padding: 0 }}>
          <table style={{ width: "100%", borderCollapse: "collapse" }}>
            <thead>
              <tr style={{ background: "#F8F9FF" }}>
                {["Doc No.", "Customer", "Date", "Total", "Status"].map(h => (
                  <th key={h} style={{
                    textAlign: "left", fontSize: 11, fontWeight: 600, color: C.textMuted,
                    padding: "12px 16px", textTransform: "uppercase", letterSpacing: "0.06em",
                    borderBottom: `1px solid ${C.border}`,
                  }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filtered.map((row, i) => (
                <tr
                  key={i}
                  onClick={() => setSelected(selected?.doc === row.doc ? null : row)}
                  style={{
                    borderBottom: `1px solid ${C.border}`, cursor: "pointer",
                    background: selected?.doc === row.doc ? C.primaryLight : "none",
                  }}
                  onMouseEnter={e => { if (selected?.doc !== row.doc) e.currentTarget.style.background = "#F8F9FF"; }}
                  onMouseLeave={e => { if (selected?.doc !== row.doc) e.currentTarget.style.background = "none"; }}
                >
                  <td style={{ padding: "12px 16px", fontFamily: "JetBrains Mono, monospace", fontSize: 12, color: C.primaryDark, fontWeight: 500 }}>{row.doc}</td>
                  <td style={{ padding: "12px 16px", fontSize: 13, color: C.text }}>{row.customer}</td>
                  <td style={{ padding: "12px 16px", fontSize: 12, color: C.textSec }}>{row.date}</td>
                  <td style={{ padding: "12px 16px", fontSize: 13, fontWeight: 600, fontFamily: "JetBrains Mono, monospace" }}>{row.total}</td>
                  <td style={{ padding: "12px 16px" }}><StatusChip variant={row.status} /></td>
                </tr>
              ))}
            </tbody>
          </table>
        </Card>

        {selected && (
          <Card>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 16 }}>
              <div>
                <div style={{ fontFamily: "JetBrains Mono, monospace", fontSize: 14, fontWeight: 700, color: C.primaryDark }}>{selected.doc}</div>
                <div style={{ fontSize: 13, color: C.textSec, marginTop: 2 }}>{selected.customer} · {selected.date}</div>
              </div>
              <StatusChip variant={selected.status} />
            </div>

            <table style={{ width: "100%", borderCollapse: "collapse", marginBottom: 16 }}>
              <thead>
                <tr style={{ borderBottom: `2px solid ${C.border}` }}>
                  {["Item", "HSN", "Qty", "Rate", "Amount"].map(h => (
                    <th key={h} style={{ textAlign: "left", fontSize: 11, fontWeight: 600, color: C.textMuted, padding: "6px 8px 10px", textTransform: "uppercase", letterSpacing: "0.06em" }}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {QUOTE_LINES.map((line, i) => (
                  <tr key={i} style={{ borderBottom: `1px solid ${C.border}` }}>
                    <td style={{ padding: "9px 8px", fontSize: 12, color: C.text }}>{line.name}</td>
                    <td style={{ padding: "9px 8px", fontSize: 11, color: C.textMuted, fontFamily: "JetBrains Mono, monospace" }}>{line.hsn}</td>
                    <td style={{ padding: "9px 8px", fontSize: 12 }}>{line.qty} {line.unit}</td>
                    <td style={{ padding: "9px 8px", fontSize: 12, fontFamily: "JetBrains Mono, monospace" }}>₹{line.rate}</td>
                    <td style={{ padding: "9px 8px", fontSize: 12, fontWeight: 600, fontFamily: "JetBrains Mono, monospace" }}>₹{(line.qty * line.rate).toLocaleString()}</td>
                  </tr>
                ))}
              </tbody>
            </table>

            <div style={{ background: "#F8F9FF", borderRadius: 8, padding: "12px 14px", marginBottom: 16 }}>
              {[
                ["Subtotal", `₹${subtotal.toLocaleString()}`],
                ["CGST", `₹${cgst.toFixed(2)}`],
                ["SGST", `₹${sgst.toFixed(2)}`],
              ].map(([label, val]) => (
                <div key={label} style={{ display: "flex", justifyContent: "space-between", fontSize: 12, marginBottom: 6, color: C.textSec }}>
                  <span>{label}</span><span style={{ fontFamily: "JetBrains Mono, monospace" }}>{val}</span>
                </div>
              ))}
              <div style={{ display: "flex", justifyContent: "space-between", fontSize: 14, fontWeight: 700, color: C.text, borderTop: `1px solid ${C.border}`, paddingTop: 8, marginTop: 4 }}>
                <span>Total</span><span style={{ fontFamily: "JetBrains Mono, monospace" }}>₹{total.toLocaleString()}</span>
              </div>
            </div>

            <div style={{ display: "flex", gap: 8, justifyContent: "flex-end", flexWrap: "wrap" }}>
              <IconBtn title="View PDF">👁 View PDF</IconBtn>
              <IconBtn title="Print">🖨 Print</IconBtn>
              <IconBtn title="Send via WhatsApp">💬 WhatsApp</IconBtn>
              {selected.status === "issued" && (
                <button
                  onClick={() => setShowConvertConfirm(true)}
                  style={{
                    padding: "7px 14px", borderRadius: 8, border: "none",
                    background: C.success, color: "#fff", cursor: "pointer",
                    fontSize: 13, fontWeight: 600, fontFamily: "inherit",
                  }}
                >↗ Convert to Invoice</button>
              )}
            </div>
          </Card>
        )}
      </div>

      <FAB onClick={() => {}} />

      <Modal open={showConvertConfirm} title="Convert to Sales Invoice" onClose={() => setShowConvertConfirm(false)} onSave={() => setShowConvertConfirm(false)} saveLabel="Convert">
        <div style={{ display: "flex", gap: 12, padding: "4px 0 8px" }}>
          <div style={{ fontSize: 32 }}>↗</div>
          <div>
            <div style={{ fontWeight: 600, fontSize: 14, color: C.text, marginBottom: 6 }}>
              Convert {selected?.doc} to Sales Invoice?
            </div>
            <div style={{ fontSize: 13, color: C.textSec, lineHeight: 1.5 }}>
              A new Sales Invoice will be created for <strong>{selected?.customer}</strong> with the same line items. The quotation status will be updated to "Converted."
            </div>
          </div>
        </div>
      </Modal>
    </>
  );
}

// ── Purchases Screen ───────────────────────────────────────────────────────────
const PO_DATA = [
  { doc: "PO-2024-0091", supplier: "Agro Supplies Ltd", date: "22 Aug 2024", total: "₹32,000", status: "received" as StatusChipVariant, items: 8 },
  { doc: "PO-2024-0090", supplier: "Metro Distributors", date: "20 Aug 2024", total: "₹18,500", status: "pending" as StatusChipVariant, items: 5 },
  { doc: "PO-2024-0089", supplier: "Sunrise Foods", date: "18 Aug 2024", total: "₹44,200", status: "issued" as StatusChipVariant, items: 12 },
  { doc: "PO-2024-0088", supplier: "Agro Supplies Ltd", date: "15 Aug 2024", total: "₹9,750", status: "cancelled" as StatusChipVariant, items: 3 },
];

const SUPPLIERS_DATA = [
  { name: "Agro Supplies Ltd", code: "SUP-001", gstin: "27AABCU9603R1ZM", contact: "Suresh Kumar · +91 98210 34567", outstanding: "₹32,000" },
  { name: "Metro Distributors", code: "SUP-002", gstin: "29AAKFU6789R1ZP", contact: "Meena Patel · +91 87009 12345", outstanding: "₹18,500" },
  { name: "Sunrise Foods", code: "SUP-003", gstin: "06AAECS1234Q1ZX", contact: "Ramesh Iyer · +91 99870 00123", outstanding: "₹44,200" },
  { name: "Golden Grains Inc.", code: "SUP-004", gstin: "33AABFG5678P1ZQ", contact: "Priya Sharma · +91 80001 56789", outstanding: "₹0" },
];

function PurchasesScreen() {
  const [tab, setTab] = useState("Purchase Orders");
  const [expanded, setExpanded] = useState<string | null>(null);

  return (
    <>
      <PageHeader title="Purchases">
        <IconBtn title="Refresh"><span>🔄</span> Refresh</IconBtn>
        <IconBtn title="Filter"><span>▼</span> Filter</IconBtn>
      </PageHeader>

      <div style={{ padding: "0 28px" }}>
        <Tabs tabs={["Purchase Orders", "Suppliers"]} active={tab} onChange={setTab} />

        {tab === "Purchase Orders" && (
          <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
            {PO_DATA.map(po => (
              <Card key={po.doc} style={{ padding: 0 }}>
                <div
                  style={{
                    padding: "14px 18px", display: "flex", alignItems: "center",
                    justifyContent: "space-between", cursor: "pointer",
                    borderBottom: expanded === po.doc ? `1px solid ${C.border}` : "none",
                  }}
                  onClick={() => setExpanded(expanded === po.doc ? null : po.doc)}
                >
                  <div style={{ display: "flex", alignItems: "center", gap: 16 }}>
                    <span style={{ fontFamily: "JetBrains Mono, monospace", fontSize: 13, fontWeight: 600, color: C.primaryDark }}>{po.doc}</span>
                    <span style={{ fontSize: 13, color: C.text }}>{po.supplier}</span>
                    <span style={{ fontSize: 12, color: C.textMuted }}>{po.date}</span>
                    <span style={{ fontSize: 11, color: C.textMuted }}>{po.items} items</span>
                  </div>
                  <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
                    <span style={{ fontFamily: "JetBrains Mono, monospace", fontSize: 13, fontWeight: 700 }}>{po.total}</span>
                    <StatusChip variant={po.status} />
                    <span style={{ color: C.textMuted, fontSize: 12 }}>{expanded === po.doc ? "▲" : "▼"}</span>
                  </div>
                </div>

                {expanded === po.doc && (
                  <div style={{ padding: "14px 18px" }}>
                    <div style={{ fontSize: 12, color: C.textMuted, marginBottom: 12 }}>
                      Supplier: <strong style={{ color: C.text }}>{po.supplier}</strong> &nbsp;·&nbsp; {po.date}
                    </div>
                    <div style={{ background: "#F8F9FF", borderRadius: 8, padding: "10px 14px", marginBottom: 14, fontSize: 13, color: C.textSec }}>
                      Line items preview — expand full order to see details
                    </div>
                    <div style={{ display: "flex", gap: 8, justifyContent: "flex-end" }}>
                      {po.status === "pending" && (
                        <button style={{
                          padding: "7px 14px", borderRadius: 8, border: "none",
                          background: C.primary, color: "#fff", cursor: "pointer",
                          fontSize: 12, fontWeight: 600, fontFamily: "inherit",
                        }}>✓ Submit</button>
                      )}
                      {po.status === "issued" && (
                        <button style={{
                          padding: "7px 14px", borderRadius: 8, border: "none",
                          background: C.success, color: "#fff", cursor: "pointer",
                          fontSize: 12, fontWeight: 600, fontFamily: "inherit",
                        }}>📦 Receive Goods</button>
                      )}
                      {(po.status === "pending" || po.status === "issued") && (
                        <button style={{
                          padding: "7px 14px", borderRadius: 8,
                          border: `1px solid ${C.error}`, background: "none",
                          color: C.error, cursor: "pointer", fontSize: 12, fontFamily: "inherit",
                        }}>✕ Cancel</button>
                      )}
                      {po.status === "received" && (
                        <button style={{
                          padding: "7px 14px", borderRadius: 8, border: `1px solid ${C.border}`,
                          background: "none", color: C.textSec, cursor: "pointer",
                          fontSize: 12, fontFamily: "inherit",
                        }}>💳 Add Payment</button>
                      )}
                      <IconBtn title="View PDF">👁 View PDF</IconBtn>
                      <IconBtn title="Print">🖨 Print</IconBtn>
                    </div>
                  </div>
                )}
              </Card>
            ))}
          </div>
        )}

        {tab === "Suppliers" && (
          <Card style={{ padding: 0 }}>
            <table style={{ width: "100%", borderCollapse: "collapse" }}>
              <thead>
                <tr style={{ background: "#F8F9FF" }}>
                  {["Code", "Supplier Name", "GSTIN", "Contact", "Outstanding"].map(h => (
                    <th key={h} style={{
                      textAlign: "left", fontSize: 11, fontWeight: 600, color: C.textMuted,
                      padding: "12px 16px", textTransform: "uppercase", letterSpacing: "0.06em",
                      borderBottom: `1px solid ${C.border}`,
                    }}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {SUPPLIERS_DATA.map((s, i) => (
                  <tr key={i} style={{ borderBottom: `1px solid ${C.border}`, cursor: "pointer" }}
                    onMouseEnter={e => (e.currentTarget.style.background = "#F8F9FF")}
                    onMouseLeave={e => (e.currentTarget.style.background = "none")}
                  >
                    <td style={{ padding: "12px 16px", fontFamily: "JetBrains Mono, monospace", fontSize: 12, color: C.primaryDark }}>{s.code}</td>
                    <td style={{ padding: "12px 16px", fontSize: 13, fontWeight: 500, color: C.text }}>{s.name}</td>
                    <td style={{ padding: "12px 16px", fontFamily: "JetBrains Mono, monospace", fontSize: 11, color: C.textSec }}>{s.gstin}</td>
                    <td style={{ padding: "12px 16px", fontSize: 12, color: C.textSec }}>{s.contact}</td>
                    <td style={{ padding: "12px 16px", fontSize: 13, fontWeight: 600, fontFamily: "JetBrains Mono, monospace", color: s.outstanding === "₹0" ? C.textMuted : C.error }}>{s.outstanding}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </Card>
        )}
      </div>

      <FAB onClick={() => {}} />
    </>
  );
}

// ── WhatsApp Screen ────────────────────────────────────────────────────────────
function WhatsAppScreen() {
  const [connected, setConnected] = useState(false);

  return (
    <div style={{ padding: "0 28px 32px" }}>
      <PageHeader title="WhatsApp Integration" />
      <div style={{ maxWidth: 560, margin: "0 auto" }}>
        <Card>
          <div style={{ textAlign: "center", padding: "8px 0 16px" }}>
            <div style={{ fontSize: 32, marginBottom: 10 }}>💬</div>
            <div style={{ fontWeight: 700, fontSize: 18, color: C.text, marginBottom: 6 }}>
              {connected ? "WhatsApp Connected" : "Connect WhatsApp"}
            </div>
            <div style={{ fontSize: 13, color: C.textSec, lineHeight: 1.6, maxWidth: 360, margin: "0 auto 24px" }}>
              {connected
                ? "Your shop's WhatsApp is paired and ready. You can send invoices, quotations, and payment reminders directly from this app."
                : "Scan the QR code below with WhatsApp on your phone to pair this app. Open WhatsApp → Linked Devices → Link a Device."}
            </div>

            {!connected ? (
              <>
                <div style={{
                  width: 224, height: 224, margin: "0 auto 24px",
                  borderRadius: 12, border: `2px solid ${C.border}`,
                  display: "flex", alignItems: "center", justifyContent: "center",
                  background: "#fff", padding: 12,
                  boxShadow: "0 2px 12px rgba(0,0,0,0.08)",
                }}>
                  {/* QR Code rendered as SVG grid */}
                  <svg width="200" height="200" viewBox="0 0 200 200">
                    {Array.from({ length: 25 }, (_, row) =>
                      Array.from({ length: 25 }, (_, col) => {
                        const isCorner =
                          (row < 7 && col < 7) || (row < 7 && col >= 18) || (row >= 18 && col < 7);
                        const seed = (row * 31 + col * 17 + row * col) % 3;
                        const filled = isCorner || seed === 0;
                        return filled ? (
                          <rect key={`${row}-${col}`} x={col * 8} y={row * 8} width={7} height={7}
                            rx={1} fill="#1A1A2E" />
                        ) : null;
                      })
                    )}
                    {/* Corner squares */}
                    {[[0, 0], [0, 18], [18, 0]].map(([r, c]) => (
                      <g key={`corner-${r}-${c}`}>
                        <rect x={c * 8} y={r * 8} width={55} height={55} rx={4} fill="#1A1A2E" />
                        <rect x={c * 8 + 8} y={r * 8 + 8} width={39} height={39} rx={2} fill="#fff" />
                        <rect x={c * 8 + 16} y={r * 8 + 16} width={23} height={23} rx={1} fill="#1A1A2E" />
                      </g>
                    ))}
                  </svg>
                </div>
                <div style={{ fontSize: 12, color: C.textMuted, marginBottom: 20 }}>
                  QR code refreshes in <strong style={{ color: C.text }}>2:34</strong>
                </div>
                <button
                  onClick={() => setConnected(true)}
                  style={{
                    padding: "9px 20px", borderRadius: 8, border: `1px solid ${C.border}`,
                    background: "none", cursor: "pointer", fontSize: 13, fontFamily: "inherit",
                    color: C.textSec,
                  }}
                >↻ Regenerate QR</button>
              </>
            ) : (
              <>
                <div style={{
                  display: "inline-flex", alignItems: "center", gap: 10,
                  background: C.successLight, color: C.successText,
                  padding: "12px 24px", borderRadius: 100, marginBottom: 28,
                  fontWeight: 600, fontSize: 14,
                }}>
                  <span style={{ width: 10, height: 10, borderRadius: "50%", background: C.success, display: "inline-block" }} />
                  Connected: +91 98210 55567
                </div>

                <div style={{ background: "#F8F9FF", borderRadius: 10, padding: "16px 20px", textAlign: "left", marginBottom: 24 }}>
                  <div style={{ fontWeight: 600, fontSize: 13, marginBottom: 10, color: C.text }}>Send documents via WhatsApp</div>
                  {["Sales Invoices", "Quotations", "Payment Reminders", "Proforma Invoices"].map(t => (
                    <div key={t} style={{
                      display: "flex", alignItems: "center", gap: 8,
                      fontSize: 13, color: C.textSec, marginBottom: 6,
                    }}>
                      <span style={{ color: C.success }}>✓</span> {t}
                    </div>
                  ))}
                </div>

                <button
                  onClick={() => setConnected(false)}
                  style={{
                    padding: "9px 20px", borderRadius: 8,
                    border: `1px solid ${C.error}`, background: "none",
                    cursor: "pointer", fontSize: 13, fontFamily: "inherit", color: C.error,
                  }}
                >⊗ Unlink Device</button>
              </>
            )}
          </div>
        </Card>

        <Card style={{ marginTop: 16 }}>
          <div style={{ fontWeight: 700, fontSize: 13, marginBottom: 12, color: C.text }}>Recent Messages Sent</div>
          {[
            { to: "Nisha General Store", doc: "INV-2024-0382", time: "22 Aug, 10:14 AM", status: "delivered" },
            { to: "Ravi Enterprises", doc: "QUO-2024-0218", time: "22 Aug, 9:40 AM", status: "read" },
            { to: "Krishna Traders", doc: "INV-2024-0380", time: "21 Aug, 6:02 PM", status: "delivered" },
          ].map((msg, i) => (
            <div key={i} style={{
              display: "flex", justifyContent: "space-between", alignItems: "center",
              padding: "10px 0", borderTop: i > 0 ? `1px solid ${C.border}` : "none",
            }}>
              <div>
                <div style={{ fontSize: 13, fontWeight: 500, color: C.text }}>{msg.to}</div>
                <div style={{ fontSize: 11, color: C.textMuted, fontFamily: "JetBrains Mono, monospace" }}>{msg.doc} · {msg.time}</div>
              </div>
              <span style={{
                fontSize: 11, fontWeight: 600, padding: "2px 8px", borderRadius: 100,
                background: msg.status === "read" ? C.successLight : C.primaryLight,
                color: msg.status === "read" ? C.successText : C.primaryDark,
                textTransform: "uppercase", letterSpacing: "0.04em",
              }}>{msg.status}</span>
            </div>
          ))}
        </Card>
      </div>
    </div>
  );
}

// ── Stub Screens ───────────────────────────────────────────────────────────────
function StubScreen({ title, icon, description }: { title: string; icon: string; description: string }) {
  return (
    <>
      <PageHeader title={title}>
        <IconBtn title="Refresh"><span>🔄</span> Refresh</IconBtn>
      </PageHeader>
      <div style={{ padding: "0 28px" }}>
        <Card style={{ textAlign: "center", padding: "60px 32px" }}>
          <div style={{ fontSize: 48, marginBottom: 16 }}>{icon}</div>
          <div style={{ fontSize: 16, fontWeight: 600, color: C.text, marginBottom: 8 }}>{title}</div>
          <div style={{ fontSize: 13, color: C.textSec, maxWidth: 360, margin: "0 auto", lineHeight: 1.6 }}>{description}</div>
        </Card>
      </div>
      <FAB onClick={() => {}} />
    </>
  );
}

// ── App Root ───────────────────────────────────────────────────────────────────
export default function App() {
  const [screen, setScreen] = useState<Screen>("dashboard");
  const [showShortcuts, setShowShortcuts] = useState(false);
  const [showConnBanner] = useState(false);

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key === "F1") { e.preventDefault(); setShowShortcuts(s => !s); }
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  function renderScreen() {
    switch (screen) {
      case "dashboard":      return <DashboardScreen />;
      case "items":          return <ItemsScreen />;
      case "quotations":     return <QuotationsScreen />;
      case "purchases":      return <PurchasesScreen />;
      case "whatsapp":       return <WhatsAppScreen />;
      case "customers":      return <StubScreen title="Customers" icon="👥" description="Manage your customer list, GST details, deposits, and order history. Use the + button to add a new customer." />;
      case "proformas":      return <StubScreen title="Proformas" icon="📄" description="Create and manage proforma invoices. Convert them to Sales Invoices when confirmed." />;
      case "sales-invoices": return <StubScreen title="Sales Invoices" icon="🧾" description="All sales invoices with GST breakdown, payment status, and PDF/WhatsApp actions." />;
      case "deposits":       return <StubScreen title="Deposits" icon="💰" description="Customer advance deposits and running balance ledger. Record new deposits with the + button." />;
      case "stock":          return <StubScreen title="Stock" icon="🏗" description="Current stock levels per item. Manually adjust quantities with a mandatory reason for audit trail." />;
      case "returns":        return <StubScreen title="Returns" icon="↩️" description="Sales and purchase returns management. Linked back to original documents." />;
      case "finance":        return <StubScreen title="Finance" icon="📊" description="General ledger, transaction history, and running balance. Credit entries in green, debit in red." />;
      case "users":          return <StubScreen title="Users & Roles" icon="🔐" description="Manage staff user accounts, assign roles, and configure module-level permissions per role." />;
      case "reports":        return <StubScreen title="Reports" icon="📈" description="Sales, purchase, stock, and financial reports with date-range filters and CSV/PDF export." />;
      case "settings":       return <StubScreen title="Shop Settings" icon="⚙️" description="Configure shop name, GSTIN, address, invoice prefix, and other system-wide settings." />;
      default:               return <DashboardScreen />;
    }
  }

  return (
    <div style={{ display: "flex", height: "100vh", background: C.surface, overflow: "hidden" }}>
      <Sidebar active={screen} onNavigate={setScreen} onShortcuts={() => setShowShortcuts(true)} />

      <main style={{ flex: 1, display: "flex", flexDirection: "column", overflow: "hidden" }}>
        <ConnBanner show={showConnBanner} />
        <div style={{ flex: 1, overflowY: "auto", paddingBottom: 80, paddingTop: 8 }}>
          {renderScreen()}
        </div>
      </main>

      {showShortcuts && <ShortcutsOverlay onClose={() => setShowShortcuts(false)} />}
    </div>
  );
}
