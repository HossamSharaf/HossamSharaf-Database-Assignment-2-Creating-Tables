-- Create Task 2
GO
CREATE DATABASE BidNile
GO 
USE BidNile
GO 
CREATE SCHEMA Account
GO
CREATE SCHEMA Ops
GO
CREATE SCHEMA Sales
GO
CREATE SCHEMA Catalogue
GO
CREATE TABLE Account.City
(
CityId  int IDENTITY (1,1)
CONSTRAINT PK_City primary key,

Name NVARCHAR(60) NOT NULL,

CountryCode CHAR(2)  NOT NULL
CONSTRAINT CK_City_CountryCode CHECK (CountryCode IN ('EG' ,'SA' , 'AE'))

CONSTRAINT UQ_City_Name_CountryCode UNIQUE(Name,CountryCode)
)
GO
CREATE TABLE Account.Member
(
MemberId UNIQUEIDENTIFIER NOT NULL
CONSTRAINT PK_Member PRIMARY KEY
CONSTRAINT DF_Member_MemberId DEFAULT NEWID(),

FullName NVARCHAR(100) NOT NULL ,

Email NVARCHAR(254) NOT NULL
CONSTRAINT UQ_Member_Email UNIQUE,

Phone NVARCHAR(16) NOT NULL,

NationalIdOrPassport NVARCHAR(20) NOT NULL
CONSTRAINT UQ_Member_NationalIdOrPassport UNIQUE,

BirthDate DATE NOT NULL 
CONSTRAINT CK_Member_BirthDate CHECK (DATEADD(YEAR, 18, BirthDate) <= CAST(GETDATE() AS DATE)),

IsVerified BIT NOT NULL 
CONSTRAINT DF_Member_IsVerified DEFAULT 0,

RegisteredAt DATETIME2(3) NOT NULL
CONSTRAINT DF_Member_RegisteredAt DEFAULT SYSUTCDATETIME(),

CityId int NOT NULL ,

InvitedByMemberId    UNIQUEIDENTIFIER NULL,
CONSTRAINT CK_Member_InvitedByMemberId CHECK (InvitedByMemberId <> MemberId)
)
GO
CREATE TABLE Account.Wallet
(
MemberId UNIQUEIDENTIFIER NOT NULL
CONSTRAINT PK_Wallet PRIMARY KEY,

Balance DECIMAL(12,2) NOT NULL
CONSTRAINT CK_Wallet_Balance CHECK (Balance >=0)
CONSTRAINT DF_Wallet_Balance DEFAULT 0.00,

AmountOnHold DECIMAL(12,2) NOT NULL
CONSTRAINT DF_Wallet_AmountOnHold DEFAULT 0.00,

Currency CHAR(3) NOT NULL
CONSTRAINT DF_Wallet_Currency DEFAULT 'EGP',

UpdatedAt    DATETIME2(3)     NOT NULL
        CONSTRAINT DF_Wallet_UpdatedAt DEFAULT SYSUTCDATETIME(),
 CONSTRAINT CK_Wallet_AmountOnHold CHECK (Balance >= AmountOnHold AND AmountOnHold>=0)
)
GO
CREATE TABLE Ops.Warehouse
(
    WarehouseId      INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Warehouse PRIMARY KEY,
    Name             NVARCHAR(80)      NOT NULL
        CONSTRAINT UQ_Warehouse_Name UNIQUE,
    Capacity         INT               NOT NULL
        CONSTRAINT CK_Warehouse_Capacity CHECK (Capacity > 0),
    Latitude         FLOAT             NOT NULL
        CONSTRAINT CK_Warehouse_Latitude CHECK (Latitude BETWEEN -90 AND 90),
    Longitude        FLOAT             NOT NULL
        CONSTRAINT CK_Warehouse_Longitude CHECK (Longitude BETWEEN -180 AND 180),
    CityId           INT               NOT NULL,
    ManagerId        UNIQUEIDENTIFIER  NOT NULL
        CONSTRAINT UQ_Warehouse_ManagerId UNIQUE,
    ManagerStartDate DATE              NOT NULL
);
GO
CREATE TABLE Ops.Employee
(
    EmployeeId  UNIQUEIDENTIFIER NOT NULL
        CONSTRAINT PK_Employee PRIMARY KEY,
    WarehouseId INT              NOT NULL
);
GO
CREATE TABLE Catalogue.Category
(
    CategoryCode       INT           NOT NULL
        CONSTRAINT PK_Category PRIMARY KEY,
    EnglishName        NVARCHAR(50)  NOT NULL
        CONSTRAINT UQ_Category_EnglishName UNIQUE,
    ArabicName         NVARCHAR(50)  NULL,
    Commission         DECIMAL(4,2)  NOT NULL
        CONSTRAINT CK_Category_Commission CHECK (Commission BETWEEN 0 AND 30),
    ParentCategoryCode INT           NULL,

    CONSTRAINT CK_Category_ParentCategoryCode CHECK (ParentCategoryCode <> CategoryCode)
);
GO
CREATE TABLE Catalogue.Item
(
    ItemId         INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Item PRIMARY KEY,
    Title          NVARCHAR(150)     NOT NULL,
    Description    NVARCHAR(MAX)     NULL,
    ConditionScore TINYINT           NOT NULL
        CONSTRAINT CK_Item_ConditionScore CHECK (ConditionScore BETWEEN 1 AND 10),
    Specifications NVARCHAR(MAX)     NOT NULL
        CONSTRAINT CK_Item_Specifications CHECK (ISJSON(Specifications) = 1),
    ListedAt       DATETIME2(3)      NOT NULL
        CONSTRAINT DF_Item_ListedAt DEFAULT SYSUTCDATETIME(),
    CategoryCode   INT               NOT NULL,
    SellerId       UNIQUEIDENTIFIER  NOT NULL,
    WarehouseId    INT               NULL,
    InspectorId    UNIQUEIDENTIFIER  NULL,

    CONSTRAINT CK_Item_InspectorId CHECK (InspectorId <> SellerId)
);
GO
CREATE TABLE Catalogue.Photo
(
    ItemId   INT          NOT NULL,
    Position TINYINT      NOT NULL
        CONSTRAINT CK_Photo_Position CHECK (Position BETWEEN 1 AND 20),
    Url      VARCHAR(500) NOT NULL,
    IsMain   BIT          NOT NULL
        CONSTRAINT DF_Photo_IsMain DEFAULT 0,

    CONSTRAINT PK_Photo PRIMARY KEY (ItemId, Position)
);
GO
CREATE TABLE Sales.Auction
(
    AuctionId     INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Auction PRIMARY KEY,
    ItemId        INT               NOT NULL,
    StartingPrice DECIMAL(12,2)     NOT NULL
        CONSTRAINT CK_Auction_StartingPrice CHECK (StartingPrice > 0),
    ReservePrice  DECIMAL(12,2)     NULL,
    BidIncrement  DECIMAL(12,2)     NOT NULL
        CONSTRAINT DF_Auction_BidIncrement DEFAULT 50.00
        CONSTRAINT CK_Auction_BidIncrement CHECK (BidIncrement > 0),
    StartsAt      DATETIMEOFFSET    NOT NULL,
    EndsAt        DATETIMEOFFSET    NOT NULL,
    Status        VARCHAR(15)       NOT NULL
        CONSTRAINT DF_Auction_Status DEFAULT 'Draft'
        CONSTRAINT CK_Auction_Status CHECK (Status IN ('Draft', 'Live', 'Ended', 'Cancelled')),

    CONSTRAINT CK_Auction_ReservePrice CHECK (ReservePrice >= StartingPrice),
    CONSTRAINT CK_Auction_EndsAt       CHECK (EndsAt > StartsAt)
);
GO
CREATE TABLE Sales.Bid
(
    BidId     BIGINT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Bid PRIMARY KEY,
    AuctionId INT                  NOT NULL,
    MemberId  UNIQUEIDENTIFIER     NOT NULL,
    Amount    DECIMAL(12,2)        NOT NULL
        CONSTRAINT CK_Bid_Amount CHECK (Amount > 0),
    PlacedAt  DATETIME2(3)         NOT NULL
        CONSTRAINT DF_Bid_PlacedAt DEFAULT SYSUTCDATETIME(),
    IpAddress VARCHAR(45)          NOT NULL,

    CONSTRAINT UQ_Bid_AuctionId_Amount UNIQUE (AuctionId, Amount)
);
GO
CREATE TABLE Sales.AuctionFollow
(
    MemberId   UNIQUEIDENTIFIER NOT NULL,
    AuctionId  INT              NOT NULL,
    FollowedAt DATETIME2(3)     NOT NULL
        CONSTRAINT DF_AuctionFollow_FollowedAt DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_AuctionFollow PRIMARY KEY (MemberId, AuctionId)
);
GO
--Task 3.1
ALTER TABLE Account.Member
    ADD CONSTRAINT FK_Member_CityId
    FOREIGN KEY (CityId) REFERENCES Account.City (CityId);

