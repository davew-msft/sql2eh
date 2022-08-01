_master branch is SQL CDC to EH using debezium_  
_sqlct2eh is SQL CT to EH_ 

## SQL-to-EH

This repo demos how to get changes from SQL Server published to an EH.  We take the data and then land it to a data lake.  For this branch of the repo we are using SQL Server CDC and the debezium kafka connector.  

This is not complete. 

## Assumptions

* we are using the docker container solution.  This will require docker or k8s when run in a production manner.  
* your workstation/laptop has docker capabilities.  

## References

* [Microsoft Documentation for debezium with EH](https://github.com/Azure-Samples/azure-sql-db-change-stream-debezium):  this doesn't appear up-to-date with debezium changes.  
* [Kafka Client with EH](https://nielsberglund.com/2022/01/02/how-to-use-kafka-client-with-azure-event-hubs/):  helpful to understand terminology differences and how to wireup Kafka Connect to EH.
* [Event Hubs and Stream Analytics](https://github.com/Azure-Samples/streaming-at-scale/tree/main/eventhubs-streamanalytics-azuresql) Once you have the data streaming to EH this is one possible solution to stream the messages to the datalake.  


## **Alternatives to Consider**

* [CDC via pySpark](https://github.com/InterruptSpeed/sql-server-cdc-with-pyspark).  This removes the need for EH/Kafka and keeps the delta table up-to-sync with the source via CDC.  
* [CDC to EH using "Push" via SQLAgent and .net](https://github.com/rolftesmer/SQLCDC2EventHub):  this isn't true push, but it's closer and should not require any add'l infrastructure to work.  But it will require compiling a .net project and running it from sqlagent.  
* [sqlserver-cdc-to-kafka](https://github.com/woodlee/sqlserver-cdc-to-kafka).  This is basically roll-your-own Debezium.  


kafka connect example:  https://github.com/codingblocks/Batches-to-Streams-with-Apache-Kafka

## Steps

```bash
# clone this repo
git clone https://github.com/davew-msft/sql2eh
cd sql2eh


```

## Setup vscode with Azure Event Hub Explorer

...so we can view the CDC messages later.  

## Setup SQL

We will use a SQL Server that has CDC enabled.  

I'm just going to create a docker container for this with the necessary steps.  You may not need to do these steps if you have an existing SQL Server.  

```bash

echo "Downloading AdventureWorks backup file.  We will use this for CDC enablement"
wget https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2017.bak -O ./sql-container/adventureworks-light.bak -q

cd sql-container
mkdir -p data

docker build . -t cdc-aw-light 

docker run \
  --name sqlserver \
  -p 1433:1433 \
  -e 'ACCEPT_EULA=Y' \
  -e 'SA_PASSWORD=Password01!!' \
  -e 'MSSQL_AGENT_ENABLED=True' \
  -d cdc-aw-light:latest 


# make sure it is running
docker ps

# ONLY run if you need to cleanup the docker container
docker stop sqlserver
docker rm sqlserver
docker image rm cdc-aw-light:latest

# to restart the docker container later AND maintain all the configuration
docker start sqlserver


```

## Setup CDC

We can run these commands from ADS or SSMS or whatever.  The connstring will look similar to this:  

* 127.0.0.1
* 1433
* sa/Password01!!



```sql

USE AdventureWorks
GO
EXEC sp_changedbowner 'sa'
GO
EXEC sys.sp_cdc_enable_db
GO

EXEC sys.sp_cdc_enable_table
@source_schema = N'HumanResources',
@source_name   = N'Employee',
@role_name     = N'cdc_role',
@filegroup_name = null,
@supports_net_changes = 1
GO

EXEC sys.sp_cdc_help_change_data_capture
GO

--need to ensure sqlagent is running
EXEC master.dbo.xp_servicecontrol N'QUERYSTATE',N'SQLSERVERAGENT'
```



## Setup Event Hub

* need a EH
  * Standard
  * everything else is optional.  
  * setup a policy for manage
  * two consumer groups:
    * debug
    * datalake


Here's the exact process, might be easiest to do this from [CloudShell](https://shell.azure.com/), make sure you specify `bash`.  

>>Note:  to prevent cloudshell timeouts just run `watch ls` 

```bash
# vars to change
export SUBSCRIPTION="davew demo"
export LOCATION="eastus"
export RESOURCE_GROUP="rgChEH"
# this should support at least 10K msgs/sec
export EVENTHUB_PARTITIONS=12
export EVENTHUB_CAPACITY=12
export EVENTHUB_NAMESPACE=$RESOURCE_GROUP"eventhubs"   
export EVENTHUB_NAME=$PREFIX"in-"$EVENTHUB_PARTITIONS
export EVENTHUB_CG="debug"
export EVENTHUB_CAPTURE="False"  # for now, we may want to enable this later

az login
az account list
az account set --subscription "$SUBSCRIPTION"

az group create -n $RESOURCE_GROUP -l $LOCATION

az eventhubs namespace create \
  -n $EVENTHUB_NAMESPACE \
  -g $RESOURCE_GROUP \
  --sku Standard \
  --location $LOCATION \
  --capacity $EVENTHUB_CAPACITY \
  --enable-kafka "TRUE" \
  --enable-auto-inflate false \

az eventhubs eventhub create \
  -n $EVENTHUB_NAME \
  -g $RESOURCE_GROUP \
  --message-retention 1 \
  --partition-count $EVENTHUB_PARTITIONS \
  --namespace-name $EVENTHUB_NAMESPACE \
  --enable-capture "$EVENTHUB_CAPTURE" 
 # --capture-interval 300 \
 # --capture-size-limit 314572800 \
 # --archive-name-format 'capture/{Namespace}/{EventHub}/{Year}_{Month}_{Day}_{Hour}_{Minute}_{Second}_{PartitionId}' \
 # --blob-container streamingatscale \
 # --destination-name 'EventHubArchive.AzureBlockBlob' \
 # --storage-account ${AZURE_STORAGE_ACCOUNT_GEN2:-$AZURE_STORAGE_ACCOUNT} \

az eventhubs namespace authorization-rule create \
  -g $RESOURCE_GROUP \
  --namespace-name $EVENTHUB_NAMESPACE \
  --name Listen --rights Listen 
az eventhubs namespace authorization-rule create \
  -g $RESOURCE_GROUP \
  --namespace-name $EVENTHUB_NAMESPACE \
  --name Send --rights Send 

az eventhubs eventhub consumer-group create \
  -n $EVENTHUB_CG \
  -g $RESOURCE_GROUP \
  --eventhub-name $EVENTHUB_NAME \
  --namespace-name $EVENTHUB_NAMESPACE 

az eventhubs namespace authorization-rule keys list \
  -g $RESOURCE_GROUP \
  --namespace-name $EVENTHUB_NAMESPACE  \
  -n RootManageSharedAccessKey \
  --query "primaryConnectionString" -o tsv


```

Copy the last command's output, that is your connstring:

`Endpoint=sb://rgcheheventhubs.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=DXOhIqXZjr/kA0VtXFJgg60UzcQAwJy3/1qg2gKwgI`

* Copy your connstring into the `./debezium/.env.sample` file and also change `EH_NAME` var.  
* rename the file to `.env`


## Debezium Setup

We will use dbz in docker containers and not VMs.  It's easier.  

Connect to your database and run:

```sql
USE [master]
GO
CREATE LOGIN [debezium] WITH PASSWORD = 'Password01!!'
GO
USE [AdventureWorks]
GO
CREATE USER [debezium] FROM LOGIN [debezium]
GO
ALTER ROLE [db_owner] ADD MEMBER [debezium]
GO

```

Get the docker containers running.  From your existing bash shell:

```bash
cd ../debezium

docker-compose up -d 

## watch the logs, looking for errors, etc
docker-compose logs -f
# Ctl+C when done


```

Let's make sure the container is talking to EH.  From cloudshell:

```bash
az eventhubs eventhub list -g $RESOURCE_GROUP --namespace $EVENTHUB_NAMESPACE -o table

```

You should see 3 new eventhub "topics" all starting with `debezium`.  

## Setup the Debezium connector

Open [register-connector.json](./debezium/register-connector.json) and make the necessary changes.   

>Note:  `"transforms.Reroute.topic.replacement": "in-12",`  :  that line is the name of your eventhub that YOU created

From the machine running the Debezium container:  

```bash


curl -i -X POST -H "Accept:application/json" -H "Content-Type:application/json" http://localhost:8083/connectors/ -d @./register-connector.json -w "\n"


```

Now connect to vscode, open the palette and connect to your EH.  Then choose `EventHub: Start Monitoring`.  

Let's simulate a data change:  

```sql
update HumanResources.Employee SET HireDate = '1/1/2022' WHERE BusinessEntityID = 1;

```

Note the approximate number of seconds it took until you saw the message in the EH monitor in vscode.  

Note what happens when we send 2 changes:

```sql
update HumanResources.Employee SET HireDate = '1/1/2020' WHERE BusinessEntityID IN (1,2);

```

## Other Points

To stop debezium:  
  
`docker compose down`

To list available connectors:

`curl -i -X GET http://localhost:8083/connectors -w "\n"`  
`curl -i -X GET -H "Accept:application/json" -H "Content-Type:application/json" http://localhost:8083/connector-plugins/ -w "\n"`  

