/*
    enable change tracking on the tables
    this script is idempotent
	run it in the context of the correct db

	add any new tables you need to metadata.CTTABLES in code below and rerun the script
	
	"removes" are not handled, yet

*/

GO
SET NOCOUNT ON
GO

--reset table
DELETE FROM metadata.CTTABLES;

--insert new/removed tables here
--setting LastSyncVersion to -1 means "start over with a full table pull"
INSERT INTO metadata.CTTABLES (schemaname, tblname, is_enabled, LastSyncVersion, NextSyncVersion)VALUES ('dbo','Employee', 1, -1, -1);
INSERT INTO metadata.CTTABLES (schemaname, tblname, is_enabled, LastSyncVersion, NextSyncVersion)VALUES ('dbo','Payroll', 1, -1, -1);

DECLARE @exec_str varchar(1000);

--add new tables to CT process
DECLARE curAdds CURSOR FOR 
	SELECT 'ALTER TABLE ' + ctt.schemaname + '.' + ctt.tblname + ' ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);'
	FROM metadata.CTTABLES ctt
	LEFT JOIN sys.change_tracking_tables sctt
	ON object_id(ctt.schemaname + '.' + ctt.tblname) = sctt.object_id
	WHERE ctt.is_enabled = 1 
	AND sctt.object_id IS NULL;
OPEN curAdds
FETCH NEXT FROM curAdds INTO @exec_str;
WHILE (@@FETCH_STATUS = 0)
BEGIN
	EXEC (@exec_str);
	FETCH NEXT FROM curAdds INTO @exec_str;
END;
CLOSE curAdds;
DEALLOCATE curAdds;


/*
SELECT OBJECT_NAME (object_id), * 
FROM sys.change_tracking_tables 
SELECT * FROM metadata.CTTABLES;
*/