ALTER TABLE Account.Member
    ADD CONSTRAINT FK_Member_InvitedByMemberId
    FOREIGN KEY (InvitedByMemberId) REFERENCES Account.Member (MemberId);

ALTER TABLE Account.Wallet
    ADD CONSTRAINT FK_Wallet_MemberId
    FOREIGN KEY (MemberId) REFERENCES Account.Member (MemberId);

ALTER TABLE Ops.Warehouse
    ADD CONSTRAINT FK_Warehouse_CityId
    FOREIGN KEY (CityId) REFERENCES Account.City (CityId);

ALTER TABLE Ops.Warehouse
    ADD CONSTRAINT FK_Warehouse_ManagerId
    FOREIGN KEY (ManagerId) REFERENCES Ops.Employee (EmployeeId);

ALTER TABLE Ops.Employee
    ADD CONSTRAINT FK_Employee_EmployeeId
    FOREIGN KEY (EmployeeId) REFERENCES Account.Member (MemberId);

ALTER TABLE Ops.Employee
    ADD CONSTRAINT FK_Employee_WarehouseId
    FOREIGN KEY (WarehouseId) REFERENCES Ops.Warehouse (WarehouseId);

ALTER TABLE Catalogue.Category
    ADD CONSTRAINT FK_Category_ParentCategoryCode
    FOREIGN KEY (ParentCategoryCode) REFERENCES Catalogue.Category (CategoryCode);

