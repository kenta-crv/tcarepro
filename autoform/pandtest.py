import pandas as pd
from matplotlib import pyplot
import sqlite3

import os
import datetime

data = {
    "score":[]
}

dbname = './db/development.sqlite3'
conn = sqlite3.connect(dbname)
cur = conn.cursor()

fig = pyplot.figure()

cd = os.path.abspath('.')

df = pd.read_sql_query('SELECT current_score FROM autoform_shot', conn)

df.columns = ["Score"]

pyplot.ylim(0,110)
pyplot.xlabel('予約時間あたりの回数')
pyplot.ylabel('スコア(点数)')
pyplot.title('xxx時点のスコアグラフ')

df.plot()
print(os.getcwd())
tdatetime = datetime.datetime.now()
strings = tdatetime.strftime('%Y%m%d-%H%M%S')
pyplot.ylim(0,100)
pyplot.savefig(cd + '/autoform/graph_image/'+strings+'.png')


print(df)