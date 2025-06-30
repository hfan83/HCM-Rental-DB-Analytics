USE master;
GO

-- ========================================
-- 1. TẠO LOGIN & USER
-- ========================================
CREATE OR ALTER PROCEDURE sp_CreateNewLogin
    @LoginName varchar(50),
    @Password nvarchar(50),
    @CheckExpiration bit = 0,
    @CheckPolicy bit = 0
AS
BEGIN
    DECLARE @SQL nvarchar(max)
    SET @SQL = 'CREATE LOGIN ' + QUOTENAME(@LoginName) +
               ' WITH PASSWORD = ' + QUOTENAME(@Password, '''') +
               ', CHECK_EXPIRATION = ' + CASE WHEN @CheckExpiration = 1 THEN 'ON' ELSE 'OFF' END +
               ', CHECK_POLICY = ' + CASE WHEN @CheckPolicy = 1 THEN 'ON' ELSE 'OFF' END;
    EXEC sp_executesql @SQL;
END
GO

USE PhongTro;
GO

CREATE OR ALTER PROCEDURE sp_CreateNewUser
    @UserName varchar(50),
    @LoginName varchar(50)
AS
BEGIN
    DECLARE @SQL nvarchar(max)
    SET @SQL = 'CREATE USER ' + QUOTENAME(@UserName) + ' FOR LOGIN ' + QUOTENAME(@LoginName);
    EXEC sp_executesql @SQL;
END
GO

CREATE OR ALTER PROCEDURE sp_CreateLoginAndUser
    @Name varchar(50),
    @Password nvarchar(50)
AS
BEGIN
    EXEC master.dbo.sp_CreateNewLogin @Name, @Password;
    EXEC sp_CreateNewUser @Name, @Name;
END
GO

-- Tạo các user
EXEC sp_CreateLoginAndUser 'Admin', 'admin123';
EXEC sp_CreateLoginAndUser 'DE', 'de123';
EXEC sp_CreateLoginAndUser 'DA', 'da123';
GO

-- ========================================
-- 2. TẠO ROLES VÀ CẤP QUYỀN
-- ========================================
CREATE ROLE Admin_Role;
CREATE ROLE DE_Role;
CREATE ROLE DA_Role;
GO

CREATE OR ALTER PROCEDURE sp_AssignAdminPermissions @UserName NVARCHAR(50) AS
BEGIN
    EXEC sp_addrolemember 'Admin_Role', @UserName;
    EXEC sp_executesql 'GRANT CONTROL TO ' + QUOTENAME(@UserName);
END
GO

CREATE OR ALTER PROCEDURE sp_AssignDEPermissions @UserName NVARCHAR(50) AS
BEGIN
    EXEC sp_addrolemember 'DE_Role', @UserName;
    EXEC sp_executesql 'GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO ' + QUOTENAME(@UserName);
    EXEC sp_executesql 'GRANT CREATE PROCEDURE, ALTER, DELETE TO ' + QUOTENAME(@UserName);
    EXEC sp_executesql 'GRANT CREATE FUNCTION TO ' + QUOTENAME(@UserName);
END
GO

CREATE OR ALTER PROCEDURE sp_AssignDAPermissions @UserName NVARCHAR(50) AS
BEGIN
    EXEC sp_addrolemember 'DA_Role', @UserName;
    EXEC sp_executesql 'GRANT SELECT ON SCHEMA::dbo TO ' + QUOTENAME(@UserName);
END
GO

-- Phân quyền
EXEC sp_AssignAdminPermissions 'Admin';
EXEC sp_AssignDEPermissions 'DE';
EXEC sp_AssignDAPermissions 'DA';
GO

-- ========================================
-- 3. THỦ TỤC XEM PERMISSIONS
-- ========================================
CREATE OR ALTER PROCEDURE GeneratePermissionsSummary AS
BEGIN
    CREATE TABLE #PermissionsSummary (PermissionName NVARCHAR(100), Level NVARCHAR(20), Admin NVARCHAR(10), DE NVARCHAR(10), DA NVARCHAR(10));
    DECLARE @Users TABLE (UserName NVARCHAR(50)); INSERT INTO @Users VALUES ('Admin'), ('DE'), ('DA');
    DECLARE @AllPermissions TABLE (PermissionName NVARCHAR(100), Level NVARCHAR(20));
    INSERT INTO @AllPermissions SELECT DISTINCT permission_name, 'SERVER' FROM sys.fn_builtin_permissions('SERVER')
    UNION ALL SELECT permission_name, 'DATABASE' FROM sys.fn_builtin_permissions('DATABASE')
    UNION ALL SELECT permission_name, 'OBJECT' FROM sys.fn_builtin_permissions('OBJECT');

    DECLARE @TempPermissions TABLE (PermissionName NVARCHAR(100), UserName NVARCHAR(50), Level NVARCHAR(20));
    DECLARE @User NVARCHAR(50);
    DECLARE UserCursor CURSOR FOR SELECT UserName FROM @Users;
    OPEN UserCursor; FETCH NEXT FROM UserCursor INTO @User;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXECUTE AS USER = @User;
        INSERT INTO @TempPermissions
        SELECT p.permission_name, @User, 'OBJECT' FROM sys.objects o CROSS APPLY fn_my_permissions(QUOTENAME(o.name), 'OBJECT') p WHERE schema_name(o.schema_id) = 'dbo'
        UNION ALL SELECT p.permission_name, @User, 'DATABASE' FROM sys.fn_my_permissions(NULL, 'DATABASE') p
        UNION ALL SELECT p.permission_name, @User, 'SERVER' FROM sys.fn_my_permissions(NULL, 'SERVER') p;
        REVERT; FETCH NEXT FROM UserCursor INTO @User;
    END
    CLOSE UserCursor; DEALLOCATE UserCursor;

    INSERT INTO #PermissionsSummary
    SELECT p.PermissionName, p.Level,
           CASE WHEN EXISTS (SELECT 1 FROM @TempPermissions WHERE UserName = 'Admin' AND PermissionName = p.PermissionName AND Level = p.Level) THEN 'x' ELSE '' END,
           CASE WHEN EXISTS (SELECT 1 FROM @TempPermissions WHERE UserName = 'DE' AND PermissionName = p.PermissionName AND Level = p.Level) THEN 'x' ELSE '' END,
           CASE WHEN EXISTS (SELECT 1 FROM @TempPermissions WHERE UserName = 'DA' AND PermissionName = p.PermissionName AND Level = p.Level) THEN 'x' ELSE '' END
    FROM @AllPermissions p
    WHERE EXISTS (SELECT 1 FROM @TempPermissions WHERE PermissionName = p.PermissionName AND Level = p.Level);

    SELECT * FROM #PermissionsSummary;
END
GO

EXEC GeneratePermissionsSummary;
GO

-- ========================================
-- 4. THU HỒI QUYỀN
-- ========================================
CREATE OR ALTER PROCEDURE sp_RevokeAllPermissions @UserName NVARCHAR(50) AS
BEGIN
    CREATE TABLE #UserPermissions (Permission NVARCHAR(50), ObjectName NVARCHAR(255));
    INSERT INTO #UserPermissions
    SELECT permission_name, class_desc + '::' + OBJECT_NAME(major_id)
    FROM sys.database_permissions dp
    JOIN sys.database_principals dpn ON dp.grantee_principal_id = dpn.principal_id
    WHERE dpn.name = @UserName;

    DECLARE @Permission NVARCHAR(50), @ObjectName NVARCHAR(255), @SQL NVARCHAR(MAX);
    DECLARE cur CURSOR FOR SELECT Permission, ObjectName FROM #UserPermissions;
    OPEN cur; FETCH NEXT FROM cur INTO @Permission, @ObjectName;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @SQL = 'REVOKE ' + @Permission + ' ON ' + @ObjectName + ' FROM ' + QUOTENAME(@UserName);
        EXEC sp_executesql @SQL;
        FETCH NEXT FROM cur INTO @Permission, @ObjectName;
    END
    CLOSE cur; DEALLOCATE cur;
    DROP TABLE #UserPermissions;
END
GO

EXEC sp_RevokeAllPermissions 'DA';
GO
