from flask import *
import datetime
import schedule
import hardware
import requests
import json
import sys
import os
import time
import pandas as pd
from apscheduler.schedulers.background import BackgroundScheduler
from matplotlib import pyplot
import matplotlib
import traceback
matplotlib.use('agg')

app = Flask(__name__)

statment = "local"
#statment = sys.argv[0]
server_domain = ""

if statment == "local":
    server_domain = "http://localhost:3000"
elif statment == "global":
    server_domain = "http://tcare.pro"

def scheds():
    print('running...')
    schedule.run_pending()


class Schedule:

    def __init__(self):
        self.shutdown = False

    def starting(self):
        print("BOTアラームをアクティブ化しました。Flask Servingを有効にしている間起動できます。")
        while True:
            date = datetime.datetime.today()
            if self.shutdown == True:
                break
            
            schedule.run_pending()
            print(f"ただいまの時刻は、{date.hour} : {date.minute} : {date.second} です。")
            time.sleep(1)

schedules = Schedule()

class Score:
    def __init__(self):
        self.score = 0
        self.count = 0
        self.rimes = []
        self.sumdic = []
        self.result_data = []
        self.time = ''

    def result(self,status,session_code,generation_code):
        print(status)
        truecount = 0
        for tuc in self.rimes:
            if tuc == True:
                truecount += 1

        sum = int(int((truecount / len(self.rimes)) * 100))
        self.sumdic.append(sum)

        # 自動送信成功した場合
        if status == "SUCCESS":
            parameter = {"generation_code":generation_code}
            r = requests.post(server_domain + "/api/v1/pybotcenter/success",data=json.dumps(parameter))
            self.result_data.append({"session_code":session_code,"generation_code":generation_code,"status":"送信済"})
            print('SUCCESSデータを送信しました。')
        #自動送信失敗した場合
        elif status == "FAILED":
            parameter = {"generation_code":generation_code}
            r = requests.post(server_domain + "/api/v1/pybotcenter/failed",data=json.dumps(parameter))
            self.result_data.append({"session_code":session_code,"generation_code":generation_code,"status":"送信エラー"})
            print('FAILEDデータを送信しました。')


        try:
            return str(sum) + "%"
        except ZeroDivisionError as e:
            return "0%"
        
    def graph_make(self,session_code,company):
        #時間軸
        #1日毎
        #100回毎

        print('グラフを作成します。')



        sqldata = []

        frame = {
            "score":[]
        }

        success = 0
        error = 0

        #SQL抽出
        for curs in self.result_data:
            if curs['session_code'] == session_code:
                if curs['status'] == '送信済':
                    success += 1
                elif curs['status'] == '送信エラー':
                    error += 1

        self.result_data = []

        df = pd.DataFrame(data=[success,error],index=['送信済','送信エラー'])
        df.columns = ["送信率"]
        pyplot.rcParams["font.family"] = "Hiragino sans"
        cd = os.path.abspath('.')
        tdatetime = datetime.datetime.now()
        df['送信率'].plot.pie(autopct='%.f%%')
        strings = tdatetime.strftime('%Y%m%d-%H%M%S')
        pyplot.title(company+'の営業問い合わせを'+str(success + error) + '回行った送信成功率' ,fontname="Hiragino sans")
        pyplot.savefig(cd + '/autoform/graph_image/shot/'+strings+'.png')
        self.count = 0
        headers = {"content-type": "application/json"}
        data = {"title":"オート送信実行完了","message":company+'の営業問い合わせの自動送信が終了しました。送信成功率を(./graph_image/shot)へ配置しております。',"status":"notify"}
        message_post = requests.post(server_domain + "/api/v1/pycall",data=json.dumps(data),headers=headers)

    def graph_summary(self):

        print('グラフサマリーを作成します。')



        sqldata = []

        frame = {
            "score":[]
        }

        #SQL抽出
        success = 0
        error = 0
        for curs in self.result_data:
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

        headers = {"content-type": "application/json"}
        data = {"title":"autoの実行完了","message":"autoの実行を全て終えました。グラフ","status":"notify"}
        message_post = requests.post(server_domain + "/api/v1/pycall",data=json.dumps(data),headers=headers)