ALTER TABLE Catalogue.Item
    ADD CONSTRAINT FK_Item_CategoryCode
    FOREIGN KEY (CategoryCode) REFERENCES Catalogue.Category (CategoryCode);

ALTER TABLE Catalogue.Item
    ADD CONSTRAINT FK_Item_SellerId
    FOREIGN KEY (SellerId) REFERENCES Account.Member (MemberId);

ALTER TABLE Catalogue.Item
    ADD CONSTRAINT FK_Item_WarehouseId
    FOREIGN KEY (WarehouseId) REFERENCES Ops.Warehouse (WarehouseId);

ALTER TABLE Catalogue.Item
    ADD CONSTRAINT FK_Item_InspectorId
    FOREIGN KEY (InspectorId) REFERENCES Ops.Employee (EmployeeId);

ALTER TABLE Catalogue.Photo
    ADD CONSTRAINT FK_Photo_ItemId
    FOREIGN KEY (ItemId) REFERENCES Catalogue.Item (ItemId)
    ON DELETE CASCADE;

ALTER TABLE Sales.Auction
    ADD CONSTRAINT FK_Auction_ItemId
    FOREIGN KEY (ItemId) REFERENCES Catalogue.Item (ItemId);

ALTER TABLE Sales.Bid
    ADD CONSTRAINT FK_Bid_AuctionId
    FOREIGN KEY (AuctionId) REFERENCES Sales.Auction (AuctionId);

