from flask import *
import datetime
import schedule
import hardware
from matplotlib import pyplot

app = Flask(__name__)

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

score = Score()

class Mother:
    def __init__(self):
        self.boottime = []
        self.count = 0

    def add(self,time,url,sender_id,inquiry_id,worker_id,reserve_key,generation_key):
        print('@bot railsから新しいデータを受け取りました。 [',time,url,sender_id,']')
        if len(self.boottime) == 0:
            self.count += 1
            self.boottime.append({'time':time,'url':url,'inquiry_id':inquiry_id,'worker_id':worker_id,'priority':1,'reserve_key':reserve_key,'generation_key':generation_key,'subscription':False})
            self.inset_schedule(time,url,sender_id,1,worker_id,reserve_key,generation_key)
        else:
            if self.boottime[-1]['reserve_key'] == reserve_key:
                self.count += 1
                sum = self.boottime[-1]['priority'] + 1
                self.boottime.append({'time':time,'url':url,'inquiry_id':inquiry_id,'worker_id':worker_id,'priority':sum,'reserve_key':reserve_key,'generation_key':generation_key,'subscription':False})

    def check(self,url,sender_id,worker_id):
        for time in self.boottime:
            if time["url"] == url and time["sender_id"] == sender_id and time["worker_id"] == worker_id:
                return True
            
        return False
    def reserve(self,worker_id,sender_id,inquiry_id,contact_url,scheduled_date,reserve_key,generation_key):
        c = self.check(contact_url,sender_id,worker_id)
        if c == True:
            print("@bot すでにデータがあります。")
            raise FileExistsError("すでにデータがあります。")
        elif c == False:
            if contact_url == "":
                print("@bot URLがありません。")
                raise FileNotFoundError("URLがありません。")
            else:
                if contact_url.startswith('http'):
                    self.add(scheduled_date,contact_url,sender_id,inquiry_id,worker_id,reserve_key,generation_key)
                else:
                    print("Invaild URL!!")
                    raise ValueError("httpからはじまっていません。")
                
    def boot(url,sender_id,worker_id,session_code,generate_code):
        # inquiryをAPIで取得する
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
            # apiで送信済みにする
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
            # apiで送信エラーにする
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
                
    def inset_schedule(self):
        sabun = 0
        fime = 1
        for num,trigger in enumerate(self.boottime):
            strtime = trigger["time"]
            datetimes = datetime.datetime.strptime(strtime, '%Y-%m-%d %H:%M:%S')
            dtnow = datetime.datetime.now()
            hour = str(datetimes.hour)
            minute = str(datetimes.minute+fime)
            if dtnow.year == datetimes.year and dtnow.month == datetimes.month and dtnow.day == datetimes.day:
                if trigger["subscription"] == True:
                    print(trigger["generation_key"] + "はすでに準備できています。")
                else:
                    trigger["subscription"] = True
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
                            print(trigger["generation_key"] + "をスケジュールしました。")
                            schedule.every().day.at(str(int(hour)+1).zfill(2)+':'+str(int(newminute)*-1).zfill(2)).do(self.boot,trigger["url"],trigger["sender_id"],num,trigger["worker_id"],trigger["reserve_key"],trigger["generation_key"])
                        else:
                            schedule.every().day.at(hour.zfill(2)+':'+minute.zfill(2)).do(self.boot,trigger["url"],trigger["sender_id"],num,trigger["worker_id"],trigger["reserve_key"],trigger["generation_key"])
                            print(trigger["generation_key"] + "をスケジュールしました。")
                    else:
                        newminute = 0
                        print(minute)
                        if int(minute) > 59:
                            if int(minute) > 119:
                                newminute = str(120-int(minute))
                                print(newminute)
                            else:
                                newminute = str(60-int(minute))
                            print(trigger["generation_key"] + "をスケジュールしました。")
                            schedule.every().day.at(str(int(hour)+1)+':'+str(int(newminute)*-1).zfill(2)).do(boot,trigger["url"],trigger["sender_id"],num,trigger["worker_id"],trigger["reserve_key"],trigger["generation_key"])
                        else:
                            print(trigger["generation_key"] + "をスケジュールしました。")
                            schedule.every().day.at(hour.zfill(2)+':'+minute.zfill(2)).do(boot,trigger["url"],trigger["sender_id"],num,trigger["worker_id"],trigger["reserve_key"],trigger["generation_key"])
            else:
                print('このデータは今日準備できません。')

                
    

                
m = Mother()
#データ投下
@app.route('/api/v1/rocketbumb',methods=['POST'])
def rocketbumb():
    try:
        worker_id = request.json['worker_id']
        inquiry_id = request.json['inquiry_id']
        sender_id = request.json['sender_id']
        try:
            contact_url = request.json['contact_url']
        except KeyError as e:
            contact_url = ''

        scheduled_date = request.json['date']
        customers_key = request.json['customers_code']
        reserve_key = request.json['reserve_code']
        generation_key = request.json['generation_code']

        rvbot = m.reserve(worker_id,sender_id,inquiry_id,contact_url,scheduled_date,reserve_key,generation_key)

        print('[200] API is active!!')
        return jsonify({'code':200,'message':generation_key})
    
    except Exception as e:
        print('[500] API Error')
        print(e)
        return abort(500)


if __name__ == "__main__":
    app.run(port=6500,debug=True)