score = Score()

class Mother:
    def __init__(self):
        self.boottime = []
        self.count = 0
        self.sabun = 0
        self.fime = 0

    def add(self,company_name,time,url,inquiry_id,worker_id,reserve_key,generation_key):
        print('@bot railsから '+ company_name +'の送信データを受け取りました。 [',time,url,']')
        if len(self.boottime) == 0:
            print(score.count)
            self.boottime.append({'time':time,'url':url,'company_name':company_name,'inquiry_id':inquiry_id,'worker_id':worker_id,'priority':1,'reserve_key':reserve_key,'generation_key':generation_key,'subscription':False,'finalist':True})
        else:
            if self.boottime[-1]['reserve_key'] == reserve_key:
                print(score.count)
                sum = self.boottime[-1]['priority'] + 1
                self.boottime[-1]['finalist'] = False
                self.boottime.append({'time':time,'url':url,'company_name':company_name,'inquiry_id':inquiry_id,'worker_id':worker_id,'priority':sum,'reserve_key':reserve_key,'generation_key':generation_key,'subscription':False,'finalist':True})

    def check(self,url,inquiry_id,worker_id):
        for time in self.boottime:
            if time["url"] == url and time["inquiry_id"] == inquiry_id and time["worker_id"] == worker_id:
                return True
            
        return False
    def reserve(self,worker_id,inquiry_id,company_name,contact_url,scheduled_date,reserve_key,generation_key):
        c = self.check(contact_url,inquiry_id,worker_id)
        if c == True:
            print("@bot すでにデータがあります。")
        elif c == False:
            if contact_url == "":
                print("@bot URLがありません。")
                raise FileNotFoundError("URLがありません。")
            else:
                if contact_url.startswith('http'):
                    self.add(company_name,scheduled_date,contact_url,inquiry_id,worker_id,reserve_key,generation_key)
                    self.inset_schedule()
                else:
                    print("@bot 無効なURL")
                    raise ValueError("httpからはじまっていません。")
                
    def boot(self,url,inquiry_id,worker_id,session_code,generate_code):
        # inquiryをAPIで取得する
        headers = {"content-type": "application/json"}
        inquiry_get = requests.get(server_domain + "/api/v1/inquiry?id=" + str(inquiry_id),headers=headers)
        inquiry_data = inquiry_get.json()
        data = inquiry_data["inquiry_data"]


        # APIで取得したinquiry情報
        form = {
            "company":data["from_company"],
            "company_kana":"カカシ",
            "manager":data["person"],
            "manager_kana":data["person_kana"],
            "phone":data["from_tel"],
            "fax":data["from_fax"],
            "address":data["address"],
            "mail":data["from_mail"],
            "subjects":data["headline"],
            "body":data["content"]
        }
        print("get inquiry data")
        
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
            # apiで送信済みにする
            s = score.result("SUCCESS",session_code,generate_code)
            print("---------------------------------")
            print("現在の送信精度：",s)
            print("---------------------------------")
        elif go == "NG":
            print("送信エラー。。。")
            score.rimes.append(False)
            sql = 'UPDATE contact_trackings SET status = ?, sended_at = ? WHERE contact_url = ? AND worker_id = ?'
            data = ("自動送信エラー",datetime.datetime.now(),url,worker_id)
            # apiで送信エラーにする
            s = score.result("FAILED",session_code,generate_code)
            print("---------------------------------")
            print("送信精度：",s)
            print("---------------------------------")

        
        

        for bst in self.boottime:
            if bst['generation_key'] == generate_code and bst['finalist'] == True:
                print('quit.')
                score.graph_make(session_code,form["company"])
                for index,item in enumerate(self.boottime):
                    if item['reserve_key'] == session_code:
                        self.boottime.pop(index)
            elif bst['generation_key'] == generate_code and bst['finalist'] == False:
                print('not final.')
                
    def inset_schedule(self):
        for num,trigger in enumerate(self.boottime):
            strtime = trigger["time"]
            datetimes = datetime.datetime.strptime(strtime, '%Y-%m-%d %H:%M:%S')
            dtnow = datetime.datetime.now()
            hour = str(datetimes.hour)
            minute = str(datetimes.minute+self.fime)
            if dtnow.year == datetimes.year and dtnow.month == datetimes.month and dtnow.day == datetimes.day:
                if trigger["subscription"] == True:
                    print(trigger["generation_key"] + "はすでに準備できています。")
                else:
                    trigger["subscription"] = True
                    if (num - self.sabun) >= 4:
                        newminute = 0
                        print(num,"-",self.sabun,"=",(num-self.sabun))
                        if (num - self.sabun) == 5:
                            print("reach!")
                            self.sabun += 5
                            self.fime += 1

                        if int(minute) > 59:
                            if int(minute) > 119:
                                newminute = str(120-int(minute))
                            else:
                                newminute = str(60-int(minute))
                            print(trigger["generation_key"] + "を"+ str(int(hour)).zfill(2)+'時'+str(int(newminute)*-1).zfill(2)+"分にスケジュールしました。")
                            schedule.every().day.at(str(int(hour)).zfill(2)+':'+str(int(newminute)*-1).zfill(2)).do(self.boot,trigger["url"],trigger["inquiry_id"],trigger["worker_id"],trigger["reserve_key"],trigger["generation_key"])
                        else:
                            schedule.every().day.at(hour.zfill(2)+':'+minute.zfill(2)).do(self.boot,trigger["url"],trigger["inquiry_id"],trigger["worker_id"],trigger["reserve_key"],trigger["generation_key"])
                            print(trigger["generation_key"] + "を"+ str(int(hour)).zfill(2)+'時'+minute.zfill(2)+"分にスケジュールしました。")
                    else:
                        newminute = 0
                        print(minute)
                        if int(minute) > 59:
                            if int(minute) > 119:
                                newminute = str(120-int(minute))
                                print(newminute)
                            else:
                                newminute = str(60-int(minute))
                            schedule.every().day.at(str(int(hour))+':'+str(int(newminute)*-1).zfill(2)).do(self.boot,trigger["url"],trigger["inquiry_id"],trigger["worker_id"],trigger["reserve_key"],trigger["generation_key"])
                            print(trigger["generation_key"] + "を"+ str(int(hour)).zfill(2)+'時'+str(int(newminute)*-1).zfill(2)+"分にスケジュールしました。")
                        else:
                            schedule.every().day.at(hour.zfill(2)+':'+minute.zfill(2)).do(self.boot,trigger["url"],trigger["inquiry_id"],trigger["worker_id"],trigger["reserve_key"],trigger["generation_key"])
                            print(trigger["generation_key"] + "を"+ str(int(hour)).zfill(2)+'時'+minute.zfill(2)+"分にスケジュールしました。")
            else:
                print('このデータは今日準備できません。')


