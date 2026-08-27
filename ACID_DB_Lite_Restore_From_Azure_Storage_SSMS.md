# Restore DB from Azure Storage Account to Azure SQL Server VM (SAS + SSMS)

## Overview
This runbook restores a database backup file from an Azure Storage Account container onto a SQL Server running on an Azure VM, using a SAS/connection string and SQL Server Management Studio (SSMS).

> **Variable to replace throughout this doc:** `Acid2_Prod` — replace with the actual target database name for your environment before running any commands.

---

## Steps

1. **Get Storage Account connection string**
   Login to Azure Portal → Storage Accounts → Access Keys → Copy Connection String.
   *No variable to replace — just copy the connection string as-is.*

2. **Connect to Storage Account from the VM**
   RDP to the Azure SQL Server VM → Open Azure Storage Explorer → Right-click on the Storage Account (SA) → Select SA or Services → Connection string → Connect using the copied string.
   *Replace: the connection string pasted here must be the one copied in Step 1 for your specific Storage Account.*

3. **Download the backup file**
   Go to SA → Container → Latest Backup → Download.
   *Replace: select the correct/latest `.bak` file matching the DB you intend to restore (filename will vary per environment/date).*

4. **Place backup file on the SQL Server**
   Copy the downloaded backup file to:
   `C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup`
   *Replace: `MSSQL16.MSSQLSERVER` may differ if your SQL Server instance name/version is different — confirm the actual instance path on the target VM.*

5. **Login to SSMS**
   Open SSMS → Login using Admin credentials.
   *Replace: use the correct admin credentials for the target SQL Server instance.*

6. **Set database to single-user mode**
   ```sql
   USE master;
   GO

   ALTER DATABASE [Acid2_Prod]
   SET SINGLE_USER
   WITH ROLLBACK IMMEDIATE;
   GO
   ```
   *Replace: `Acid2_Prod` with your actual target database name.*

7. **Start the restore**
   Right-click on Databases → Restore Databases → Select Device → Select the backup file uploaded to the path in Step 4.
   *Replace: choose the correct backup file matching the DB you're restoring.*

8. **Set destination database name**
   On the same Restore Database page, edit the Destination database field to the DB name present in the target environment.
   *Replace: destination DB name must match the actual environment's DB name (e.g., `Acid2_Prod`).*

9. **Enable overwrite**
   Go to Options → check "Overwrite the existing database (WITH REPLACE)".
   *No variable to replace — just ensure this checkbox is enabled.*

10. **Run the restore**
    Click OK/Run and wait until the restore completes.
    *No variable to replace.*

11. **Set database back to multi-user mode**
    ```sql
    USE master;
    GO

    ALTER DATABASE [Acid2_Prod]
    SET MULTI_USER;
    GO
    ```
    *Replace: `Acid2_Prod` with your actual target database name.*

12. **Verify restore status**
    ```sql
    SELECT
        name,
        user_access_desc,
        state_desc
    FROM sys.databases
    WHERE name = 'Acid2_Prod';
    ```
    *Replace: `Acid2_Prod` with your actual target database name.*

---

## Troubleshooting: DB In Use / Active Connections

If Step 6 (SINGLE_USER) fails because the database is in use, check active connections first:

```sql
SELECT
    s.session_id,
    s.login_name,
    s.host_name,
    s.program_name,
    DB_NAME(s.database_id) AS database_name,
    s.status
FROM sys.dm_exec_sessions s
WHERE s.database_id = DB_ID('Acid2_Prod');
```
*Replace: `Acid2_Prod` with your actual target database name.*

Review the active sessions and disconnect/kill them as needed before retrying Step 6.

---

## Result
Once Step 10 completes successfully, the target database will be restored and will overwrite the existing database with the contents of the backup file.
