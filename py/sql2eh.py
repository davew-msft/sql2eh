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

path = str(pathlib.Path(__file__).parent.absolute())

# access configurations
configFile = path + '/config.json'
with open(configFile) as c:
    creds = json.load(c)

conn = pyodbc.connect(
    driver='{ODBC Driver 17 for SQL Server}', \
    host=creds['credentials']['sqlserver']['database']['db1']['server'], \
    database=creds['credentials']['sqlserver']['database']['db1']['database'], \
    trusted_connection='no', \
    user=creds['credentials']['sqlserver']['database']['db1']['username'], \
    password=creds['credentials']['sqlserver']['database']['db1']['password']
    )

ehquery = "exec metadata.GetLatestTableData 'dbo','Employee'"
#cursor = conn.cursor()
#cursor.execute (ehquery)

#for row in cursor: 
#    print(row)

def query_db(query, args=(), one=False):
    cur = conn.cursor()
    cur.execute(query, args)
    r = [dict((cur.description[i][0], value) \
               for i, value in enumerate(row)) for row in cur.fetchall()]
    cur.connection.close()
    return (r[0] if r else None) if one else r

rowsquery = query_db(ehquery)
json_output = json.dumps(rowsquery)
print(json_output)


# eh client
ehAddress=creds['credentials']['EventHub']['connstring']
sas=creds['credentials']['EventHub']['event-hub-policy-name']
saskey= creds['credentials']['EventHub']['sas-key']


ehClient = EventHubClient(ehAddress, debug=False, username=sas, password=saskey)
sender = ehClient.add_sender(partition="0")
ehClient.run()
try:
    start_time = time.time()
    for i in range(100):
        print("Sending message: {}".format(i))
        message = "Message {}".format(i)
        sender.send(EventData(message))
except:
    raise
finally:
    end_time = time.time()
    client.stop()
    run_time = end_time - start_time
    logger.info("Runtime: {} seconds".format(run_time))

