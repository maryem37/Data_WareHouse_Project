/*
===============================================================================
Stored Procedure: silver.load_silver
===============================================================================
Script Purpose:
    Cette procédure stockée exécute le processus ETL (Extract, Transform, Load) 
    pour alimenter l'ensemble des tables du schéma 'silver' depuis le schéma 'bronze'.

Main Actions Performed:
    1. Mesure globale et individuelle des temps d'exécution (Auditing & Performance).
    2. Vidage des tables cibles (TRUNCATE TABLE pour garantir l'idempotence).
    3. Nettoyage, dédoublonnage, typage et transformation métier de la donnée source.
    4. Insertion des données purifiées dans les tables Silver.
    5. Capture et journalisation des erreurs T-SQL via bloc TRY...CATCH.

Parameters:
    Aucun paramètre en entrée.

Usage Example:
    EXEC silver.load_silver;

File Location in Repo:
    scripts/silver/proc_load_silver.sql
===============================================================================
*/

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
    -- Déclaration des variables de suivi temporel (Audit de performance)
    DECLARE 
        @start_time       DATETIME, 
        @end_time         DATETIME, 
        @batch_start_time DATETIME, 
        @batch_end_time   DATETIME;

    BEGIN TRY
        -- Horodatage du début de chargement du Batch complet
        SET @batch_start_time = GETDATE();
        PRINT '================================================';
        PRINT 'Loading Silver Layer';
        PRINT '================================================';

        -- ====================================================================
        -- SECTION 1 : Chargement des tables sources CRM
        -- ====================================================================
        PRINT '------------------------------------------------';
        PRINT 'Loading CRM Tables';
        PRINT '------------------------------------------------';

        -----------------------------------------------------------------------
        -- 1.1 Table : silver.crm_cust_info
        -- Transformations : Dédoublonnage sur cst_id (ROW_NUMBER), suppression
        --                  des espaces (TRIM) et normalisation du genre / statut.
        -----------------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.crm_cust_info';
        TRUNCATE TABLE silver.crm_cust_info;

        PRINT '>> Inserting Data Into: silver.crm_cust_info';
        INSERT INTO silver.crm_cust_info (
            cst_id,
            cst_key,
            cst_firstname,
            cst_lastname,
            cst_marital_status,
            cst_gndr,
            cst_create_date
        )
        SELECT
            cst_id,
            cst_key,
            TRIM(cst_firstname) AS cst_firstname, -- Nettoyage des espaces superflus
            TRIM(cst_lastname)  AS cst_lastname,  -- Nettoyage des espaces superflus
            
            -- Normalisation du statut marital vers des valeurs lisibles
            CASE
                WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
                WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
                ELSE 'n/a'
            END AS cst_marital_status,

            -- Normalisation du genre vers des valeurs standardisées
            CASE
                WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
                WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
                ELSE 'n/a'
            END AS cst_gndr,

            cst_create_date
        FROM (
            -- Subquery : Stratégie de dédoublonnage pour ne conserver que l'enregistrement le plus récent
            SELECT
                *,
                ROW_NUMBER() OVER (
                    PARTITION BY cst_id 
                    ORDER BY cst_create_date DESC
                ) AS flag_last
            FROM bronze.crm_cust_info
            WHERE cst_id IS NOT NULL -- Élimination des identifiants invalides/manquants
        ) t
        WHERE flag_last = 1;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -----------------------------------------------------------------------
        -- 1.2 Table : silver.crm_prd_info
        -- Transformations : Extraction de cat_id et prd_key, mapping de prd_line,
        --                  gestion des prix nuls et calcul des dates SCD Type 2.
        -----------------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.crm_prd_info';
        TRUNCATE TABLE silver.crm_prd_info;

        PRINT '>> Inserting Data Into: silver.crm_prd_info';
        INSERT INTO silver.crm_prd_info (
            prd_id,
            cat_id,
            prd_key,
            prd_nm,
            prd_cost,
            prd_line,
            prd_start_dt,
            prd_end_dt
        )
        SELECT
            prd_id,
            REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,  -- Extraction de l'ID de catégorie
            SUBSTRING(prd_key, 7, LEN(prd_key))         AS prd_key, -- Extraction de la clé produit nettoyée
            TRIM(prd_nm)                                AS prd_nm,
            ISNULL(prd_cost, 0)                         AS prd_cost,-- Remplacement des coûts NULL par 0
            
            -- Normalisation des abréviations de ligne de produit
            CASE
                WHEN UPPER(TRIM(prd_line)) = 'M' THEN 'Mountain'
                WHEN UPPER(TRIM(prd_line)) = 'R' THEN 'Road'
                WHEN UPPER(TRIM(prd_line)) = 'S' THEN 'Other Sales'
                WHEN UPPER(TRIM(prd_line)) = 'T' THEN 'Touring'
                ELSE 'n/a'
            END AS prd_line,

            CAST(prd_start_dt AS DATE) AS prd_start_dt,
            
            -- SCD Type 2 : Calcul de la date d'expiration de la version (start_dt suivante - 1 jour)
            CAST(
                LEAD(prd_start_dt) OVER (
                    PARTITION BY SUBSTRING(prd_key, 7, LEN(prd_key)) 
                    ORDER BY prd_start_dt
                ) - 1 AS DATE
            ) AS prd_end_dt
        FROM bronze.crm_prd_info;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -----------------------------------------------------------------------
        -- 1.3 Table : silver.crm_sales_details
        -- Transformations : Conversion des dates entières YYYYMMDD vers DATE,
        --                  recalcul des montants de ventes et prix unitaires valides.
        -----------------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.crm_sales_details';
        TRUNCATE TABLE silver.crm_sales_details;

        PRINT '>> Inserting Data Into: silver.crm_sales_details';
        INSERT INTO silver.crm_sales_details (
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            sls_order_dt,
            sls_ship_dt,
            sls_due_dt,
            sls_sales,
            sls_quantity,
            sls_price
        )
        SELECT
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            
            -- Conversion sécurisée de la date de commande (Validation de longueur YYYYMMDD)
            CASE
                WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
                ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
            END AS sls_order_dt,

            -- Conversion sécurisée de la date d'expédition
            CASE
                WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
                ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
            END AS sls_ship_dt,

            -- Conversion sécurisée de la date d'échéance
            CASE
                WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
                ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
            END AS sls_due_dt,

            -- Correction métier du chiffre d'affaires (Sales = Quantité * |Prix|)
            CASE
                WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
                    THEN sls_quantity * ABS(sls_price)
                ELSE sls_sales
            END AS sls_sales,

            sls_quantity,

            -- Correction du prix unitaire (Prix = Sales / Quantité) avec protection contre la division par zéro
            CASE
                WHEN sls_price IS NULL OR sls_price <= 0
                    THEN sls_sales / NULLIF(sls_quantity, 0)
                ELSE sls_price
            END AS sls_price
        FROM bronze.crm_sales_details;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- ====================================================================
        -- SECTION 2 : Chargement des tables sources ERP
        -- ====================================================================
        PRINT '------------------------------------------------';
        PRINT 'Loading ERP Tables';
        PRINT '------------------------------------------------';

        -----------------------------------------------------------------------
        -- 2.1 Table : silver.erp_cust_az12
        -- Transformations : Nettoyage du préfixe 'NAS' sur l'ID client,
        --                  invalidation des dates de naissance futures.
        -----------------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.erp_cust_az12';
        TRUNCATE TABLE silver.erp_cust_az12;

        PRINT '>> Inserting Data Into: silver.erp_cust_az12';
        INSERT INTO silver.erp_cust_az12 (
            cid,
            bdate,
            gen
        )
        SELECT
            -- Nettoyage du préfixe système source ERP
            CASE
                WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
                ELSE cid
            END AS cid,

            -- Remplacement des dates de naissance futures aberrantes par NULL
            CASE
                WHEN bdate > GETDATE() THEN NULL
                ELSE bdate
            END AS bdate,

            -- Harmonisation des formats de genre ERP
            CASE
                WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
                WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
                ELSE 'n/a'
            END AS gen
        FROM bronze.erp_cust_az12;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -----------------------------------------------------------------------
        -- 2.2 Table : silver.erp_loc_a101
        -- Transformations : Suppression des tirets sur les identifiants et 
        --                  standardisation des libellés pays.
        -----------------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.erp_loc_a101';
        TRUNCATE TABLE silver.erp_loc_a101;

        PRINT '>> Inserting Data Into: silver.erp_loc_a101';
        INSERT INTO silver.erp_loc_a101 (
            cid,
            cntry
        )
        SELECT
            REPLACE(cid, '-', '') AS cid, -- Formatage uniforme de la clé client
            
            -- Mapping et nettoyage des codes pays
            CASE
                WHEN TRIM(cntry) = 'DE' THEN 'Germany'
                WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
                WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
                ELSE TRIM(cntry)
            END AS cntry
        FROM bronze.erp_loc_a101;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -----------------------------------------------------------------------
        -- 2.3 Table : silver.erp_px_cat_g1v2
        -- Transformations : Transposition directe des données de catégorisation.
        -----------------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.erp_px_cat_g1v2';
        TRUNCATE TABLE silver.erp_px_cat_g1v2;

        PRINT '>> Inserting Data Into: silver.erp_px_cat_g1v2';
        INSERT INTO silver.erp_px_cat_g1v2 (
            id,
            cat,
            subcat,
            maintenance
        )
        SELECT
            TRIM(id)          AS id,
            TRIM(cat)         AS cat,
            TRIM(subcat)      AS subcat,
            TRIM(maintenance) AS maintenance
        FROM bronze.erp_px_cat_g1v2;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- Fin du batch et calcul de la durée globale
        SET @batch_end_time = GETDATE();
        PRINT '==========================================';
        PRINT 'Loading Silver Layer Completed Successfully';
        PRINT '   - Total Load Duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
        PRINT '==========================================';

    END TRY
    BEGIN CATCH
        -- Gestion centralisée des erreurs de pipeline
        PRINT '==========================================';
        PRINT 'ERROR OCCURRED DURING LOADING SILVER LAYER';
        PRINT 'Error Message : ' + ERROR_MESSAGE();
        PRINT 'Error Number  : ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT 'Error State   : ' + CAST(ERROR_STATE() AS NVARCHAR);
        PRINT '==========================================';
    END CATCH
END;
GO
