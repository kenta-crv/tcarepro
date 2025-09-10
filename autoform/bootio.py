import sqlite3
import sched, time
import hardware
import schedule
import datetime
import pandas
import os
from matplotlib import pyplot
import random
import string
import pandas as pd
import traceback

print(os.getcwd())

dbname = "../db/development.sqlite3"
s = sched.scheduler()


class Score:
    def __init__(self):
        self.score = 0
        self.count = 0
        self.rimes = []
        self.sumdic = []
        self.time = ""

    def result(self, sender_id, worker_id, url, status, session_code):
        truecount = 0
        for tuc in self.rimes:
            if tuc == True:
                truecount += 1

        sum = int(int((truecount / len(self.rimes)) * 100))
        self.sumdic.append(sum)

        # 統計システム入れる
        conn = sqlite3.connect(dbname)
        cur = conn.cursor()

        # SQL検索
        # sql = "INSERT INTO autoform_shot (sender_id, worker_id, url, status, current_score, session_code) values (?,?,?,?,?,?)"
        # data = (sender_id, worker_id, url, status, sum, session_code)
        # cur.execute(sql, data)

        # conn.commit()
        # conn.close()

        try:
            return str(sum) + "%"
        except ZeroDivisionError as e:
            return "0%"

    def graph_make(self, session_code):
        # DB接続
        conn = sqlite3.connect(dbname)
        cur = conn.cursor()

        # SQL検索（パラメータ化も検討してください）
        cur.execute('SELECT * FROM autoform_shot WHERE session_code = "' + session_code + '"')
        print("グラフを作成します。")

        success = 0
        error = 0

        # SQL抽出：各レコードのステータスを集計
        for curs in cur.fetchall():
            if curs[3] == "送信済":
                success += 1
            elif curs[3] == "送信エラー":
                error += 1

        total = success + error
        if total == 0:
            print("送信データがありません。グラフは作成されません。")
            conn.close()
            return

        # DataFrame作成（行ラベル：送信済、送信エラー、1列目を送信率）
        df = pd.DataFrame(data=[success, error], index=["送信済", "送信エラー"], columns=["送信率"])

        # 日本語フォントの設定
        pyplot.rcParams["font.family"] = "Hiragino sans"
        cd = os.path.abspath(".")
        tdatetime = datetime.datetime.now()

        # パイチャート作成
        df["送信率"].plot.pie(autopct="%.f%%")

        strings = tdatetime.strftime("%Y%m%d-%H%M%S")
        pyplot.title(self.time + "に" + str(self.count) + "回実行したグラフ", fontname="Hiragino sans")
        pyplot.savefig(cd + "/autoform/graph_image/shot/" + strings + ".png")

        conn.commit()
        conn.close()


    def graph_summary(self):
        conn = sqlite3.connect(dbname)
        cur = conn.cursor()

        # SQL検索
        cur.execute("SELECT * FROM autoform_shot")

        print("グラフサマリーを作成します。")

        sqldata = []

        frame = {"score": []}

        # SQL抽出
        success = 0
        error = 0
        for curs in cur.fetchall():
            if curs[3] == "送信済":
                success += 1
            elif curs[3] == "送信不可":
                error += 1

        df = pd.DataFrame(frame, columns=["score"])
        df.columns = ["Score"]


        df["status"].plot.pie(autopct="%.f%%")

        df.plot()
        cd = os.path.abspath(".")
        tdatetime = datetime.datetime.now()

        date = tdatetime.strftime("%Y-%m-%d")

        pyplot.title(date + "今まで実行したグラフ", fontname="Hiragino sans")
        pyplot.rcParams["font.family"] = "Hiragino sans"

        strings = tdatetime.strftime("%Y%m%d-%H%M%S")
        pyplot.savefig(cd + "/autoform/graph_image/day/" + strings + ".png")
        conn.commit()
        conn.close()


class Reservation:
    def __init__(self):
        self.boottime = []

    def add(self, time, url, sender_id, priority, worker_id, unique_id):
        print("New Records!! [", time, url, sender_id, priority, "]")
        self.boottime.append(
            {
                "time": time,
                "url": url,
                "sender_id": sender_id,
                "worker_id": worker_id,
                "priority": priority,
                "unique_id": unique_id,
            }
        )

    def check(self, url, sender_id):
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
    return "".join(randlst)


def boot(url, sender_id, count, worker_id, session_code, unique_id):
    conn = sqlite3.connect(dbname)
    # sqliteを操作するカーソルオブジェクトを作成
    cur = conn.cursor()
    id = sender_id
    form = {}
    print(id)
    cur.execute('SELECT * FROM inquiries WHERE sender_id = "' + str(id) + '"')
    for index, item in enumerate(cur.fetchall()):
        form = {
            "company": item[1],
            "company_kana": "kakasi",
            "manager": item[3],
            "manager_kana": item[4],
            "phone": item[5],
            "fax": item[6],
            "address": item[9],
            "mail": item[7],
            "subjects": item[10],
            "body": item[11],
        }

    try:
        hard = hardware.Place_enter(url, form)
        go = hard.go_selenium()
        print(go)
    except Exception as e:
        go = "NG"
        print("system error")
        print(e)
        traceback.print_exc()  # エラー発生箇所や行番号が表示されます

    if go == "OK":
        print("正常に送信されました。")
        score.rimes.append(True)
        sql = "UPDATE contact_trackings SET status = ?, sended_at = ? WHERE contact_url = ? AND worker_id = ?"
        sql = "UPDATE contact_trackings SET status = ?, sended_at = ? WHERE id = ?"
        data = ("送信済", datetime.datetime.now(), unique_id)
        cur.execute(sql, data)
        conn.commit()
        conn.close()
        s = score.result(sender_id, worker_id, url, "送信済", session_code)
        print("---------------------------------")
        print("送信精度：", s)
        print("---------------------------------")
    elif go == "NG":
        print("送信エラー。。。")
        score.rimes.append(False)
        sql = "UPDATE contact_trackings SET status = ?, sended_at = ? WHERE contact_url = ? AND worker_id = ?"
        sql = "UPDATE contact_trackings SET status = ?, sended_at = ? WHERE id = ?"
        data = ("自動送信エラー", datetime.datetime.now(), unique_id)
        cur.execute(sql, data)
        conn.commit()
        conn.close()
        s = score.result(sender_id, worker_id, url, "送信エラー", session_code)
        print("unique_id", unique_id)
        print("---------------------------------")
        print("---------------------------------")
        print("送信精度：", s)
        print("---------------------------------")

    print(score.count - 1)
    print(count)

    # if count == score.count - 1:
    #     score.graph_make(session_code)


