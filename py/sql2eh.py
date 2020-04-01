from __future__ import print_function

import pathlib
import datetime
import logging
import json
import pyodbc
import pandas as pd
import io
import sys
import os
#import asyncio
#from azure.eventhub.aio import EventHubProducerClient
from azure.eventhub import EventHubProducerClient, EventData

ehquery = "exec metadata.GetLatestTableData {},{}"
hwmQuery = "exec metadata.SetLastSyncVersion {},{}"
ehBatchSize = 20  # num rows sent for EH call, EH message size is about 1MB
path = str(pathlib.Path(__file__).parent.absolute())

# access configurations
configFile = path + '/config.json'
with open(configFile) as c:
    creds = json.load(c)

# get eh primed 
ehAddress=creds['credentials']['EventHub']['connstring']


# sql conn
conn = pyodbc.connect(
    driver='{ODBC Driver 17 for SQL Server}', \
    host=creds['credentials']['sqlserver']['database']['db1']['server'], \
    database=creds['credentials']['sqlserver']['database']['db1']['database'], \
    trusted_connection='no', \
    user=creds['credentials']['sqlserver']['database']['db1']['username'], \
    password=creds['credentials']['sqlserver']['database']['db1']['password'], \
    MARS_Connection='Yes'
    )
conn.autocommit = True

# helper functions
def send_event_data_batch(producer,data):
    event_data_batch = producer.create_batch()
    event_data_batch.add(EventData(data))
    producer.send_batch(event_data_batch)

def processOneTable(schema,table):
    # a single table needs to be processed "transactionally".  This means we want to 
    # read/jsonify/send to EH/mark table complete in one call
    # we also want to do this async since we may have several batches per table TODO

    print("Running : {} - {}".format(schema,table))

    # get all eligible table rows
    dfAllRows = pd.read_sql(ehquery.format(schema,table), conn)

    # EH messages should be batches of x rows
    for i in range (0,len(dfAllRows),ehBatchSize):
        print("Running for batch {}:{}".format(i,i+ehBatchSize))
        dfjson = dfAllRows.iloc[i:i+ehBatchSize].to_json(orient='records',indent=0,lines=False, date_format='iso')
        #print(dfjson)

        # send to EH
        producer = EventHubProducerClient.from_connection_string(conn_str=ehAddress)
        with producer: 
            send_event_data_batch(producer,dfjson)

    # mark the table as processed
    curUpdater = conn.cursor()
    curUpdater.execute(hwmQuery.format(schema,table))


def processAllTables():
    curAllItems = conn.cursor()
    curAllItems.execute("select schemaname, tblname from metadata.CTTABLES where is_enabled = 1;")

    # for each table
    for row in curAllItems:
        processOneTable (row[0],row[1])

processAllTables()




