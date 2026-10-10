-- Hop & Barrel shop (OLTP). Source system, not the warehouse.
USE hop_and_barrel;
GO

IF OBJECT_ID(N'dbo.styles', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.styles (
        style_id INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        updated_at DATETIME2 NOT NULL CONSTRAINT DF_styles_updated_at DEFAULT SYSUTCDATETIME()
    );

    SET IDENTITY_INSERT dbo.styles ON;
    INSERT INTO dbo.styles (style_id, name) VALUES
        (1, 'IPA'),
        (2, 'Stout'),
        (3, 'Lager'),
        (4, 'Sour'),
        (5, 'Wheat');
    SET IDENTITY_INSERT dbo.styles OFF;
END
GO

IF OBJECT_ID(N'dbo.beers', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.beers (
        beer_id INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        style_id INT,
        abv DECIMAL(4, 2),
        price DECIMAL(10, 2),
        updated_at DATETIME2 NOT NULL CONSTRAINT DF_beers_updated_at DEFAULT SYSUTCDATETIME()
    );

    SET IDENTITY_INSERT dbo.beers ON;
    INSERT INTO dbo.beers (beer_id, name, style_id, abv, price) VALUES
        (101, 'Pine Needle IPA', 1, 6.50, 8.00),
        (102, 'Night Watch Stout', 2, 8.20, 9.00),
        (103, 'Canal Street Lager', 3, 4.80, 6.00),
        (104, 'Kettle Sour Cherry', 4, 5.10, 7.50),
        (105, 'Hefe Cloud', 5, 5.00, 7.00),
        (106, 'West Coast IPA', 1, 7.10, 8.50),
        (107, 'Milk Stout', 2, 6.00, 8.00),
        (108, 'Pilsner Bench', 3, 4.50, 6.50),
        (109, 'Gose Salt', 4, 4.20, 7.00),
        (110, 'Amber Wheat', 5, 5.40, 7.25);
    SET IDENTITY_INSERT dbo.beers OFF;
END
GO

IF OBJECT_ID(N'dbo.customers', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.customers (
        customer_id INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
        name VARCHAR(255),
        email VARCHAR(255),
        updated_at DATETIME2 NOT NULL CONSTRAINT DF_customers_updated_at DEFAULT SYSUTCDATETIME()
    );

    SET IDENTITY_INSERT dbo.customers ON;
    INSERT INTO dbo.customers (customer_id, name, email) VALUES
        (1, 'Alex Rivera', 'alex@example.com'),
        (2, 'Sam Chen', 'sam@example.com'),
        (3, 'Jordan Blake', 'jordan@example.com'),
        (4, 'Riley Ng', 'riley@example.com'),
        (5, 'Casey Dunn', 'casey@example.com'),
        -- Intentionally messy: silver should quarantine this row.
        (6, 'Unknown Guest', NULL);
    SET IDENTITY_INSERT dbo.customers OFF;
END
GO

IF OBJECT_ID(N'dbo.orders', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.orders (
        order_id INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
        customer_id INT,
        order_date DATETIME2 NOT NULL CONSTRAINT DF_orders_order_date DEFAULT SYSUTCDATETIME(),
        total_amount DECIMAL(10, 2),
        updated_at DATETIME2 NOT NULL CONSTRAINT DF_orders_updated_at DEFAULT SYSUTCDATETIME()
    );

    SET IDENTITY_INSERT dbo.orders ON;
    INSERT INTO dbo.orders (order_id, customer_id, total_amount) VALUES
        (2001, 1, 16.00),
        (2002, 2, 9.00),
        (2003, 3, 15.00),
        (2004, 4, 14.50),
        (2005, 5, 13.00),
        -- Intentionally messy: header total does not match line items.
        (2006, 1, 99.00);
    SET IDENTITY_INSERT dbo.orders OFF;
END
GO

IF OBJECT_ID(N'dbo.order_items', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.order_items (
        order_item_id INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
        order_id INT,
        beer_id INT,
        quantity INT,
        price DECIMAL(10, 2),
        updated_at DATETIME2 NOT NULL CONSTRAINT DF_order_items_updated_at DEFAULT SYSUTCDATETIME()
    );

    SET IDENTITY_INSERT dbo.order_items ON;
    INSERT INTO dbo.order_items (order_item_id, order_id, beer_id, quantity, price) VALUES
        (1, 2001, 101, 2, 8.00),
        (2, 2002, 102, 1, 9.00),
        (3, 2003, 104, 2, 7.50),
        (4, 2004, 105, 1, 7.00),
        (5, 2004, 109, 1, 7.00),
        (6, 2005, 103, 1, 6.00),
        (7, 2005, 108, 1, 6.50),
        (8, 2006, 106, 1, 8.50);
    SET IDENTITY_INSERT dbo.order_items OFF;
END
GO
