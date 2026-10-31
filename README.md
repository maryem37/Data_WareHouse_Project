# 🏗️ Enterprise Data Warehouse & Analytics Project

[![SQL Server](https://img.shields.io/badge/SQL%20Server-CC292B?style=for-the-badge&logo=microsoftsqlserver&logoColor=white)](https://www.microsoft.com/en-us/sql-server/)
[![SSMS](https://img.shields.io/badge/SSMS-0078D4?style=for-the-badge&logo=microsoft&logoColor=white)](https://docs.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms)
[![Architecture](https://img.shields.io/badge/Architecture-Medallion-gold?style=for-the-badge)](#-data-architecture)
[![Git](https://img.shields.io/badge/Git-F05032?style=for-the-badge&logo=git&logoColor=white)](https://git-scm.com/)

An end-to-end modern data warehousing solution built on **SQL Server** using the **Medallion Architecture** (Bronze, Silver, Gold). This project integrates raw datasets from disparate ERP and CRM systems into a unified Star Schema data model to drive business analytics and reporting on customer behavior, product performance, and sales trends.

---

## 📖 Project Overview

This project covers the full lifecycle of modern data warehousing and business intelligence:

* **Architecture Design**: Implementing a structured 3-layer warehouse architecture (Bronze, Silver, Gold).
* **ETL Pipeline Development**: Extracting raw CSV files, transforming and cleansing data, and loading into modeled layers.
* **Data Modeling**: Designing dimensional models (Fact and Dimension tables) optimized for analytical performance.
* **Business Intelligence & SQL Analytics**: Querying business-ready data to answer key business performance questions.

---

## 🏗️ Data Architecture

The pipeline follows the **Medallion Architecture** pattern to guarantee data freshness, lineage, and high data quality:

              +-------------------------------------------------+
              |                   SOURCE DATA                   |
              |          ERP System & CRM System (CSV)          |
              +------------------------+------------------------+
                                       |
                                       v
              +-------------------------------------------------+
              |                  BRONZE LAYER                   |
              |        Raw Data Ingestion (SQL Server)          |
              +------------------------+------------------------+
                                       |
                                       v
              +-------------------------------------------------+
              |                  SILVER LAYER                   |
              |     Cleansing, Standardization, & Normalization |
              +------------------------+------------------------+
                                       |
                                       v
              +-------------------------------------------------+
              |                   GOLD LAYER                    |
              |     Dimensional Modeling (Star Schema Data)     |
              +------------------------+------------------------+
                                       |
                                       v
              +-------------------------------------------------+
              |                ANALYTICS & BI                   |
              |    SQL Reporting, Dashboards, & Insights        |
              +-------------------------------------------------+
  | Layer | Type | Description |
| :--- | :--- | :--- |
| **Bronze** | Raw Ingestion | Stores raw source data standardly as-is from CRM & ERP CSV inputs into SQL Server. |
| **Silver** | Cleaned & Transformed | Applies data cleansing, data type enforcement, standardization, and deduplication. |
| **Gold** | Analytics Ready | Houses final Star Schema dimensional models (Facts & Dimensions) optimized for reporting. |

---

## 🚀 Project Requirements

### 1. Building the Data Warehouse (Data Engineering)
* **Data Sources**: Ingest raw datasets from two distinct source systems (**ERP** and **CRM**) provided as flat CSV files.
* **Data Quality**: Detect and resolve missing values, duplicate entries, data type inconsistencies, and structural issues during the Silver layer transformation.
* **Integration**: Combine disparate sources into a cohesive, user-friendly relational model optimized for ad-hoc analytical queries.
* **Scope**: Focus exclusively on the latest dataset slice (no historization/SCD Type 2 required).
* **Documentation**: Provide clear data dictionaries, entity-relationship diagrams (ERD), and pipeline documentation.

### 2. Business Intelligence & Analytics (Data Analysis)
Develop advanced, optimized SQL queries to extract key business insights:
* **Customer Behavior**: Analyze customer acquisition, retention, lifetime value, and demographic segmentation.
* **Product Performance**: Evaluate top/bottom-performing products, sales volume, return rates, and category growth.
* **Sales Trends**: Identify seasonal revenue variations, regional performance, and period-over-period sales velocity.

---

## 🛠️ Tools & Technologies

* **Database Engine**: SQL Server
* **IDE / Management**: SQL Server Management Studio (SSMS)
* **Version Control**: Git & GitHub
* **Diagramming**: [draw.io](https://app.diagrams.net/) (Architecture and Data Model Diagrams)
* **Project Management**: Notion (Task tracking and process documentation)

---

## 📁 Repository Structure

```text
.
├── 00_setup/                  # SQL Server & SSMS installation & database initialization scripts
├── 01_bronze/                 # DDls for bronze tables & bulk ingestion SQL scripts
├── 02_silver/                 # Cleansing scripts, transformations, and Silver layer DDLs
├── 03_gold/                   # Dimensional modeling scripts (Star Schema Facts & Dimensions)
├── 04_analytics/              # SQL queries answering core business, sales, & product questions
├── docs/                      # Architecture diagrams, ERD files (draw.io), and Data Dictionary
│   ├── architecture_diagram.png
│   └── data_model_erd.png
├── data/                      # Sample or source CSV files (ERP & CRM)
└── README.md                  # Project documentation            
              