def sql_reservation():
    print("Reservation Check!!!")
    conn = sqlite3.connect(dbname)
    score.count = 0
    # sqliteを操作するカーソルオブジェクトを作成
    cur = conn.cursor()
    # 自動送信予定のデータを取得
    cur.execute(
        'SELECT contact_url,sender_id,scheduled_date,callback_url,worker_id,id FROM contact_trackings WHERE status = "自動送信予定"'
    )
    #  送信セッションを識別するためのランダムな16文字のコードを生成
    session_code = randomname(16)

    # 取得した全レコードを順に処理
    for index, item in enumerate(cur.fetchall()):
        url = item[0]
        gotime = item[2]
        callback = item[3]
        worker_id = item[4]
        sender_id = item[1]
        unique_id = item[5]

        # 現在処理中の予約の送信予定日時を score オブジェクトにセットしています（後続のグラフ作成などで利用）。
        score.time = gotime

        # すでに同じURLと送信元IDが予約リストに登録されているかをチェック
        c = reservation.check(url, sender_id)
        # if c == True:
        #     print("This already exists")
        #     pass
        # URLが None（存在しない）なら、送信不能と判断
        if url == None:
            print("No URL!!")
            # idけで一意に決まるのでロジック変更
            # sql = "UPDATE contact_trackings SET status = ?, sended_at = ? WHERE callback_url = ? AND worker_id = ?"
            # data = ("自動送信エラー", datetime.datetime.now(), callback, worker_id)
            sql = "UPDATE contact_trackings SET status = ?, sended_at = ? WHERE id = ?"
            data = ("自動送信エラー", datetime.datetime.now(), unique_id)
            cur.execute(sql, data)
        else:
            # URLが http で始まる（正しい形式）の場合は、予約リストに追加し、score.count（登録件数）を1増やす
            if url.startswith("http"):
                reservation.add(gotime, url, sender_id, index, worker_id, unique_id)
                score.count += 1
            # URLが http で始まらない場合もエラーとみなしてDBの状態を更新
            else:
                print("Invaild URL!!")
                # sql = "UPDATE contact_trackings SET status = ?, sended_at = ? WHERE callback_url = ? AND worker_id = ?"
                print("自動送信エラー", datetime.datetime.now(), callback, worker_id)
                # data = ("自動送信エラー", datetime.datetime.now(), callback, worker_id)
                # idけで一意に決まるのでロジック変更
                sql = "UPDATE contact_trackings SET status = ?, sended_at = ? WHERE id = ?"
                data = ("自動送信エラー", datetime.datetime.now(), unique_id)
                cur.execute(sql, data)
    
    # DB接続を終了。
    conn.commit()
    conn.close()


    # 予約リスト内の各予約データ（trigger）に対して処理を行う
    # ループ回数を数えて、4件ごとに1分後ろへずらす
    # sabun や fime は不要なケースが多いので省略
    for i, trigger in enumerate(reservation.alltime()):
        strtime = trigger["time"]  # "YYYY-MM-DD HH:MM:SS" 形式
        # 予約日時をパース
        scheduled_dt = datetime.datetime.strptime(strtime, "%Y-%m-%d %H:%M:%S")

        now = datetime.datetime.now()

        # 「予約日が今日の日付」と一致するかチェック
        # 元コードでは year,month,day を比較していたが、.date() でまとめて比較可能
        if scheduled_dt.date() == now.date():
            print(f"このデータは起動する準備ができています -> {strtime}")

            # もし同じ日に複数の予約がある場合、4件ごとに1分後ろにずらす
            # たとえば 0-3件目は同時刻, 4-7件目は +1分, 8-11件目は +2分 というイメージ
            shift_minutes = (i // 4)
            scheduled_dt += datetime.timedelta(minutes=shift_minutes)

            # schedule ライブラリに渡すために "HH:MM" 形式の文字列を作成
            schedule_str = scheduled_dt.strftime("%H:%M")

            # 毎日 schedule_str の時刻に実行されるように登録
            schedule.every().day.at(schedule_str).do(
                boot,
                trigger["url"],
                trigger["sender_id"],
                i,  # num に相当
                trigger["worker_id"],
                session_code,
                trigger["unique_id"],
            )
            print(f"登録 -> {schedule_str} / shift={shift_minutes}分後ろ倒し")

    print("-----------------------------------------")
    print(f"      {score.count} 件登録しました。        ")
    print("-----------------------------------------")


schedule.every(1).minutes.do(sql_reservation)
# schedule.every(1).days.do(score.graph_summary)

sql_reservation()

while True:
    schedule.run_pending()
    time.sleep(2)
    print("running")