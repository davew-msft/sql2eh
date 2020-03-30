/*
	This procedure is called from the orchestrator (ADF or python).  Gets the "latest" data for the table.
	
	Steps:  
	--It checks that change tracking is "working" and we haven't lost any data.  
	--determines if a full pull is necessary 
	--gets the data required
	--saves CHANGE_TRACKING_CURRENT_VERSION() to NextSyncVersion so this can be called transactionally AFTER the data gets copied
		-- see metadata.SetLastSyncVersion


*/

IF NOT EXISTS (select * from sys.objects where object_id = object_id('metadata.GetLatestTableData'))
BEGIN
	EXEC('CREATE PROCEDURE metadata.GetLatestTableData AS BEGIN SELECT NULL; END;');
END;
GO
ALTER PROCEDURE metadata.GetLatestTableData 
	@schemaname varchar(256),
	@tblname varchar(256)
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	BEGIN TRAN 

	DECLARE @LastSyncVersion BIGINT = -1, @EarliestVersion BIGINT = -1, @exec_str VARCHAR(8000), @token VARCHAR(8000), @CHANGE_TRACKING_CURRENT_VERSION BIGINT;
	SELECT @token = @schemaname + '.' + @tblname;

	--get "current"
	SELECT @CHANGE_TRACKING_CURRENT_VERSION = CHANGE_TRACKING_CURRENT_VERSION();

	--get LastSyncVersion
	SELECT @LastSyncVersion = LastSyncVersion
	FROM metadata.CTTABLES 
	WHERE schemaname = @schemaname
	AND tblname = @tblname
	AND is_enabled = 1;

	--SELECT @LastSyncVersion;

	--is it "safe" to pull transactions from the LastSyncVersion
	--the min_valid_version for the table must be > what we last pulled
	--don't be concerned if this is a full pull (-1)
	SELECT @EarliestVersion = ctt.min_valid_version
	FROM sys.objects so
	JOIN sys.change_tracking_tables ctt ON so.object_id = ctt.object_id 
	WHERE so.schema_id = schema_id(@schemaname)
	AND so.object_id = object_id(@tblname)	

	IF ((@LastSyncVersion <> - 1) AND @EarliestVersion > @LastSyncVersion)
	BEGIN
		RAISERROR ('Last Sync is older than change tracking, need to do a full pull of table stream.',16,1);
		RETURN 1;
	END;

	--full or incremental? 
	--Full will have a LastSyncVersion of -1 initially
	IF @LastSyncVersion = -1
	BEGIN
		SELECT @exec_str = REPLACE(FullPullQuery,'%TABLE%',@token) FROM metadata.CTTABLES WHERE schemaname = @schemaname AND tblname = @tblname;
		PRINT @exec_str;
		EXEC (@exec_str)
	END;
	ELSE
	BEGIN
		--incremental via change tracking
		SELECT @exec_str = REPLACE(REPLACE(IncrementalQuery,'%TABLE%',@token),'%LastSyncVersion%',convert(varchar(100),LastSyncVersion)) FROM metadata.CTTABLES WHERE schemaname = @schemaname AND tblname = @tblname;
		--SELECT @exec_str = REPLACE(@exec_str,'base.*','TOP 100 base.*')
		PRINT @exec_str;
		EXEC (@exec_str)
	END;

	

	--update new HWM
	UPDATE metadata.CTTABLES 
		SET NextSyncVersion = @CHANGE_TRACKING_CURRENT_VERSION 
	WHERE schemaname = @schemaname
	AND tblname = @tblname
	AND is_enabled = 1;
	
	COMMIT;
END;
GO

/*
Unit Tests

update metadata.CTTABLES SET LastSyncVersion = -1 where tblname = 'KNVH';
EXEC metadata.GetLatestTableData 'dbo', 'Employee'

select * from metadata.CTTABLES;
select CHANGE_TRACKING_CURRENT_VERSION();

EXEC metadata.GetLatestTableData 'dbo', 'Employee'

select * from dbo.Employee;
update dbo.Employee SET FirstName = 'David' WHERE EmpID = 1
SELECT CHANGE_TRACKING_CURRENT_VERSION();



*/

