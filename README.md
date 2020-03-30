## SQL-to-EH

This repo demos how to get changes from SQL Server published to an EH.  We take the data and then land it to a data lake.  We use python to extract the data every x mins from SQL Server.  The tables we care about are stored in a metadata table that tracks the Change Tracking information.  Every python runs finds the latest changed data since the previous run.  

This is not complete. 

Assumptions:
* all SQL tables need a PK
* we don't send deletes to EH
* this is not fully transactional, but it is idempotent and it follows "at-least-once" semantics

This will NOT do the initial data copy for existing data.  Solutions:
* use ADF or SSIS or similar
* set each row equal to itself so CT sees it and marks the row for ingestion

## TODO:

* I think this needs a rowcount limiter.  Paging.  How?  EH has 1MBish size limit.  need single message json and not arry of json?
* EH setup scripts
* initial copy
* [manual process finding table primary keys needs fixing](./sql/04-updater-queries.sql)
* one table's pull is done in 1 batch.  Potentially big batches
* python code:
  * probably better if this was in a container
* everything push's to partition 0, put that in the metadata maybe?
* multiple rows are sent simulataneiously as array of json.  is that ok?  


## Setup EH

* need a EH.  
  * Standard
  * everything else is optional.  
  * setup a policy for manage
  * two consumer groups:
    * debug
    * datalake

Note connstring info here (this must be to the EH _not_ the namespace):

Mine:  
`Endpoint=sb://davewdataeng.servicebus.windows.net/;SharedAccessKeyName=mypolicy;SharedAccessKey=78k4G4aL26NmSjEtqZQPS7w26H1XDSVnzhooublUzeQ=;EntityPath=sql2eh`


## Setup SQL

We will use a SQL Server that has Change Tracking enabled .  

Here are the sample scripts, adjust accordingly:

* [Create Sample Items](./sql/01-sample.sql) 
  * these are the objects I'm replicating
* [Setup SQL](./sql/02-setup-sql.sql)
  * sets up CT and the metadata objects
* [Add tables to CT](./sql/03-add-tables.sql)
  * add your tables that you want to "replicate" to the metadata
* [Add the Updater queries to the metadata](./sql/04-updater-queries.sql)
  * this is a manual process for now.  This writes the queries that the python uses to the metadata.  
  * these queries determine what data has changed since the last time we polled
* [metadata.GetLatestTableData](metadata.GetLatestTableData.sql)
  * gets the latest data for the given table
* [metadata.SetLastSyncVersion](metadata.SetLastSyncVersion.sql)

## Setup Python

This is designed to run on-prem.  It does the following:
* Connect to SQL
* figure out what data has changed in the tables specified in the metadata
* wrap that data into an EH message and push the message

I do everything in bash/wsll/ubuntu, here's the steps:

```bash

mkdir -p pysql2eh
cd pysql2eh
python3.6 -m venv .venv
source .venv/bin/activate

# if this generates errors then 
# sudo nano /etc/odbcinst.ini
# clear the file and rerun
sudo apt-get install msodbcsql17


pip install pandas
pip install --upgrade pyodbc --no-cache-dir
pip install azure-eventhub


pip freeze >> requirements.txt




```

Here's the code:    

[sql2eh.py](./py/sql2eh.py)


## Running the Demo

1. Get everything setup above
2. change any connstrings as needed in `config.json`
3. Run the code. 

```bash
python ./py/sql2eh.py

```

## Testing (Running a Consumer)

Easiest way is to go to EH and find the "Process Data" option.  This is a mini Azure Stream Analytics.  Have the consumer run a few times and you should see the output.  The last 3 columns will also show the EvnetProcessedUtcTime, PartitionId, and EventEnqueuedUtcTime.  