sched = BackgroundScheduler(daemon=True,job_defaults={'max_instances': 10})
sched.add_job(scheds,'interval',minutes=1) 
sched.start()
                
    

                
m = Mother()
#データ投下
@app.route('/api/v1/rocketbumb',methods=['POST'])
def rocketbumb():
    try:
        worker_id = request.json['worker_id']
        inquiry_id = request.json['inquiry_id']
        try:
            contact_url = request.json['contact_url']
        except KeyError as e:
            contact_url = ''

        scheduled_date = request.json['date']
        customers_key = request.json['customers_code']
        reserve_key = request.json['reserve_code']
        generation_key = request.json['generation_code']
        company_name = request.json['company_name']

        rvbot = m.reserve(worker_id,inquiry_id,company_name,contact_url,scheduled_date,reserve_key,generation_key)

        print('[200] API is active!!')
        return jsonify({'code':200,'message':generation_key})
    
    except Exception as e:
        print('[500] API Error')
        print(e)
        headers = {"content-type": "application/json"}
        data = {"title":f"{e.__class__.__name__}によるエラー","message":f"システムで以下のエラーが発生しました。\n\n{traceback.format_exception_only(type(e), e)}","status":"error"}
        #message_post = requests.post(server_domain + "/api/v1/pycall",data=json.dumps(data),headers=headers)
        return abort(500)




if __name__ == "__main__":
    app.run(port=6500,debug=True)