
CREATE TABLE [dbo].[Employee](
	[EmpID] [int] NOT NULL PRIMARY KEY,
	[NamePrefix] [varchar](20) NULL,
	[FirstName] [varchar](50) NULL,
	[MiddleInitial] [varchar](1) NULL,
	[LastName] [varchar](50) NULL,
	[Gender] [varchar](1) NULL,
	[EMail] [varchar](200) NULL
) ON [PRIMARY]
GO



CREATE TABLE [dbo].[Payroll](
    PayrollID int NOT NULL PRIMARY KEY,
	[EmpId] int NOT NULL,
	PayDate datetime NOT NULL,
    NetPay decimal(10,2) NOT NULL
) ON [PRIMARY]
GO

--sample data 
INSERT INTO Employee VALUES(1,'Mr','Dave','K','Wentzel','M','davew@microsoft.com');
INSERT INTO Employee VALUES(2,'Mr','Steve','K','Smith','M','ssmith@microsoft.com');
INSERT INTO Payroll VALUES (1,1,'1/15/2019',5)
INSERT INTO Payroll VALUES (2,2,'1/15/2019',50)
INSERT INTO Payroll VALUES (3,1,'1/31/2019',5)
INSERT INTO Payroll VALUES (4,2,'1/31/2019',50)