ALTER TABLE Sales.Bid
    ADD CONSTRAINT FK_Bid_MemberId
    FOREIGN KEY (MemberId) REFERENCES Account.Member (MemberId);

ALTER TABLE Sales.AuctionFollow
    ADD CONSTRAINT FK_AuctionFollow_MemberId
    FOREIGN KEY (MemberId) REFERENCES Account.Member (MemberId);

ALTER TABLE Sales.AuctionFollow
    ADD CONSTRAINT FK_AuctionFollow_AuctionId
    FOREIGN KEY (AuctionId) REFERENCES Sales.Auction (AuctionId);
GO
--TASK 3.2
ALTER TABLE Account.Member
    ADD AppLanguage CHAR(2) NOT NULL
        CONSTRAINT DF_Member_AppLanguage DEFAULT 'ar'
        CONSTRAINT CK_Member_AppLanguage CHECK (AppLanguage IN ('ar', 'en'));
GO
--TASK 3.3
ALTER TABLE Catalogue.Item
    ADD IsFeatured BIT NOT NULL
        CONSTRAINT DF_Item_IsFeatured DEFAULT 0;
GO
--TASK 3.4
EXEC sp_rename 'Sales.Bid.IpAddress', 'DeviceIp', 'COLUMN';
ALTER TABLE Ops.Warehouse
    DROP CONSTRAINT CK_Warehouse_Capacity;

EXEC sp_rename 'Ops.Warehouse.Capacity', 'MaxItems', 'COLUMN';
GO

ALTER TABLE Ops.Warehouse
    ADD CONSTRAINT CK_Warehouse_MaxItems CHECK (MaxItems > 0);
GO
-- TASK 3.5

ALTER TABLE Account.Member 
ALTER COLUMN FullName NVARCHAR(150) NOT NULL
GO
--TASK 3.6
ALTER TABLE Ops.Warehouse
    DROP CONSTRAINT CK_Warehouse_MaxItems;

ALTER TABLE Ops.Warehouse
ALTER COLUMN MaxItems SMALLINT NOT NULL
ALTER TABLE Ops.Warehouse
    ADD CONSTRAINT CK_Warehouse_MaxItems CHECK (MaxItems > 0);
GO
--TASK 3.7
ALTER TABLE Catalogue.Category
DROP CONSTRAINT CK_Category_Commission

ALTER TABLE Catalogue.Category
ADD CONSTRAINT CK_Category_Commission CHECK (Commission BETWEEN 0 AND 25)
GO
--TASK 3.8
ALTER TABLE Sales.Auction
DROP CONSTRAINT DF_Auction_Status

ALTER TABLE Sales.Auction
ADD CONSTRAINT DF_Auction_Status DEFAULT 'PendingReview' FOR Status


ALTER TABLE Sales.Auction
DROP CONSTRAINT CK_Auction_Status

ALTER TABLE Sales.Auction
ADD  CONSTRAINT CK_Auction_Status CHECK (Status IN ('Draft', 'Live', 'Ended', 'Cancelled','PendingReview'))
GO
--TASK 3.9
ALTER TABLE Sales.Auction
    ADD BuyNowPrice DECIMAL(12,2) NULL;

    ALTER TABLE Sales.Auction
    WITH CHECK ADD CONSTRAINT CK_Auction_BuyNowPrice CHECK (BuyNowPrice > StartingPrice);
GO
-- TASK 3.10
ALTER TABLE Account.Member
    ADD CONSTRAINT UQ_Member_Phone UNIQUE (Phone);
GO
-- TASK 3.11
ALTER TABLE Account.Member
    ADD VerifiedAt DATETIME2(3) NULL;
    ALTER TABLE Account.Member
    DROP CONSTRAINT DF_Member_IsVerified;

ALTER TABLE Account.Member
    DROP COLUMN IsVerified;
GO
--TASK 3.12 
CREATE SCHEMA Marketing;
GO

ALTER SCHEMA Marketing TRANSFER Sales.AuctionFollow;
GO
-- End


