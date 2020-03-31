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
import asyncio
from azure.eventhub.aio import EventHubProducerClient
from azure.eventhub import EventData

ehquery = "exec metadata.GetLatestTableData 'dbo','Employee'"
hwmQuery = "exec metadata.SetLastSyncVersion 'dbo','Employee'"
path = str(pathlib.Path(__file__).parent.absolute())

# access configurations
configFile = path + '/config.json'
with open(configFile) as c:
    creds = json.load(c)
    
ehAddress=creds['credentials']['EventHub']['connstring']

# sql conn
conn = pyodbc.connect(
    driver='{ODBC Driver 17 for SQL Server}', \
    host=creds['credentials']['sqlserver']['database']['db1']['server'], \
    database=creds['credentials']['sqlserver']['database']['db1']['database'], \
    trusted_connection='no', \
    user=creds['credentials']['sqlserver']['database']['db1']['username'], \
    password=creds['credentials']['sqlserver']['database']['db1']['password']
    )
conn.autocommit = True

# helper functions
def query_db(query, args=(), one=False):
    cur = conn.cursor()
    cur.execute(query, args)
    r = [dict((cur.description[i][0], value) \
               for i, value in enumerate(row)) for row in cur.fetchall()]
    cur.close()
    return (r[0] if r else None) if one else r

# eh client
async def ehProducer(data):
    producer = EventHubProducerClient.from_connection_string(conn_str=ehAddress)
    async with producer:
        event_data_batch = await producer.create_batch()

        # add our JSON
        event_data_batch.add(EventData(data))

        await producer.send_batch(event_data_batch)

# main
# get the data from sql 
rowsquery = query_db(ehquery)
json_output = json.dumps(rowsquery)
print(json_output)

# push to eh
loop = asyncio.get_event_loop()
loop.run_until_complete(ehProducer(json_output))

# mark the table as processed
cur = conn.cursor()
cur.execute(hwmQuery)








