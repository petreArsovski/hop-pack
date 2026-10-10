USE hop_distributors;
GO

IF OBJECT_ID(N'dbo.distributors', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.distributors (
        distributor_id INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
        distributor_name VARCHAR(255) NOT NULL,
        contact_name VARCHAR(255),
        city VARCHAR(100),
        country VARCHAR(100),
        created_at DATETIME2 NOT NULL CONSTRAINT DF_distributors_created_at DEFAULT SYSUTCDATETIME()
    );

    SET IDENTITY_INSERT dbo.distributors ON;
    INSERT INTO dbo.distributors (distributor_id, distributor_name, contact_name, city, country) VALUES
        (1, 'North Cask Co', 'Pat Morgan', 'Portland', 'USA'),
        (2, 'Lowlands Keg', 'Eva de Vries', 'Amsterdam', 'Netherlands'),
        (3, 'Pacific Hops Freight', 'Kenji Sato', 'Osaka', 'Japan'),
        (4, 'Alpine Barrel Lines', 'Mia Keller', 'Munich', 'Germany'),
        (5, 'Harbor Yeast', 'Luis Ortega', 'San Diego', 'USA');
    SET IDENTITY_INSERT dbo.distributors OFF;
END
GO

IF OBJECT_ID(N'dbo.beer_distributors', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.beer_distributors (
        distributor_id INT NOT NULL,
        beer_id INT NOT NULL,
        supply_price DECIMAL(10, 2),
        last_updated DATETIME2 NOT NULL CONSTRAINT DF_beer_distributors_last_updated DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_beer_distributors PRIMARY KEY (distributor_id, beer_id)
    );

    INSERT INTO dbo.beer_distributors (distributor_id, beer_id, supply_price) VALUES
        (1, 101, 4.10),
        (1, 106, 4.40),
        (2, 103, 2.80),
        (2, 108, 3.00),
        (3, 102, 4.90),
        (3, 107, 4.20),
        (4, 104, 3.70),
        (4, 109, 3.40),
        (5, 105, 3.50),
        (5, 110, 3.60),
        -- Broken FK on purpose: no distributor 9. Silver/gold should still load; quality checks notice it.
        (9, 101, 1.00);
END
GO
