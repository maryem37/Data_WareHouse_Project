/*
===============================================================================
DDL Script: Create Silver Schema Tables
===============================================================================
Script Purpose:
    Ce script crée la structure DDL des tables du schéma 'silver' dans SQL Server.
    Il réinitialise proprement les tables existantes (Idempotence via DROP TABLE IF EXISTS)
    et applique un typage strict pour stocker les données nettoyées et transformées.

Data Warehouse Layer:
    - Layer : Silver (Data Cleansing, Standardization & Conforming Layer)
    - Engine : Microsoft SQL Server / T-SQL
    - Source Systems : CRM & ERP (Bronze Layer)

File Location in Repo:
    docs/ddl/silver_layer_tables.sql
===============================================================================
*/

-- ============================================================================
-- 1. Table : silver.crm_cust_info
-- Description : Référentiel clients issu du CRM.
-- Transformations : Dédoublonné (ROW_NUMBER), espaces nettoyés (TRIM), 
--                   genres et statuts maritaux harmonisés.
-- ============================================================================
IF OBJECT_ID('silver.crm_cust_info', 'U') IS NOT NULL
    DROP TABLE silver.crm_cust_info;
GO

CREATE TABLE silver.crm_cust_info (
    cst_id             INT,            -- Clé primaire client (Unique & non NULL)
    cst_key            NVARCHAR(50),   -- Clé métier / Identifiant CRM d'origine
    cst_firstname      NVARCHAR(50),   -- Prénom nettoyé (Espaces superflus supprimés)
    cst_lastname       NVARCHAR(50),   -- Nom nettoyé (Espaces superflus supprimés)
    cst_marital_status NVARCHAR(50),   -- Statut marital standardisé ('Single', 'Married', 'n/a')
    cst_gndr           NVARCHAR(50),   -- Genre standardisé ('Male', 'Female', 'n/a')
    cst_create_date    DATE,           -- Date de création du profil client
    dwh_create_date    DATETIME2 DEFAULT GETDATE() -- Horodatage d'audit DWH (Date/heure d'ingestion Silver)
);
GO

-- ============================================================================
-- 2. Table : silver.crm_prd_info
-- Description : Catalogue produits du CRM avec extraction des catégories 
--               et calcul de la gestion des versions historiques (SCD Type 2).
-- ============================================================================
IF OBJECT_ID('silver.crm_prd_info', 'U') IS NOT NULL
    DROP TABLE silver.crm_prd_info;
GO

CREATE TABLE silver.crm_prd_info (
    prd_id          INT,            -- Clé primaire produit
    cat_id          NVARCHAR(50),   -- Identifiant de catégorie (Extrait des 5 premiers caractères de prd_key)
    prd_key         NVARCHAR(50),   -- Clé produit nettoyée (Isolée à partir du 7ème caractère)
    prd_nm          NVARCHAR(50),   -- Libellé / Nom commercial du produit
    prd_cost        INT,            -- Coût unitaire (Valeurs NULL remplacées par 0)
    prd_line        NVARCHAR(50),   -- Ligne de produit explicite ('Mountain', 'Road', 'Touring', etc.)
    prd_start_dt    DATE,           -- SCD Type 2 : Date d'effet de la version du produit
    prd_end_dt      DATE,           -- SCD Type 2 : Date d'expiration (Calculée via LEAD() - 1 jour)
    dwh_create_date DATETIME2 DEFAULT GETDATE() -- Horodatage d'audit DWH
);
GO

-- ============================================================================
-- 3. Table : silver.crm_sales_details
-- Description : Table de faits des ventes CRM.
-- Transformations : Dates YYYYMMDD converties en DATE, montants incohérents 
--                   ou négatifs recalculés (Ventes = Quantité * Prix).
-- ============================================================================
IF OBJECT_ID('silver.crm_sales_details', 'U') IS NOT NULL
    DROP TABLE silver.crm_sales_details;
GO

CREATE TABLE silver.crm_sales_details (
    sls_ord_num     NVARCHAR(50),   -- Identifiant de la transaction / Numéro de commande
    sls_prd_key     NVARCHAR(50),   -- Clé étrangère -> Lien vers silver.crm_prd_info (prd_key)
    sls_cust_id     INT,            -- Clé étrangère -> Lien vers silver.crm_cust_info (cst_id)
    sls_order_dt    DATE,           -- Date de commande (Convertie depuis le format entier YYYYMMDD)
    sls_ship_dt     DATE,           -- Date d'expédition (Convertie depuis le format entier YYYYMMDD)
    sls_due_dt      DATE,           -- Date d'échéance de paiement (Convertie depuis YYYYMMDD)
    sls_sales       INT,            -- Montant total de la ligne de vente (Sanitisé)
    sls_quantity    INT,            -- Quantité d'articles vendus
    sls_price       INT,            -- Prix unitaire (Recalculé si NULL ou négatif)
    dwh_create_date DATETIME2 DEFAULT GETDATE() -- Horodatage d'audit DWH
);
GO

-- ============================================================================
-- 4. Table : silver.erp_loc_a101
-- Description : Données de localisation des clients en provenance de l'ERP.
-- Transformations : Suppression des tirets sur les identifiants et mapping
--                   des codes pays vers leurs noms complets.
-- ============================================================================
IF OBJECT_ID('silver.erp_loc_a101', 'U') IS NOT NULL
    DROP TABLE silver.erp_loc_a101;
GO

CREATE TABLE silver.erp_loc_a101 (
    cid             NVARCHAR(50),   -- Clé client ERP (Tirets '-' supprimés pour correspondre au CRM)
    cntry           NVARCHAR(50),   -- Nom du pays standardisé ('Germany', 'United States', 'n/a')
    dwh_create_date DATETIME2 DEFAULT GETDATE() -- Horodatage d'audit DWH
);
GO

-- ============================================================================
-- 5. Table : silver.erp_cust_az12
-- Description : Métadonnées démographiques clients issues de l'ERP.
-- Transformations : Suppression du préfixe 'NAS' sur les ID et invalidation 
--                   des dates de naissance futures.
-- ============================================================================
IF OBJECT_ID('silver.erp_cust_az12', 'U') IS NOT NULL
    DROP TABLE silver.erp_cust_az12;
GO

CREATE TABLE silver.erp_cust_az12 (
    cid             NVARCHAR(50),   -- Clé client ERP (Préfixe 'NAS' nettoyé)
    bdate           DATE,           -- Date de naissance (Dates futures converties en NULL)
    gen             NVARCHAR(50),   -- Genre standardisé ('Male', 'Female', 'n/a')
    dwh_create_date DATETIME2 DEFAULT GETDATE() -- Horodatage d'audit DWH
);
GO

-- ============================================================================
-- 6. Table : silver.erp_px_cat_g1v2
-- Description : Hiérarchie des catégories produits et niveaux de maintenance ERP.
-- ============================================================================
IF OBJECT_ID('silver.erp_px_cat_g1v2', 'U') IS NOT NULL
    DROP TABLE silver.erp_px_cat_g1v2;
GO

CREATE TABLE silver.erp_px_cat_g1v2 (
    id              NVARCHAR(50),   -- Code/Identifiant de la sous-catégorie produit
    cat             NVARCHAR(50),   -- Catégorie principale
    subcat          NVARCHAR(50),   -- Sous-catégorie
    maintenance     NVARCHAR(50),   -- Exigence/Statut de maintenance
    dwh_create_date DATETIME2 DEFAULT GETDATE() -- Horodatage d'audit DWH
);
GO
