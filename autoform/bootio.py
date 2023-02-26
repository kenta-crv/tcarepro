import sqlite3
import sched,time
import hardware
import schedule
import datetime
import os
from matplotlib import pyplot

print(os.getcwd())

dbname = './db/development.sqlite3'
s = sched.scheduler()

class Score:
    def __init__(self):
        self.score = 0
        self.count = 0
        self.rimes = []
        self.sumdic = []

    def result(self):
        truecount = 0
        for tuc in self.rimes:
            if tuc == True:
                truecount += 1

        sum = int((truecount / len(self.rimes)) * 100)
        self.sumdic.append(sum)

        try:
            return str(sum) + "%"
        except ZeroDivisionError as e:
            return "0%"
        
    def graph_make(self):
        x = self.sumdic
        y = range(len(x))
        pyplot.plot(x,y)
        pyplot.show()

    

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

def boot(url,sender_id,count,worker_id):
    conn = sqlite3.connect(dbname)
    # sqliteを操作するカーソルオブジェクトを作成
    cur = conn.cursor()
    id = sender_id
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
        except Exception as e:
            go = "NG"
            print("system error")
            print(e)
        if go == "OK":
            print("正常に送信されました。")
            score.rimes.append(True)
            cur.execute('UPDATE contact_trackings SET status = "送信済", sended_at = "'+ str(datetime.datetime.now()) +'" WHERE contact_url="'+ url +' AND worker_id = '+ str(worker_id)+'"')
            print("---------------------------------")
            print("送信精度：",score.result())
            print("---------------------------------")
        elif go == "NG":
            print("送信エラー。。。")
            score.rimes.append(False)
            cur.execute('UPDATE contact_trackings SET status = "送信不可", sended_at = "'+ str(datetime.datetime.now()) +'" WHERE contact_url="'+ url +' AND worker_id = '+ str(worker_id)+'"')
            print("---------------------------------")
            print("送信精度：",score.result())
            print("---------------------------------")


    conn.commit()
    conn.close()

    if count == score.count:
        score.graph_make()

def sql_reservation():
    print("Reservation Check!!!")
    conn = sqlite3.connect(dbname)
    score.count = 0
    # sqliteを操作するカーソルオブジェクトを作成
    cur = conn.cursor()
    cur.execute('SELECT contact_url,sender_id,scheduled_date,callback_url,worker_id FROM contact_trackings WHERE status = "自動送信予定"')
    for index,item in enumerate(cur.fetchall()):
        url = item[0]
        gotime = item[2]
        callback = item[3]
        worker_id = item[4]
        sender_id = item[1]
        c = reservation.check(url,sender_id)
        if c == True:
            print("This already exists")
            pass
        elif c == False:
            if url == None:
                print("No URL!!")
                cur.execute('UPDATE contact_trackings SET status = "送信不可", sended_at = "'+ str(datetime.datetime.now()) +'" WHERE callback_url="'+ callback +'" AND worker_id = "'+ str(worker_id) +'"')
            else:
                reservation.add(gotime,url,sender_id,index,worker_id)
                score.count += 1

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
                if (num - sabun) == 5:
                    sabun += 5
                    fime += 1

                if int(minute) > 59:
                    newminute = str(60-int(minute))
                    print("new")
                    schedule.every().day.at(str(int(hour)+1).zfill(2)+':'+str(int(newminute)*-1).zfill(2)).do(boot,trigger["url"],trigger["sender_id"],trigger["worker_id"],num)
                else:
                    schedule.every().day.at(hour.zfill(2)+':'+minute.zfill(2)).do(boot,trigger["url"],trigger["sender_id"],trigger["worker_id"],num)
            else:
                print(minute)
                if int(minute) > 59:
                    newminute = str(60-int(minute))
                    print(int(newminute)*-1)
                    print("new")
                    schedule.every().day.at(str(int(hour)+1)+':'+str(int(newminute)*-1).zfill(2)).do(boot,trigger["url"],trigger["sender_id"],trigger["worker_id"],num)
                else:
                    schedule.every().day.at(hour.zfill(2)+':'+minute.zfill(2)).do(boot,trigger["url"],trigger["sender_id"],trigger["worker_id"],num)

    print("-----------------------------------------")
    print("      "+str(score.count)+"件登録しました。        ")
    print("-----------------------------------------")

schedule.every(1).hours.do(sql_reservation)
sql_reservation()

while True:
    schedule.run_pending()
    time.sleep(2)
    print("running")