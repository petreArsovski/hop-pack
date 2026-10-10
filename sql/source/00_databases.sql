-- SQL Server does not create these for you. Applied by scripts/init-mssql.sh after the engine is healthy.
IF DB_ID(N'hop_and_barrel') IS NULL
BEGIN
    CREATE DATABASE hop_and_barrel;
END
GO

IF DB_ID(N'hop_distributors') IS NULL
BEGIN
    CREATE DATABASE hop_distributors;
END
GO
