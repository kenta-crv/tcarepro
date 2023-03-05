import sqlite3
import sched,time
import hardware
import schedule
import datetime
import pandas
import os
from matplotlib import pyplot
import random
import string
import pandas as pd

print(os.getcwd())

dbname = './db/development.sqlite3'
s = sched.scheduler()

class Score:
    def __init__(self):
        self.score = 0
        self.count = 0
        self.rimes = []
        self.sumdic = []
        self.time = ''

    def result(self,sender_id,worker_id,url,status,session_code):
        truecount = 0
        for tuc in self.rimes:
            if tuc == True:
                truecount += 1

        sum = int(int((truecount / len(self.rimes)) * 100))
        self.sumdic.append(sum)

        # 統計システム入れる
        conn = sqlite3.connect(dbname)
        cur = conn.cursor()

        sql = 'INSERT INTO autoform_shot (sender_id, worker_id, url, status, current_score, session_code) values (?,?,?,?,?,?)'
        data = (sender_id,worker_id,url,status,sum,session_code)
        cur.execute(sql,data)
        
        conn.commit()
        conn.close()

        try:
            return str(sum) + "%"
        except ZeroDivisionError as e:
            return "0%"
        
    def graph_make(self,session_code):
        #時間軸
        #1日毎
        #100回毎

        conn = sqlite3.connect(dbname)
        cur = conn.cursor()

        #SQL検索
        cur.execute('SELECT * FROM autoform_shot WHERE session_code ="' + session_code+'"')


        print('グラフを作成します。')



        sqldata = []

        frame = {
            "score":[]
        }

        success = 0
        error = 0

        #SQL抽出
        for curs in cur.fetchall():
            if curs[3] == '送信済':
                success += 1
            elif curs[3] == '送信エラー':
                error += 1

        df = pd.DataFrame(data=[success,error],index=['送信済','送信エラー'])
        df.columns = ["送信率"]
        pyplot.rcParams["font.family"] = "Hiragino sans"
        cd = os.path.abspath('.')
        tdatetime = datetime.datetime.now()
        df['送信率'].plot.pie(autopct='%.f%%')
        strings = tdatetime.strftime('%Y%m%d-%H%M%S')
        pyplot.title(self.time + 'に'+ str(self.count) + '回実行したグラフ' ,fontname="Hiragino sans")
        pyplot.savefig(cd + '/autoform/graph_image/shot/'+strings+'.png')
        conn.commit()
        conn.close()

    def graph_summary(self):
        conn = sqlite3.connect(dbname)
        cur = conn.cursor()

        #SQL検索
        cur.execute('SELECT * FROM autoform_shot')


        print('グラフサマリーを作成します。')



        sqldata = []

        frame = {
            "score":[]
        }

        #SQL抽出
        success = 0
        error = 0
        for curs in cur.fetchall():
            if curs[3] == '送信済':
                success += 1
            elif curs[3] == '送信不可':
                error += 1

        df = pd.DataFrame(frame, columns=["score"])
        df.columns = ["Score"]

        date = tdatetime.strftime('%Y-%m-%d')

        pyplot.title(date + '今まで実行したグラフ',fontname='Hiragino sans')
        pyplot.rcParams["font.family"] = "Hiragino sans"

        df['status'].plot.pie(autopct='%.f%%')
        
        df.plot()
        cd = os.path.abspath('.')
        tdatetime = datetime.datetime.now()
        strings = tdatetime.strftime('%Y%m%d-%H%M%S')
        pyplot.savefig(cd + '/autoform/graph_image/day/'+strings+'.png')
        conn.commit()
        conn.close()


    

class Reservation:
    def __init__(self):
        self.boottime = []

    def add(self,time,url,sender_id,priority,worker_id):
        print('New Records!! [',time,url,sender_id,priority,']')
        self.boottime.append({'time':time,'url':url,'sender_id':sender_id,'worker_id':worker_id,'priority':priority})

    def check(self,url,sender_id):
        for time in self.boottime:
            if time["url"] == url and time["sender_id"] == sender_id:
                return True
            
        return False
    
    def alltime(self):
        return self.boottime



score = Score()
reservation = Reservation()

def randomname(n):
   randlst = [random.choice(string.ascii_letters + string.digits) for i in range(n)]
   return ''.join(randlst)

