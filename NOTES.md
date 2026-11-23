# BidNile — Technical Notes & Design Decisions

## 1. Schemas, Tables, and Separation Rationale

BidNile is organized into **4 core schemas** (plus `Marketing` introduced in Task 3.12) to enforce logical boundaries, security permissions, and maintainability:

- **`Account`** (`City`, `Member`, `Wallet`): Isolates user identity, authentication/profile metadata, geographic locations, and financial balances/holds from marketplace operations.
- **`Ops`** (`Warehouse`, `Employee`): Separates internal physical logistics, storage hubs, and staff/inspector assignments from public-facing user tables.
- **`Catalogue`** (`Category`, `Item`, `Photo`): Groups product taxonomy, item listings, JSON specifications, and media assets independently of live auction traffic.
- **`Sales`** (`Auction`, `Bid`, and `AuctionFollow` prior to Task 3.12): Handles high-throughput transactional bidding and auction lifecycle states.
- **`Marketing`** (`AuctionFollow` transferred from `Sales` in Task 3.12): Separates user engagement and watchlist tracking for the marketing team without granting access to financial or bidding tables.

---

## 2. Relationship Types in BidNile & Mapping Strategy

| Relationship Type | Where in BidNile | How It Was Mapped |
| :--- | :--- | :--- |
| **1:1** | `Account.Member` ↔ `Account.Wallet`<br>`Ops.Employee` manages `Ops.Warehouse` | **Shared Primary Key:** `Wallet.MemberId` is both `PK` and `FK` referencing `Member(MemberId)`.<br>**Unique Foreign Key:** `Warehouse.ManagerId` is a `UNIQUE` `FK` referencing `Employee(EmployeeId)` (1 manager per warehouse, at most 1 warehouse per manager). |
| **1:N** | `City` → `Member`, `Category` → `Item`, `Item` → `Auction`, `Auction` → `Bid` | Placed the parent's `PK` as a `FK` on the child ("many") table (e.g., `Member.CityId`, `Item.CategoryCode`, `Bid.AuctionId`). |
| **M:N** | `Account.Member` ↔ `Sales.Auction` (Follows) | Mapped to junction table `Marketing.AuctionFollow` with a composite `PK (MemberId, AuctionId)` and two `FK`s referencing `Member` and `Auction`. |
| **Recursive** | `Member` invites `Member`<br>`Category` parent of `Category` | Nullable self-referencing `FK` (`Member.InvitedByMemberId` → `Member.MemberId`, `Category.ParentCategoryCode` → `Category.CategoryCode`) plus a `CHECK` constraint preventing self-reference (`<>`). |
| **Circular** | `Ops.Warehouse` ↔ `Ops.Employee` | Every employee works in a warehouse (`Employee.WarehouseId` → `Warehouse.WarehouseId`) and every warehouse has a manager (`Warehouse.ManagerId` → `Employee.EmployeeId`). Created both tables first, then added both `FK`s via `ALTER TABLE`. |
| **Weak Entity** | `Catalogue.Photo` depends on `Catalogue.Item` | Mapped with a composite `PK (ItemId, Position)` where `ItemId` is both part of the `PK` and an `FK` referencing `Catalogue.Item(ItemId)` with `ON DELETE CASCADE`. |

---

## 3. Data Type Decisions

- **`GUID` (`UNIQUEIDENTIFIER`) for `Member`:** Guarantees global uniqueness across distributed services, prevents ID enumeration attacks (users cannot guess sequential profile IDs), and allows client-side ID generation before database insertion.
- **`BIGINT` for `Bid`:** Bidding is a high-volume append-heavy workload that can exceed `INT` limits (~2.14B) over time; sequential `BIGINT IDENTITY` (8 bytes vs. 16 bytes for GUID) avoids clustered index fragmentation while supporting virtually unlimited bids.
- **`FLOAT` for GPS (`Latitude`, `Longitude`):** Geographic coordinates are continuous spatial measurements where IEEE 754 floating-point precision (~15 significant digits) is standard and accurate to sub-millimeter scale.
- **`DECIMAL(12,2)` for Money (`Balance`, `StartingPrice`, `Amount`):** Financial calculations require exact base-10 representation; binary `FLOAT` cannot represent fractions like `0.10` accurately and introduces rounding drift in balances and totals.
- **`DATETIMEOFFSET` for Auctions (`StartsAt`, `EndsAt`):** BidNile serves users across multiple time zones (`+02:00` Egypt, `+03:00` KSA, `+04:00` UAE); `DATETIMEOFFSET` stores both the exact UTC instant and the local offset, eliminating Daylight Saving Time ambiguity.

