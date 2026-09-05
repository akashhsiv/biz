using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Erp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddNotificationEngine : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "DueDate",
                table: "purchase_orders",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "MinimumStock",
                table: "items",
                type: "numeric(18,3)",
                precision: 18,
                scale: 3,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "notification_events",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ShopId = table.Column<Guid>(type: "uuid", nullable: false),
                    EventType = table.Column<int>(type: "integer", nullable: false),
                    PayloadJson = table.Column<string>(type: "text", nullable: false),
                    Status = table.Column<int>(type: "integer", nullable: false),
                    FailureReason = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    ReferenceType = table.Column<int>(type: "integer", nullable: true),
                    ReferenceId = table.Column<Guid>(type: "uuid", nullable: true),
                    DispatchedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedBy = table.Column<Guid>(type: "uuid", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedBy = table.Column<Guid>(type: "uuid", nullable: true),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_notification_events", x => x.Id);
                    table.ForeignKey(
                        name: "FK_notification_events_shops_ShopId",
                        column: x => x.ShopId,
                        principalTable: "shops",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "shop_notification_settings",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ShopId = table.Column<Guid>(type: "uuid", nullable: false),
                    LowStockWhatsapp = table.Column<bool>(type: "boolean", nullable: false),
                    LowStockMobile = table.Column<bool>(type: "boolean", nullable: false),
                    PurchaseDueWhatsapp = table.Column<bool>(type: "boolean", nullable: false),
                    PurchaseDueMobile = table.Column<bool>(type: "boolean", nullable: false),
                    PurchaseOverdueWhatsapp = table.Column<bool>(type: "boolean", nullable: false),
                    PurchaseOverdueMobile = table.Column<bool>(type: "boolean", nullable: false),
                    CustomerOutstandingWhatsapp = table.Column<bool>(type: "boolean", nullable: false),
                    CustomerOutstandingMobile = table.Column<bool>(type: "boolean", nullable: false),
                    CreatedBy = table.Column<Guid>(type: "uuid", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedBy = table.Column<Guid>(type: "uuid", nullable: true),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_shop_notification_settings", x => x.Id);
                    table.ForeignKey(
                        name: "FK_shop_notification_settings_shops_ShopId",
                        column: x => x.ShopId,
                        principalTable: "shops",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "mobile_push_outbox_items",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ShopId = table.Column<Guid>(type: "uuid", nullable: false),
                    NotificationEventId = table.Column<Guid>(type: "uuid", nullable: false),
                    RecipientDescription = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    PayloadJson = table.Column<string>(type: "text", nullable: false),
                    Status = table.Column<int>(type: "integer", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_mobile_push_outbox_items", x => x.Id);
                    table.ForeignKey(
                        name: "FK_mobile_push_outbox_items_notification_events_NotificationEv~",
                        column: x => x.NotificationEventId,
                        principalTable: "notification_events",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_mobile_push_outbox_items_shops_ShopId",
                        column: x => x.ShopId,
                        principalTable: "shops",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_mobile_push_outbox_items_NotificationEventId",
                table: "mobile_push_outbox_items",
                column: "NotificationEventId");

            migrationBuilder.CreateIndex(
                name: "IX_mobile_push_outbox_items_ShopId",
                table: "mobile_push_outbox_items",
                column: "ShopId");

            migrationBuilder.CreateIndex(
                name: "IX_mobile_push_outbox_items_Status",
                table: "mobile_push_outbox_items",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_notification_events_ReferenceType_ReferenceId",
                table: "notification_events",
                columns: new[] { "ReferenceType", "ReferenceId" });

            migrationBuilder.CreateIndex(
                name: "IX_notification_events_ShopId",
                table: "notification_events",
                column: "ShopId");

            migrationBuilder.CreateIndex(
                name: "IX_notification_events_Status_CreatedAt",
                table: "notification_events",
                columns: new[] { "Status", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_shop_notification_settings_ShopId",
                table: "shop_notification_settings",
                column: "ShopId",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "mobile_push_outbox_items");

            migrationBuilder.DropTable(
                name: "shop_notification_settings");

            migrationBuilder.DropTable(
                name: "notification_events");

            migrationBuilder.DropColumn(
                name: "DueDate",
                table: "purchase_orders");

            migrationBuilder.DropColumn(
                name: "MinimumStock",
                table: "items");
        }
    }
}
