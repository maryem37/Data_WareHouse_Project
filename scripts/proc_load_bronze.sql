/*
===============================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze)
===============================================================================
Script Purpose:
    This stored procedure ingests raw data from CSV source files (CRM and ERP systems)
    into the 'bronze' schema tables within the Data Warehouse.

Operations Performed:
    1. Truncates destination Bronze tables to ensure clean full-load ingestion.
    2. Performs BULK INSERT from raw CSV files into SQL Server Bronze tables.
    3. Tracks and logs performance metrics (individual table and total batch load duration).
    4. Implements structured exception handling using TRY...CATCH to intercept runtime errors.

Parameters:
    None.

Usage / Execution:
    EXEC bronze.load_bronze;
===============================================================================
*/

CREATE OR ALTER PROCEDURE bronze.load_bronze
AS
BEGIN
    -- Prevent extra result sets from interfering with SELECT statements / clean output stream
    SET NOCOUNT ON;

    -- Declare local variables for timing metrics
    DECLARE @start_time DATETIME, @end_time DATETIME;            -- Measures duration per table
    DECLARE @batch_start_time DATETIME, @batch_end_time DATETIME;  -- Measures overall batch duration

    BEGIN TRY
        -- Capture overall batch execution start time
        SET @batch_start_time = GETDATE();

        PRINT '==================================================';
        PRINT 'Loading Bronze Layer';
        PRINT '==================================================';

        -- ====================================================================
        -- 1. CRM SOURCE SYSTEM INGESTION
        -- ====================================================================
        PRINT '--------------------------------------------------';
        PRINT 'Loading CRM Tables';
        PRINT '--------------------------------------------------';

        ----------------------------------------------------------------------
        -- Table 1: Customer Information (cust_info.csv)
        ----------------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.crm_cust_info';
        TRUNCATE TABLE bronze.crm_cust_info;

        PRINT '>> Inserting Data Into: bronze.crm_cust_info';
        BULK INSERT bronze.crm_cust_info
        FROM 'D:\sql-data-warehouse-project\datasets\source_crm\cust_info.csv'
        WITH (
            FIRSTROW = 2,           -- Skip the header row in CSV
            FIELDTERMINATOR = ',',  -- CSV column delimiter
            TABLOCK                 -- Minimal logging for optimized bulk insertion speed
        );
        
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(millisecond, @start_time, @end_time) AS NVARCHAR) + ' ms';
        PRINT '--------------------------------------------------';

        ----------------------------------------------------------------------
        -- Table 2: Product Information (prd_info.csv)
        ----------------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.crm_prd_info';
        TRUNCATE TABLE bronze.crm_prd_info;

        PRINT '>> Inserting Data Into: bronze.crm_prd_info';
        BULK INSERT bronze.crm_prd_info
        FROM 'D:\sql-data-warehouse-project\datasets\source_crm\prd_info.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(millisecond, @start_time, @end_time) AS NVARCHAR) + ' ms';
        PRINT '--------------------------------------------------';

        ----------------------------------------------------------------------
        -- Table 3: Sales Order Details (sales_details.csv)
        ----------------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.crm_sales_details';
        TRUNCATE TABLE bronze.crm_sales_details;

        PRINT '>> Inserting Data Into: bronze.crm_sales_details';
        BULK INSERT bronze.crm_sales_details
        FROM 'D:\sql-data-warehouse-project\datasets\source_crm\sales_details.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(millisecond, @start_time, @end_time) AS NVARCHAR) + ' ms';
        PRINT '--------------------------------------------------';

        -- ====================================================================
        -- 2. ERP SOURCE SYSTEM INGESTION
