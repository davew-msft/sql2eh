/*
	This procedure is called from the orchestrator (ADF or python).
	It sets LastSyncVersion = NextSyncVersion and sets NextSyncVersion = -1

	There is no way to pass an OUTPUT param from a stored proc and use it elsewhere as param in ADF.
	metadata.GetLatestTableData persists the "next" val and then we call this AFTER ADF (or python) actually
	persists the data to the destination.  

	This helps the process to be "transactional".  

	We set NextSyncVersion to -1 to indicate that there is no ADF or python pipeline running for the given table.  


*/

IF NOT EXISTS (select * from sys.objects where object_id = object_id('metadata.SetLastSyncVersion'))
BEGIN
	EXEC('CREATE PROCEDURE metadata.SetLastSyncVersion AS BEGIN SELECT NULL; END;');
END;
GO
ALTER PROCEDURE metadata.SetLastSyncVersion 
	@schemaname varchar(256),
	@tblname varchar(256)
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRAN 

	UPDATE metadata.CTTABLES SET 
        LastSyncVersion = NextSyncVersion,
		NextSyncVersion = -1 
	WHERE schemaname = @schemaname
	AND tblname = @tblname
	AND is_enabled = 1;
	
	COMMIT;
END;
GO




/*
	metadata.SetLastSyncVersion 'dbo','Employee';
*/
