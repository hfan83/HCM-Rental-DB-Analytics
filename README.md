# 🏘️ HCM Rental DB & Analytics Pipeline

**Tagline:**  
*A complete end-to-end project that uses SQL-centric data cleaning, automated backups, user permissions, plus Power BI dashboards and machine learning to analyze and predict rental prices in Ho Chi Minh City.*

---

## 📌 Project Overview

This project was developed as a comprehensive exercise for the course *Database Management Systems (MIS3008_48K29.1)* at the University of Economics - University of Danang.  
It focuses on building a robust solution for the rental room market in Ho Chi Minh City, covering:

- 🐍 **Scraping & importing data into Azure SQL**
- 🛠 **Data cleaning & building a relational data model in SQL**
- 💾 **Automating full & differential backups with retention policies**
- 🔐 **Role-based security management with users & granular permissions**
- 📊 **Business dashboards in Power BI**
- 🤖 **Predicting rental prices using machine learning models deployed via Streamlit**

---

## 📂 Project Structure (ordered execution flow)

1️⃣ `01_Scraping_and_Importing_to_Cloud/`  
 - Python scripts to scrape `phongtro123.com` using BeautifulSoup & requests.  
 - Extracts rental details (price, area, address, dates, amenities).  
 - Loads raw data into Azure SQL using `pyodbc`.

2️⃣ `02_Clean_Transform_and_Model.sql`  
 - T-SQL scripts to clean, normalize data:
    - Standardize `price` & `area` units.
    - Extract `district` from unstructured addresses.
    - Convert date strings to proper `DATE` type.
    - Remove unnecessary columns.
 - Builds normalized relational tables: `Room`, `District`, `Amenities_Type`, `Amenities_Details`, `Room_Amenities`.
 
 ![RDM](https://github.com/user-attachments/assets/58c004ca-8c96-4d2e-99da-889ed238d0ba)

3️⃣ `03_Backup_and_Job_Scheduling.sql`  
 - Creates stored procedures for **Full & Differential backups**, plus automatic cleanup of old backup files (30 days full, 2 days diff).  
 - Sets up scheduled jobs via SQL Server Agent for daily full backups, bi-daily differential backups, and daily cleanup.  
 - Adds `fn_JobHistory` function to view execution logs.

4️⃣ `04_User_Roles_and_Permissions.sql`  
 - Creates `Admin`, `Data Engineer (DE)`, `Data Analyst (DA)` users.  
 - Grants granular permissions:
    - `Admin`: full database control
    - `DE`: CRUD + create procedures/functions
    - `DA`: read-only SELECT
 - Includes dynamic procedures to revoke permissions and audit role rights.

5️⃣ `05_Overview_Dashboard.pbix`  
 - Power BI dashboard connected directly to the Azure SQL Database.  
 - Shows key visuals:
    - Average rental prices by district
    - Distribution of area vs price
    - Top listed amenities
    ![Dashboard_image](https://github.com/user-attachments/assets/fb5cef2a-1200-4994-92a3-265008956c98)

6️⃣ `06_Prediction_Modeling/`  
 - Python notebooks to read clean data from Azure, engineer features, and train models (Linear Regression, Random Forest, XGBoost, LightGBM).  
 - Selects **Random Forest** (≈38% R²) as best performer given limited features.  
 - Deploys with Streamlit so users can input room attributes and predict price.

---

## 🔍 Conclusion & Key Insights

- ✅ **Strong DBMS foundation:**  
  Successfully built an automated, secure, cloud-hosted SQL pipeline:
    - Data cleaning & transformation done entirely in T-SQL
    - Normalized relational data model reduces redundancy and improves query efficiency
    - Automated backups & retention ensures robust data protection

- ✅ **Effective security:**  
  With clear separation of roles (Admin / DE / DA), the project ensures data integrity and minimizes unauthorized changes.

- ✅ **Market insights:**  
  Analysis revealed:
    - Rental prices cluster higher in central districts.
    - Listings frequently lack structured data, requiring extensive cleaning and standardization.

- ✅ **Machine learning deployment:**  
  Although Random Forest achieved moderate R² (~38%), the deployment pipeline shows how an end-to-end system can evolve — future work should include more granular location features (distance to universities, transit), room quality, and time series data.

---

## 👨‍🎓 Project Team

| Member                 | Roles & Contributions                  |
|-------------------------|--------------------------------------|
| Phan Truong Huy         | Azure SQL, T-SQL cleaning, schema design, security |
| Tran Quoc Toan          | Web scraping, Power BI dashboard, ML |
| Nguyen Thi Diem Ly      | ML modeling, Streamlit deployment |
| Huynh Phuong Anh        | Backups, job scheduling, permissions management |

Supervised by **Dr. Hoang Nguyen Vu**  
University of Economics - University of Danang

---

🎉 **Thank you for exploring our project!**
