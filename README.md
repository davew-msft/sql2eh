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
* [sqlserver-cdc-to-kafka](https://github.com/woodlee/sqlserver-cdc-to-kafka).  Thi sis basically roll-your-own Debezium.  


kafka connect example:  https://github.com/codingblocks/Batches-to-Streams-with-Apache-Kafka

## Steps

```bash
# clone this repo
git clone https://git.davewentzel.com/demos/sql2eh
cd sql2eh


```

## Setup SQL

We will use a SQL Server that has CDC enabled.  

I'm just going to create a docker container for this with the necessary steps.  You may not need to do these steps if you have an existing SQL Server.  

```bash
docker-compose -f docker-compose-sqlserver.yaml up

```

## Setup CDC

```sql

USE testDB
GO
EXEC sys.sp_cdc_enable_db
GO

EXEC sys.sp_cdc_enable_table
@source_schema = N'dbo',
@source_name   = N'MyTable',
@role_name     = N'MyRole',
@filegroup_name = N'MyDB_CT',
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

Note connstring info here (this must be to the EH _not_ the namespace):

Mine:  
`Endpoint=sb://davewdataeng.servicebus.windows.net/;SharedAccessKeyName=mypolicy;SharedAccessKey=78k4G4aL26NmSjEtqZQPS7w26H1XDSVnzhooublUzeQ=;EntityPath=sql2eh`

Here's the exact process, might be easiest to do this from [CloudShell](https://shell.azure.com/), make sure you specify `bash`.  

```bash
# vars to change
export SUBSCRIPTION=""
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
az account set --subscription $SUBSCRIPTION

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
```
