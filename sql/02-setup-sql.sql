DECLARE @retention_period INT = 10;
DECLARE @exec_str varchar(1000);

IF NOT EXISTS (
	SELECT db_name(database_id) , *
	FROM sys.change_tracking_databases
    WHERE database_id = db_id()
)
BEGIN
	SELECT @exec_str = 'ALTER DATABASE ' + quotename(db_name())  + ' SET CHANGE_TRACKING = ON (CHANGE_RETENTION = '  + convert(varchar(100),@retention_period) + ' DAYS, AUTO_CLEANUP = ON)'
	EXEC (@exec_str);
END;

IF NOT EXISTS (
	SELECT db_name(database_id) , *
	FROM sys.change_tracking_databases
	WHERE retention_period = @retention_period
)
BEGIN
	SELECT @exec_str = 'ALTER DATABASE ' + quotename(db_name()) + ' SET CHANGE_TRACKING (CHANGE_RETENTION = ' + convert(varchar(100),@retention_period) + ' DAYS)'
	EXEC (@exec_str);
END;

GO
IF NOT EXISTS (select * from sys.schemas where name = 'metadata')
BEGIN
	EXEC ('CREATE SCHEMA metadata');
END;
GO

IF NOT EXISTS (select * from sys.objects where object_id = object_id('metadata.CTTABLES'))
BEGIN
	CREATE TABLE metadata.CTTABLES (
		schemaname varchar(100),
		tblname varchar(100),
		is_enabled bit NOT NULL,
		LastSyncVersion BIGINT,
		NextSyncVersion BIGINT,
		FullPullQuery varchar(max) NULL,
		IncrementalQuery varchar(max) NULL
	);
END;