def boot(url,sender_id,count,worker_id,session_code):
    conn = sqlite3.connect(dbname)
    # sqliteを操作するカーソルオブジェクトを作成
    cur = conn.cursor()
    id = sender_id
    form = {}
    print(id)
    cur.execute('SELECT * FROM inquiries WHERE sender_id = "'+ str(id) +'"')
    for index,item in enumerate(cur.fetchall()):
        form = {
            "company":item[1],
            "company_kana":"kakasi",
            "manager":item[3],
            "manager_kana":item[4],
            "phone":item[5],
            "fax":item[6],
            "address":item[9],
            "mail":item[7],
            "subjects":item[10],
            "body":item[11]
        }
        
    try:
            hard = hardware.Place_enter(url,form)
            go = hard.go_selenium()
            print(go)
    except Exception as e:
            go = "NG"
            print("system error")
            print(e)

    if go == "OK":
            print("正常に送信されました。")
            score.rimes.append(True)
            sql = 'UPDATE contact_trackings SET status = ?, sended_at = ? WHERE contact_url = ? AND worker_id = ?'
            data = ("送信済",datetime.datetime.now(),url,worker_id)
            cur.execute(sql,data)
            conn.commit()
            conn.close()
            s = score.result(sender_id,worker_id,url,"送信済",session_code)
            print("---------------------------------")
            print("送信精度：",s)
            print("---------------------------------")
    elif go == "NG":
            print("送信エラー。。。")
            score.rimes.append(False)
            sql = 'UPDATE contact_trackings SET status = ?, sended_at = ? WHERE contact_url = ? AND worker_id = ?'
            data = ("自動送信エラー",datetime.datetime.now(),url,worker_id)
            cur.execute(sql,data)
            conn.commit()
            conn.close()
            s = score.result(sender_id,worker_id,url,"送信エラー",session_code)
            print("---------------------------------")
            print("送信精度：",s)
            print("---------------------------------")


    print(score.count-1)
    print(count)

    if count == score.count-1:
        score.graph_make(session_code)

def sql_reservation():
    print("Reservation Check!!!")
    conn = sqlite3.connect(dbname)
    score.count = 0
    # sqliteを操作するカーソルオブジェクトを作成
    cur = conn.cursor()
    cur.execute('SELECT contact_url,sender_id,scheduled_date,callback_url,worker_id FROM contact_trackings WHERE status = "自動送信予定"')
    session_code = randomname(16)
    for index,item in enumerate(cur.fetchall()):
        url = item[0]
        gotime = item[2]
        callback = item[3]
        worker_id = item[4]
        sender_id = item[1]
        score.time = gotime
        c = reservation.check(url,sender_id)
        if c == True:
            print("This already exists")
            pass
        elif c == False:
            if url == None:
                print("No URL!!")
                sql = 'UPDATE contact_trackings SET status = ?, sended_at = ? WHERE callback_url = ? AND worker_id = ?'
                data = ("自動送信エラー",datetime.datetime.now(),callback,worker_id)
                cur.execute(sql,data)
            else:
                if url.startswith('http'):
                    reservation.add(gotime,url,sender_id,index,worker_id)
                    score.count += 1
                else:
                    print("Invaild URL!!")
                    sql = 'UPDATE contact_trackings SET status = ?, sended_at = ? WHERE callback_url = ? AND worker_id = ?'
                    data = ("自動送信エラー",datetime.datetime.now(),callback,worker_id)
                    cur.execute(sql,data)

    conn.commit()
    conn.close()
    sabun = 0
    fime = 1

    for num,trigger in enumerate(reservation.alltime()):
        strtime = trigger["time"]
        datetimes = datetime.datetime.strptime(strtime, '%Y-%m-%d %H:%M:%S')
        dtnow = datetime.datetime.now()
        print("このデータは起動する準備ができています。")
        hour = str(datetimes.hour)
        minute = str(datetimes.minute+fime)
        if dtnow.year == datetimes.year and dtnow.month == datetimes.month and dtnow.day == datetimes.day:
            print(dtnow.hour,':',dtnow.minute)
            print(hour,':',minute)
            if (num - sabun) >= 4:
                newminute = 0
                if (num - sabun) == 5:
                    sabun += 5
                    fime += 1

                if int(minute) > 59:
                    if int(minute) > 119:
                        newminute = str(120-int(minute))
                    else:
                        newminute = str(60-int(minute))
                    print("new")
                    schedule.every().day.at(str(int(hour)+1).zfill(2)+':'+str(int(newminute)*-1).zfill(2)).do(boot,trigger["url"],trigger["sender_id"],num,trigger["worker_id"],session_code)
                else:
                    schedule.every().day.at(hour.zfill(2)+':'+minute.zfill(2)).do(boot,trigger["url"],trigger["sender_id"],num,trigger["worker_id"],session_code)
            else:
                newminute = 0
                print(minute)
                if int(minute) > 59:
                    if int(minute) > 119:
                        newminute = str(120-int(minute))
                        print(newminute)
                    else:
                        newminute = str(60-int(minute))
                    print(int(newminute)*-1)
                    print("new")
                    schedule.every().day.at(str(int(hour)+1)+':'+str(int(newminute)*-1).zfill(2)).do(boot,trigger["url"],trigger["sender_id"],num,trigger["worker_id"],session_code)
                else:
                    schedule.every().day.at(hour.zfill(2)+':'+minute.zfill(2)).do(boot,trigger["url"],trigger["sender_id"],num,trigger["worker_id"],session_code)

    print("-----------------------------------------")
    print("      "+str(score.count)+"件登録しました。        ")
    print("-----------------------------------------")

schedule.every(1).hours.do(sql_reservation)
schedule.every(1).days.do(score.graph_summary)

sql_reservation()

while True:
    schedule.run_pending()
    time.sleep(2)
    print("running")