---

## 4. Why the Circular Relationship Cannot Be Created Inside `CREATE TABLE`

SQL Server validates all `FOREIGN KEY` targets at DDL execution time. When creating `Ops.Warehouse` first, `Ops.Employee` does not yet exist in the database catalog, causing `CREATE TABLE` to fail with an invalid object error (and vice versa if `Ops.Employee` is created first). Creating both tables without foreign keys and adding the `FOREIGN KEY` constraints afterward via `ALTER TABLE` cleanly resolves the mutual dependency.

---

## 5. Table Insertion Order & Rationale

Because Foreign Keys were already active before seeding data, tables had to be populated in **topological parent-before-child order** so every `FK` pointed to an existing `PK`:

1. **`Account.City`** — Root lookup table with no dependencies.
2. **`Account.Member`** — Depends on `City`; root members (`InvitedByMemberId = NULL`) were inserted first, followed by invited members referencing them.
3. **`Account.Wallet`** — Depends on `Member`.
4. **`Ops.Warehouse` & `Ops.Employee`** — Temporarily disabled `FK_Warehouse_ManagerId` (`NOCHECK`), inserted warehouses, inserted employees, and re-enabled the constraint (`WITH CHECK CHECK CONSTRAINT`) to break the circular FK during insertion.
5. **`Catalogue.Category`** — Top-level categories (`ParentCategoryCode = NULL`) inserted before child subcategories.
6. **`Catalogue.Item`** — Depends on `Category`, `Member` (`SellerId`), `Warehouse`, and `Employee` (`InspectorId`).
7. **`Catalogue.Photo`** — Depends on `Item`.
8. **`Sales.Auction`** — Depends on `Item`.
9. **`Sales.Bid`** — Depends on `Auction` and `Member`.
10. **`Marketing.AuctionFollow`** — Depends on `Member` and `Auction`.

---

## 6. Errors Encountered in Tasks 3.6 & 3.11 and Fixes

- **Task 3.6 (Changing `Ops.Warehouse.MaxItems` to `SMALLINT`):**
  - *Error:* `ALTER TABLE Ops.Warehouse ALTER COLUMN MaxItems SMALLINT NOT NULL` failed (`Msg 5074`) because `CK_Warehouse_MaxItems` (`MaxItems > 0`) depended on the column.
  - *Fix:* Dropped `CK_Warehouse_MaxItems` first, altered `MaxItems` to `SMALLINT NOT NULL`, and re-created `CK_Warehouse_MaxItems CHECK (MaxItems > 0)`.
- **Task 3.11 (Dropping `Account.Member.IsVerified`):**
  - *Error:* `ALTER TABLE Account.Member DROP COLUMN IsVerified` failed (`Msg 5074`) because the default constraint `DF_Member_IsVerified` was attached to the column.
  - *Fix:* Added `VerifiedAt DATETIME2(3) NULL`, dropped `DF_Member_IsVerified` first via `ALTER TABLE ... DROP CONSTRAINT`, and then dropped `IsVerified`.

---

## 7. Hand Trace — Task 5 (`nums = [1, 2, 3, 4]`)

Given `nums = [1, 2, 3, 4]` (`n = 4`):
- **`prefix[i]`** = product of all elements strictly to the left of `i` (`prefix[0] = 1`).
- **`suffix[i]`** = product of all elements strictly to the right of `i` (`suffix[n - 1] = 1`).
- **`result[i]`** = `prefix[i] * suffix[i]`.

| Index (`i`) | `nums[i]` | `prefix[i]` Calculation | `prefix[i]` | `suffix[i]` Calculation | `suffix[i]` | `result[i] = prefix[i] * suffix[i]` |
| :---: | :---: | :--- | :---: | :--- | :---: | :---: |
| **0** | `1` | Base case (nothing to the left) | **1** | `nums[1] * nums[2] * nums[3] = 2 * 3 * 4` | **24** | `1 * 24 = 24` |
| **1** | `2` | `prefix[0] * nums[0] = 1 * 1` | **1** | `nums[2] * nums[3] = 3 * 4` | **12** | `1 * 12 = 12` |
| **2** | `3` | `prefix[1] * nums[1] = 1 * 2` | **2** | `nums[3] = 4` | **4** | `2 * 4 = 8` |
| **3** | `4` | `prefix[2] * nums[2] = 2 * 3` | **6** | Base case (nothing to the right) | **1** | `6 * 1 = 6` |

- **`prefix[]`** = `[1, 1, 2, 6]`
- **`suffix[]`** = `[24, 12, 4, 1]`
- **Final Output (`result[]`)** = `[24, 12, 8, 6]`