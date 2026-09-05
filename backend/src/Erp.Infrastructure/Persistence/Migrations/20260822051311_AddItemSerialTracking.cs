using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Erp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddItemSerialTracking : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "SerialId",
                table: "stock_movements",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsSerialTracked",
                table: "items",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateTable(
                name: "item_serials",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ItemId = table.Column<Guid>(type: "uuid", nullable: false),
                    SerialNumber = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    IsSold = table.Column<bool>(type: "boolean", nullable: false),
                    ReceivedDate = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    PurchaseReceiptLineId = table.Column<Guid>(type: "uuid", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_item_serials", x => x.Id);
                    table.ForeignKey(
                        name: "FK_item_serials_items_ItemId",
                        column: x => x.ItemId,
                        principalTable: "items",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_stock_movements_SerialId",
                table: "stock_movements",
                column: "SerialId");

            migrationBuilder.CreateIndex(
                name: "IX_item_serials_ItemId_SerialNumber",
                table: "item_serials",
                columns: new[] { "ItemId", "SerialNumber" },
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_stock_movements_item_serials_SerialId",
                table: "stock_movements",
                column: "SerialId",
                principalTable: "item_serials",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_stock_movements_item_serials_SerialId",
                table: "stock_movements");

            migrationBuilder.DropTable(
                name: "item_serials");

            migrationBuilder.DropIndex(
                name: "IX_stock_movements_SerialId",
                table: "stock_movements");

            migrationBuilder.DropColumn(
                name: "SerialId",
                table: "stock_movements");

            migrationBuilder.DropColumn(
                name: "IsSerialTracked",
                table: "items");
        }
    }
}
