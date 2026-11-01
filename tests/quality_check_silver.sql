/*
===============================================================================
Quality Assurance Script: Silver Layer Data Quality Audit
===============================================================================
Script Purpose:
    Ce script exécute une suite complète de tests de qualité de données (Data Quality Checks)
    sur l'ensemble du schéma 'silver' après l'exécution de la procédure 'silver.load_silver'.
    
    Il permet de valider :
    1. L'intégrité des clés primaires (absence de NULL et de doublons).
    2. La propreté des chaînes de caractères (absence d'espaces superflus).
    3. La cohérence des règles de standardisation (valeurs catégorielles nettoyées).
    4. La validité et le séquencement chronologique des dates.
    5. La cohérence mathématique des équations financières et quantitatives.

Usage Notes:
    - À exécuter immédiatement après chaque rechargement de la couche Silver.
    - Pour les requêtes annotées avec 'Expectation: No Results', tout résultat retourné
      indique une anomalie à corriger dans le pipeline d'ingestion Silver.

File Location in Repo:
    tests/quality_checks_silver.sql
===============================================================================
*/

-- ====================================================================
-- SECTION 1 : Audit de la table 'silver.crm_cust_info'
-- ====================================================================

-- 1.1 Contrôle d'unicité et de validité de la clé primaire (cst_id)
-- Résultat attendu : 0 ligne (Aucun doublon ni identifiant NULL)
SELECT
    cst_id,
    COUNT(*) AS count_duplicates
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- 1.2 Contrôle de propreté du champ cst_key (Absence d'espaces indésirables)
-- Résultat attendu : 0 ligne
SELECT
    cst_key
FROM silver.crm_cust_info
WHERE cst_key != TRIM(cst_key);

-- 1.3 Validation de la standardisation des statuts maritaux
-- Résultat attendu : Liste distincte propre ('Single', 'Married', 'n/a')
SELECT DISTINCT
    cst_marital_status
FROM silver.crm_cust_info;

-- 1.4 Validation de la standardisation des genres
-- Résultat attendu : Liste distincte propre ('Male', 'Female', 'n/a')
SELECT DISTINCT
    cst_gndr
FROM silver.crm_cust_info;


-- ====================================================================
-- SECTION 2 : Audit de la table 'silver.crm_prd_info'
-- ====================================================================

-- 2.1 Contrôle d'unicité et de validité de la clé primaire (prd_id)
-- Résultat attendu : 0 ligne
SELECT
    prd_id,
    COUNT(*) AS count_duplicates
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;

-- 2.2 Contrôle de propreté du nom de produit (prd_nm)
-- Résultat attendu : 0 ligne
SELECT
    prd_nm
FROM silver.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);

-- 2.3 Détection de coûts unitaires invalides ou manquants (prd_cost)
-- Résultat attendu : 0 ligne (Les NULLs doivent être convertis en 0 et aucun coût ne doit être négatif)
SELECT
    prd_cost
FROM silver.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL;

-- 2.4 Validation de la standardisation des lignes de produits (prd_line)
-- Résultat attendu : Libellés explicites ('Mountain', 'Road', 'Other Sales', 'Touring', 'n/a')
SELECT DISTINCT
    prd_line
FROM silver.crm_prd_info;

-- 2.5 Contrôle de la cohérence chronologique des dates SCD Type 2
-- Résultat attendu : 0 ligne (La date de fin ne peut pas être antérieure à la date de début)
SELECT
    *
FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt;


-- ====================================================================
-- SECTION 3 : Audit de la table 'silver.crm_sales_details'
-- ====================================================================

-- 3.1 Contrôle des dates invalides dans la table source Bronze
-- Note : Ce test interroge la table Bronze car Silver a déjà nettoyé et converti ces champs en DATE.
-- Résultat attendu : 0 ligne (Aucune date égale à 0, hors de portée ou avec une longueur différente de 8 caractères YYYYMMDD)
SELECT
    NULLIF(sls_due_dt, 0) AS sls_due_dt
FROM bronze.crm_sales_details
WHERE sls_due_dt <= 0
   OR LEN(sls_due_dt) != 8
   OR sls_due_dt > 20500101
   OR sls_due_dt < 19000101;

-- 3.2 Contrôle de la cohérence chronologique du cycle de vente
-- Résultat attendu : 0 ligne (La date de commande ne peut pas être postérieure à la date d'expédition ou d'échéance)
SELECT
    *
FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt
   OR sls_order_dt > sls_due_dt;

-- 3.3 Vérification de la cohérence financière : Montant Ventes = Quantité * Prix Unitaire
-- Résultat attendu : 0 ligne (Aucun écart de calcul, montant nul, négatif ou valeur manquante)
SELECT DISTINCT
    sls_sales,
    sls_quantity,
    sls_price
FROM silver.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
   OR sls_sales IS NULL
   OR sls_quantity IS NULL
   OR sls_price IS NULL
   OR sls_sales <= 0
   OR sls_quantity <= 0
   OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price;


-- ====================================================================
-- SECTION 4 : Audit de la table 'silver.erp_cust_az12'
-- ====================================================================

-- 4.1 Détection des dates de naissance aberrantes ou hors limites (bdate)
-- Résultat attendu : Dates de naissance réalistes (comprises entre 1924-01-01 et la date du jour)
SELECT DISTINCT
    bdate
FROM silver.erp_cust_az12
WHERE bdate < '1924-01-01'
   OR bdate > GETDATE();

-- 4.2 Validation de la standardisation du genre ERP (gen)
-- Résultat attendu : Liste distincte propre ('Male', 'Female', 'n/a')
SELECT DISTINCT
    gen
FROM silver.erp_cust_az12;


-- ====================================================================
-- SECTION 5 : Audit de la table 'silver.erp_loc_a101'
-- ====================================================================

-- 5.1 Validation de la normalisation des noms de pays (cntry)
-- Résultat attendu : Liste alphabétique propre de pays complets (ex: 'Germany', 'United States', 'n/a')
SELECT DISTINCT
    cntry
FROM silver.erp_loc_a101
ORDER BY cntry;


-- ====================================================================
-- SECTION 6 : Audit de la table 'silver.erp_px_cat_g1v2'
-- ====================================================================

-- 6.1 Contrôle de propreté des champs textuels (cat, subcat, maintenance)
-- Résultat attendu : 0 ligne (Aucun espace superflu en début/fin de chaîne)
SELECT
    *
FROM silver.erp_px_cat_g1v2
WHERE cat != TRIM(cat)
   OR subcat != TRIM(subcat)
   OR maintenance != TRIM(maintenance);

-- 6.2 Validation de la standardisation des niveaux de maintenance
-- Résultat attendu : Valeurs distinctes nettoyées
SELECT DISTINCT
    maintenance
FROM silver.erp_px_cat_g1v2;
