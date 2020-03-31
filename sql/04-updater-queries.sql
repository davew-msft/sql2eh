/*
    adds the sync queries to metadata.CTTABLES

    these are called by metadata.GetLatestTableData
    
*/

--USE PRD;
GO
SET NOCOUNT ON
GO
DECLARE @FullPullQuery varchar(max), @IncrementalQuery varchar(max), @FilterQuery varchar(max);
SELECT @FullPullQuery = 'SELECT ''%TABLE%'' as object, * FROM %TABLE% ';

--reset table
UPDATE metadata.CTTABLES SET 
    FullPullQuery = NULL,
    IncrementalQuery = NULL
;

--for each table

--dbo.Employee
SELECT @IncrementalQuery = '
SELECT ''%TABLE%'' as object, base.* 
FROM %TABLE% base
JOIN (
    SELECT DISTINCT 
        EmpID
    FROM CHANGETABLE (CHANGES %TABLE%, %LastSyncVersion%) chgs
	WHERE chgs.SYS_CHANGE_OPERATION IN (''I'',''U'')
) chgs
ON base.EmpID = chgs.EmpID;
';
UPDATE metadata.CTTABLES SET
	FullPullQuery = @FullPullQuery
	,IncrementalQuery = @IncrementalQuery
WHERE schemaname = 'dbo' AND tblname = 'Employee';

--dbo.Payroll
SELECT @IncrementalQuery = '
SELECT ''%TABLE%'' as object, base.* 
FROM %TABLE% base
JOIN (
    SELECT DISTINCT 
        PayrollID
    FROM CHANGETABLE (CHANGES %TABLE%, %LastSyncVersion%) chgs
	WHERE chgs.SYS_CHANGE_OPERATION IN (''I'',''U'')
) chgs
ON base.PayrollID = chgs.PayrollID;
';
UPDATE metadata.CTTABLES SET
	FullPullQuery = @FullPullQuery
	,IncrementalQuery = @IncrementalQuery
WHERE schemaname = 'dbo' AND tblname = 'Payroll';


select * from metadata.CTTABLES;
