/* ===========================================================================
   Row-Level Security (RLS) + Column-Level Security (CLS) demo
   Target: the SQL analytics endpoint of Lakehouse LH_Gold (or a Warehouse).
   Run in the Fabric SQL query editor against LH_Gold.

   Demonstrates governance directly on the governed data layer:
     - CLS: hide the sensitive column customer_360.sensitivity_tier from analysts.
     - Dynamic data masking: mask customer_name for non-privileged users.
     - RLS: restrict rows by country unless the user is a sales manager.

   NOTE: Replace the placeholder principals below with real Entra ID users/groups
   from your tenant (e.g. an email like analyst@contoso.com). In Fabric, add users
   to the SQL endpoint and they map to database principals automatically.
   =========================================================================== */

-------------------------------------------------------------------------------
-- 0. Roles (represent personas). Add real users with ALTER ROLE ... ADD MEMBER.
-------------------------------------------------------------------------------
IF DATABASE_PRINCIPAL_ID('SalesManagers') IS NULL
    CREATE ROLE SalesManagers;
IF DATABASE_PRINCIPAL_ID('Analysts') IS NULL
    CREATE ROLE Analysts;
GO

-- Example membership (uncomment + edit):
-- ALTER ROLE SalesManagers ADD MEMBER [manager@contoso.com];
-- ALTER ROLE Analysts      ADD MEMBER [analyst@contoso.com];
-- GO

-------------------------------------------------------------------------------
-- 1. Column-Level Security (CLS)
--    Analysts may read customer_360 but NOT the sensitivity_tier column.
-------------------------------------------------------------------------------
GRANT SELECT ON dbo.customer_360 TO Analysts;
DENY  SELECT ON dbo.customer_360 (sensitivity_tier) TO Analysts;
GO

-------------------------------------------------------------------------------
-- 2. Dynamic Data Masking (DDM)
--    customer_name is partially masked; SalesManagers can be UNMASKed.
-------------------------------------------------------------------------------
ALTER TABLE dbo.customer_360
    ALTER COLUMN customer_name ADD MASKED WITH (FUNCTION = 'partial(3,"****",0)');
GO
-- Let managers see unmasked values:
GRANT UNMASK TO SalesManagers;
GO

-------------------------------------------------------------------------------
-- 3. Row-Level Security (RLS)
--    Non-managers see only United States rows; SalesManagers see all rows.
--    Swap the predicate for a mapping table for true per-user filtering.
-------------------------------------------------------------------------------
IF SCHEMA_ID('Security') IS NULL
    EXEC('CREATE SCHEMA Security');
GO

CREATE OR ALTER FUNCTION Security.fn_customer_country_filter(@country AS NVARCHAR(50))
    RETURNS TABLE
    WITH SCHEMABINDING
AS
    RETURN
        SELECT 1 AS fn_result
        WHERE
            IS_ROLEMEMBER('SalesManagers') = 1   -- managers: unrestricted
            OR IS_ROLEMEMBER('db_owner')   = 1   -- admins:   unrestricted
            OR @country = N'United States';      -- everyone else: US only
GO

CREATE OR ALTER SECURITY POLICY Security.CustomerRowFilter
    ADD FILTER PREDICATE Security.fn_customer_country_filter(country)
        ON dbo.customer_360
    WITH (STATE = ON);
GO

-------------------------------------------------------------------------------
-- 4. How to test
-------------------------------------------------------------------------------
-- As a SalesManager  -> all rows, unmasked names, sensitivity_tier visible.
-- As an Analyst      -> US rows only, masked names, sensitivity_tier DENIED.
--
-- Quick checks:
--   SELECT COUNT(*) FROM dbo.customer_360;                 -- row count differs by persona
--   SELECT customer_id, customer_name FROM dbo.customer_360;-- masking differs by persona
--   SELECT sensitivity_tier FROM dbo.customer_360;          -- errors for Analysts (CLS)
--
-- To disable the RLS policy during a reset:
--   ALTER SECURITY POLICY Security.CustomerRowFilter WITH (STATE = OFF);
