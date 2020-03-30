from __future__ import print_function

import pathlib
import datetime
import logging
import json
import pyodbc
import pandas as pd
import io

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

def query_db(query, one=False):
    cursor = conn.cursor()
    cursor.execute(query)
    r = [dict((cursor.description[i][0], value) \
               for i, value in enumerate(row)) for row in cursor.fetchall()]
    cursor.connection.close()
    return (r[0] if r else None) if one else r

rowsquery = query_db(ehquery)
json_output = json.dumps(rowsquery)