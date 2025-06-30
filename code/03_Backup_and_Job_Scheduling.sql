USE master;
GO

-- ========================================
-- 1. TẠO THƯ MỤC LƯU BACKUP
-- ========================================
EXEC master.dbo.xp_create_subdir 'D:\Backup\QTCSDL\Full';
EXEC master.dbo.xp_create_subdir 'D:\Backup\QTCSDL\Diff';
GO

-- ========================================
-- 2. STORED PROCEDURES BACKUP
-- ========================================
CREATE OR ALTER PROCEDURE sp_BackupR3_Full AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @BackupFile NVARCHAR(255)
    SET @BackupFile = 'D:\Backup\QTCSDL\Full\QTCSDL_FULL_' + FORMAT(GETDATE(),'yyyyMMdd_HHmmss') + '.bak'

    DBCC CHECKDB('R3') WITH NO_INFOMSGS

    BACKUP DATABASE R3
    TO DISK = @BackupFile
    WITH COMPRESSION, INIT, NAME = 'R3-Full Database Backup', STATS = 10, CHECKSUM, RETAINDAYS = 30;
END
GO

CREATE OR ALTER PROCEDURE sp_BackupR3_Diff AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @BackupFile NVARCHAR(255)
    SET @BackupFile = 'D:\Backup\QTCSDL\Diff\QTCSDL_DIFF_' + FORMAT(GETDATE(),'yyyyMMdd_HHmmss') + '.bak'

    BACKUP DATABASE R3
    TO DISK = @BackupFile
    WITH DIFFERENTIAL, COMPRESSION, INIT, NAME = 'R3-Differential Backup', STATS = 10, CHECKSUM, RETAINDAYS = 2;
END
GO

CREATE OR ALTER PROCEDURE sp_CleanupBackups AS
BEGIN
    DECLARE @cmd VARCHAR(255)
    SET @cmd = 'FORFILES /P "D:\Backup\QTCSDL\Full" /M *.bak /D -30 /C "CMD /C DEL @path"'
    EXEC master.dbo.xp_cmdshell @cmd

    SET @cmd = 'FORFILES /P "D:\Backup\QTCSDL\Diff" /M *.bak /D -2 /C "CMD /C DEL @path"'
    EXEC master.dbo.xp_cmdshell @cmd
END
GO

-- ========================================
-- 3. TẠO SQL AGENT JOBS
-- ========================================
USE msdb;
GO

-- JOB FULL BACKUP
EXEC sp_add_job @job_name = N'Full_Backup_Job';
EXEC sp_add_jobstep @job_name = N'Full_Backup_Job', @step_name = N'Full Backup',
    @subsystem = N'TSQL', @command = N'USE R3; EXEC sp_BackupR3_Full;';
EXEC sp_add_jobschedule @job_name = N'Full_Backup_Job', @name = N'1months_Full_Backup',
    @freq_type = 4, @freq_interval = 1, @active_start_time = 030300;
EXEC sp_add_jobserver @job_name = N'Full_Backup_Job', @server_name = N'(LOCAL)';
GO

-- JOB DIFF BACKUP
EXEC sp_add_job @job_name = N'Diff_Backup_Job';
EXEC sp_add_jobstep @job_name = N'Diff_Backup_Job', @step_name = N'Differential Backup',
    @subsystem = N'TSQL', @command = N'USE R3; EXEC sp_BackupR3_Diff;';
EXEC sp_add_jobschedule @job_name = N'Diff_Backup_Job', @name = N'2days_Diff_Backup',
    @freq_type = 4, @freq_interval = 2, @active_start_time = 025700;
EXEC sp_add_jobserver @job_name = N'Diff_Backup_Job', @server_name = N'(LOCAL)';
GO

-- JOB CLEANUP
EXEC sp_add_job @job_name = N'Cleanup_Job';
EXEC sp_add_jobstep @job_name = N'Cleanup_Job', @step_name = N'Cleanup Old Backups',
    @subsystem = N'TSQL', @command = N'USE R3; EXEC sp_CleanupBackups;';
EXEC sp_add_jobschedule @job_name = N'Cleanup_Job', @name = N'Daily_Cleanup',
    @freq_type = 4, @freq_interval = 1, @active_start_time = 014500;
EXEC sp_add_jobserver @job_name = N'Cleanup_Job', @server_name = N'(LOCAL)';
GO

-- ========================================
-- 4. FUNCTION XEM JOB HISTORY
-- ========================================
CREATE OR ALTER FUNCTION fn_JobHistory(@JobName NVARCHAR(128) = NULL)
RETURNS TABLE AS
RETURN
    SELECT
        j.name AS JobName,
        h.run_date,
        h.run_time,
        h.run_duration,
        h.message,
        h.step_id,
        h.step_name
    FROM msdb.dbo.sysjobhistory h
    INNER JOIN msdb.dbo.sysjobs j ON h.job_id = j.job_id
    WHERE (@JobName IS NULL OR j.name = @JobName);
GO

-- Xem lịch sử jobs
SELECT * FROM dbo.fn_JobHistory('Full_Backup_Job') ORDER BY run_date DESC, run_time DESC;
SELECT * FROM dbo.fn_JobHistory('Diff_Backup_Job') ORDER BY run_date DESC, run_time DESC;
SELECT * FROM dbo.fn_JobHistory('Cleanup_Job') ORDER BY run_date DESC, run_time DESC;
GO

-- ========================================
-- 5. RESTORE DATABASE MẪU
-- ========================================
RESTORE DATABASE R3
FROM DISK = 'D:\Backup\QTCSDL\Full\QTCSDL_FULL_20241116_003849.bak'
WITH REPLACE;
GO
l_Backup_Job') ORDER BY run_date DESC, run_time DESC;
SELECT * FROM dbo.fn_JobHistory('Diff_Backup_Job') ORDER BY run_date DESC, run_time DESC;
SELECT * FROM dbo.fn_JobHistory('Cleanup_Job') ORDER BY run_date DESC, run_time DESC;


-- Thủ tục tạo restore database
use msdb
RESTORE DATABASE R3
FROM DISK = 'D:\Backup\QTCSDL\Full\QTCSDL_FULL_20241116_003849.bak'
WITH REPLACE;
