import pandas as pd
from matplotlib import pyplot
import sqlite3

import os
import datetime

data = {
    "status":[]
}

dbname = './db/development.sqlite3'
conn = sqlite3.connect(dbname)
cur = conn.cursor()
cur.execute('SELECT status FROM autoform_shot')

fig = pyplot.figure()

cd = os.path.abspath('.')

error = 0
success = 0

for curs in cur.fetchall():
    if curs[0] == '送信済':
        success += 1
    elif curs[0] == '送信不可':
        error += 1

print(success,error)

df = pd.DataFrame(data=[success,error],index=['送信済','送信不可'])

df.columns = ["status"]

pyplot.title('xx' + '時点',fontname='Hiragino sans',fontsize=30)
pyplot.rcParams["font.family"] = "Hiragino sans"

df['status'].plot.pie(autopct='%.f%%')
print(os.getcwd())
tdatetime = datetime.datetime.now()
strings = tdatetime.strftime('%Y%m%d-%H%M%S')
pyplot.savefig(cd + '/autoform/graph_image/'+strings+'.png')


print(df)