/*
===============================================================================
DDL Script: Database, Schemas, & Bronze Layer Tables Initialization
===============================================================================
Script Purpose:
    This script initializes the DataWarehouse database, creates the Medallion 
    Architecture schemas (Bronze, Silver, Gold), and defines the raw ingestion 
    tables for the Bronze Layer (CRM and ERP source systems).
===============================================================================
*/

-- ============================================================================
-- 1. Database & Schemas Setup
-- ============================================================================
USE master;
GO

-- Create the main Data Warehouse database
CREATE DATABASE DataWarehouse;
GO

USE DataWarehouse;
GO

-- Define Medallion Architecture Schemas
CREATE SCHEMA bronze; -- Raw data ingestion layer
GO
CREATE SCHEMA silver; -- Cleansed & transformed layer
GO
CREATE SCHEMA gold;   -- Business-ready Star Schema layer
GO

-- ============================================================================
-- 2. DDL Scripts for CRM Source Tables (Bronze Schema)
-- ============================================================================

-- Table 1: Customer Information from CRM (cust_info.csv)
IF OBJECT_ID('bronze.crm_cust_info', 'U') IS NOT NULL
    DROP TABLE bronze.crm_cust_info;
GO

CREATE TABLE bronze.crm_cust_info (
    cst_id              INT,
    cst_key             NVARCHAR(50),
    cst_firstname       NVARCHAR(50),
    cst_lastname        NVARCHAR(50),
    cst_material_status NVARCHAR(50),
    cst_gndr            NVARCHAR(50),
    cst_create_date     DATE
);
GO

-- Table 2: Product Information from CRM (prd_info.csv)
IF OBJECT_ID('bronze.crm_prd_info', 'U') IS NOT NULL
    DROP TABLE bronze.crm_prd_info;
GO

CREATE TABLE bronze.crm_prd_info (
    prd_id       INT,
    prd_key      NVARCHAR(50),
    prd_nm       NVARCHAR(100),
    prd_cost     DECIMAL(10, 2),
    prd_line     NVARCHAR(50),
    prd_start_dt DATETIME,
    prd_end_dt   DATETIME
);
GO

-- Table 3: Sales Details from CRM (sales_details.csv)
IF OBJECT_ID('bronze.crm_sales_details', 'U') IS NOT NULL
    DROP TABLE bronze.crm_sales_details;
GO

CREATE TABLE bronze.crm_sales_details (
    sls_ord_num  NVARCHAR(50),
    sls_prd_key  NVARCHAR(50),
    sls_cust_id  INT,
    sls_order_dt INT,
    sls_ship_dt  INT,
    sls_due_dt   INT,
    sls_sales    DECIMAL(10, 2),
    sls_quantity INT,
    sls_price    DECIMAL(10, 2)
);
GO

-- ============================================================================
-- 3. DDL Scripts for ERP Source Tables (Bronze Schema)
-- ============================================================================

-- Table 4: Customer Demographics from ERP (CUST_AZ12.csv)
IF OBJECT_ID('bronze.erp_cust_az12', 'U') IS NOT NULL
    DROP TABLE bronze.erp_cust_az12;
GO

CREATE TABLE bronze.erp_cust_az12 (
    cid   NVARCHAR(50),
    bdate DATE,
    gen   NVARCHAR(50)
);
GO

-- Table 5: Customer Locations from ERP (LOC_A101.csv)
IF OBJECT_ID('bronze.erp_loc_a101', 'U') IS NOT NULL
    DROP TABLE bronze.erp_loc_a101;
GO

CREATE TABLE bronze.erp_loc_a101 (
    cid   NVARCHAR(50),
    cntry NVARCHAR(50)
);
GO

-- Table 6: Product Categories & Subcategories from ERP (PX_CAT_G1V2.csv)
IF OBJECT_ID('bronze.erp_px_cat_g1v2', 'U') IS NOT NULL
    DROP TABLE bronze.erp_px_cat_g1v2;
GO

CREATE TABLE bronze.erp_px_cat_g1v2 (
    id          NVARCHAR(50
