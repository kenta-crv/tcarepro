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
import sqlite3
from threading import Lock
import random
import string

app = Flask (__name__)
app.config ['JSON_AS_ASCII'] = False

# Database connection with correct path for external access - FIXED
def get_db_connection():
    # Try multiple possible database paths
    possible_paths = [
        "/myapp/db/development.sqlite3",
        "/app/db/development.sqlite3", 
        "./db/development.sqlite3",
        "../db/development.sqlite3"
    ]
    
    for db_path in possible_paths:
        try:
            # Create directory if it doesn't exist
            os.makedirs(os.path.dirname(db_path), exist_ok=True)
            
            conn = sqlite3.connect(db_path)
            conn.row_factory = sqlite3.Row
            
            # Test the connection
            cursor = conn.cursor()
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table' LIMIT 1")
            cursor.fetchone()
            
            print(f"Successfully connected to database at: {db_path}")
            return conn
            
        except sqlite3.Error as e:
            print(f"Failed to connect to {db_path}: {e}")
            continue
    
    # If all paths fail, create in-memory database
    print("All database connections failed. Using in-memory database as fallback.")
    return sqlite3.connect(":memory:")

# Local server configuration - FIXED to handle both local and production
statment = ""
try:
    statment = sys.argv[1]
except Exception as e:
    statment = ""

# Use environment variable or default to local
server_domain = os.environ.get('RAILS_SERVER', 'http://app:3000')
if statment == "local":
    server_domain = "http://localhost:3000"

print(f"Server domain: {server_domain}")

def scheds():
    print('running...')
    try:
        schedule.run_pending()
    except Exception as e:
        print(f"Error in scheds: {e}")

class Score:
    def __init__(self):
        self.score = 0
        self.count = 0
        self.rimes = []
        self.sumdic = []
        self.result_data = []
        self.sended = []
        self.time = ""
        self.lock = Lock()

    def result(self, status_keyword, session_code, generation_code, inquiry_id, reason="", detection_method=""):
        print(f"Score.result: status={status_keyword}, code={generation_code}, inquiry_id={inquiry_id}, reason='{reason[:100]}...'")
        
        with self.lock:
            truecount = sum(1 for r in self.rimes if r is True)
            current_accuracy_percentage = 0
            if self.rimes:
                current_accuracy_percentage = int((truecount / len(self.rimes)) * 100)

            self.sended.append(generation_code)

            api_endpoint_path = "/api/v1/pybotcenter_failed"
            if status_keyword == "SUCCESS":
                api_endpoint_path = "/api/v1/pybotcenter_success"
                
            api_params = {
                "generation_code": generation_code,
                "inquiry_id": str(inquiry_id),
                "reason": str(reason)[:255],
                "session_code": session_code,
                "detection_method": detection_method
            }
            
            try:
                print(f"Sending to Rails: {server_domain + api_endpoint_path} with params {api_params}")
                # Use POST instead of GET for better data handling
                r = requests.post(
                    server_domain + api_endpoint_path,
                    data=api_params,
                    timeout=15
                )
                r.raise_for_status() 
                print(f"Rails callback response: {r.status_code} for {generation_code}")
                
                self.result_data.append({
                    "session_code": session_code,
                    "generation_code": generation_code,
                    "status": "送信済" if status_keyword == "SUCCESS" else "送信エラー",
                    "inquiry_id": inquiry_id,
                    "reason": reason,
                    "detection_method": detection_method
                })
            except requests.exceptions.RequestException as e:
                print(f"Failed to send {status_keyword} data to Rails for {generation_code}: {e}")
                # Fallback: Try GET if POST fails
                try:
                    r = requests.get(server_domain + api_endpoint_path, params=api_params, timeout=15)
                    print(f"Fallback GET response: {r.status_code}")
                except Exception as fallback_error:
                    print(f"Fallback GET also failed: {fallback_error}")
                
                self.result_data.append({
                    "session_code": session_code,
                    "generation_code": generation_code,
                    "status": "送信エラー" if status_keyword == "FAILED" else "送信済 (Rails CB Fail)",
                    "inquiry_id": inquiry_id,
                    "reason": reason + " | Rails CB Error: " + str(e),
                    "detection_method": detection_method
                })

            return f"{current_accuracy_percentage}%"

    def graph_make(self, session_code, company_name, current_generation_code):
        print(f"Graph_make called for session: {session_code}")
        
        session_results = [res for res in self.result_data if res.get("session_code") == session_code]
        
        if not session_results:
            print(f"No results found for session {session_code} to make graph.")
            return

        success_count = sum(1 for res in session_results if res.get("status") == "送信済")
        error_count = len(session_results) - success_count
        
        headers = {"content-type": "application/json"}
        
        autoform_result_payload = {
            "session_code": session_code,
            "success_count": success_count,
            "failed_count": error_count,
        }
        
        try:
            print(f"Sending autoform_data_register to Rails: {autoform_result_payload}")
            # Use POST instead of GET
            reg_response = requests.post(
                f"{server_domain}/api/v1/autoform_data_register",
                data=autoform_result_payload,
                headers=headers,
                timeout=15
            )
            reg_response.raise_for_status()
            print(f"Autoform batch data registered with Rails for session {session_code}. Response: {reg_response.status_code}")
        except requests.exceptions.RequestException as e:
            print(f"Failed to send autoform_data_register to Rails for session {session_code}: {e}")
            # Fallback: Try GET if POST fails
            try:
                reg_response = requests.get(
                    f"{server_domain}/api/v1/autoform_data_register",
                    params=autoform_result_payload,
                    timeout=15
                )
                print(f"Fallback GET response: {reg_response.status_code}")
            except Exception as fallback_error:
                print(f"Fallback GET also failed: {fallback_error}")
        
        with self.lock:
            self.result_data = [res for res in self.result_data if res.get("session_code") != session_code]
            print(f"Cleaned result_data for session {session_code}")

score = Score()

class Mother:
    def __init__(self):
        self.boottime = []
        self.count = 0
        self.sabun = 0
        self.fime = 0
        self.lock = Lock()

    def add(self, company_name, time, url, inquiry_id, worker_id, reserve_key, generation_key):
        print("@bot railsから " + company_name + "の送信データを受け取りました。 [", time, url, "]")
        
        with self.lock:
            if len(self.boottime) == 0:
                self.boottime.append({
                    "time": time,
                    "url": url,
                    "company_name": company_name,
                    "inquiry_id": inquiry_id,
                    "worker_id": worker_id,
                    "priority": 1,
                    "reserve_key": reserve_key,
                    "generation_key": generation_key,
                    "subscription": False,
                    "finalist": True,
                })
            else:
                if self.boottime[-1]["reserve_key"] == reserve_key:
                    sum_priority = self.boottime[-1]["priority"] + 1
                    self.boottime[-1]["finalist"] = False
                    self.boottime.append({
                        "time": time,
                        "url": url,
                        "company_name": company_name,
                        "inquiry_id": inquiry_id,
                        "worker_id": worker_id,
                        "priority": sum_priority,
                        "reserve_key": reserve_key,
                        "generation_key": generation_key,
                        "subscription": False,
                        "finalist": True,
                    })

    def check(self, url, inquiry_id, worker_id):
        for time_item in self.boottime:
            if (time_item["url"] == url and 
                time_item["inquiry_id"] == inquiry_id and 
                time_item["worker_id"] == worker_id):
                return True
        return False

    def reserve(self, worker_id, inquiry_id, company_name, contact_url, scheduled_date, reserve_key, generation_key):
        print("🍺")
        c = self.check(contact_url, inquiry_id, worker_id)
        if c == True:
            print("@bot すでにデータがあります。")
        elif c == False:
            if contact_url == "":
                print("@bot URLがありません。")
                raise FileNotFoundError("URLがありません。")
            else:
                if contact_url.startswith("http"):
                    self.add(company_name, scheduled_date, contact_url, inquiry_id, worker_id, reserve_key, generation_key)
                    self.inset_schedule()
                else:
                    print("@bot 無効なURL")
                    raise ValueError("httpからはじまっていません。")

    def execute_form_submission(self, url, form_details, generate_code, attempt):
        submission_outcome = {"status": "NG", "reason": "selenium_module_not_initialized"}
        detection_method = ""
        
        try:
            automaton = hardware.Place_enter(url, form_details)
            if not automaton.form:
                submission_outcome = {"status": "NG", "reason": "form_not_found_by_place_enter_init"}
            else:
                submission_outcome_value = automaton.go_selenium()
                submission_outcome = {"status": "OK", "reason": "success"} if submission_outcome_value == "OK" else {"status": "NG", "reason": submission_outcome_value}
                
                if submission_outcome_value == "OK":
                    detection_method = "multi_indicator"
                    
            print(f"Selenium submission outcome for {generate_code} (attempt {attempt + 1}): {submission_outcome}")
        except Exception as e:
            submission_outcome = {"status": "NG", "reason": f"selenium_execution_error: {str(e)}"}
            print(f"Error during Place_enter or go_selenium for {generate_code}: {e}")
            traceback.print_exc()
            
        return submission_outcome, detection_method

    def boot(self, url, inquiry_id, worker_id, session_code, generate_code):
        print(f"Boot process started for generation_code: {generate_code}, URL: {url}, Session: {session_code}")

        if generate_code in score.sended:
            print(f"Skipping {generate_code}: Already processed in this run.")
            return 0

        headers = {"content-type": "application/json"}
        inquiry_data_payload = {}
        form_company_name_for_graph = "UnknownCompany"
        
        try:
            inquiry_get_url = f"{server_domain}/api/v1/inquiry?id={str(inquiry_id)}"
            print(f"Fetching inquiry data from: {inquiry_get_url}")
            inquiry_get = requests.get(inquiry_get_url, headers=headers, timeout=10)
            inquiry_get.raise_for_status()
            inquiry_data_payload = inquiry_get.json()
            data = inquiry_data_payload.get("inquiry_data", {})
            if not data:
                 raise ValueError("Inquiry data is empty or not in expected format from Rails.")
            form_company_name_for_graph = data.get("from_company", "InquiryCompany")
        except Exception as e:
            print(f"Failed to get inquiry data for ID {inquiry_id}: {e}")
            score.rimes.append(False)
            s_res = score.result("FAILED", session_code, generate_code, inquiry_id, f"inquiry_fetch_failed: {str(e)}", "api_error")
            print(f"Score after inquiry fetch failure: {s_res}")
            self.check_and_finalize_batch(session_code, form_company_name_for_graph, generate_code)
            return 1

        form_details = {
            "company": data.get("from_company"),
            "company_kana": data.get("from_company_kana") or data.get("company_kana") or "カカシ",
            "manager": data.get("person"),
            "manager_first": data.get("person_first_name"),
            "manager_last": data.get("person_last_name"),
            "manager_kana": data.get("person_kana"),
            "manager_first_kana": data.get("person_first_name_kana"),
            "manager_last_kana": data.get("person_last_name_kana"),
            "phone": data.get("from_tel"),
            "fax": data.get("from_fax"),
            "zip": data.get("zip_code"),
            "address": data.get("address"),
            "mail": data.get("from_mail"),
            "subjects": data.get("title") or data.get("headline"),
            "body": data.get("content"),
            "url": data.get("url")
        }
        
        print(f"Form data prepared for {generate_code}")

        # Add email validation before form submission
        if form_details.get('mail'):
            email_valid = hardware.verify_email_delivery(form_details['mail'])
            if not email_valid:
                print(f"Email validation failed for {form_details['mail']}")
                score.rimes.append(False)
                s_res = score.result("FAILED", session_code, generate_code, inquiry_id, 
                                f"email_validation_failed: {form_details['mail']}", "smtp_validation")
                return 1

        max_retries = 3
        retry_delay = 5
        detection_method = ""
        final_status_for_rails = "FAILED"
        submission_reason = "unknown_error"
        
        for attempt in range(max_retries):
            try:
                submission_outcome, detection_method = self.execute_form_submission(url, form_details, generate_code, attempt)
                
                if submission_outcome.get("status") == "OK":
                    print(f"Submission successful for {generate_code} on attempt {attempt + 1}.")
                    score.rimes.append(True)
                    final_status_for_rails = "SUCCESS"
                    submission_reason = "success"
                    break
                else:
                    print(f"Submission failed for {generate_code} on attempt {attempt + 1}. Reason: {submission_outcome.get('reason', 'Unknown')}")
                    if attempt < max_retries - 1:
                        print(f"Retrying in {retry_delay} seconds...")
                        time.sleep(retry_delay)
                        retry_delay *= 2
                    else:
                        score.rimes.append(False)
                        final_status_for_rails = "FAILED"
                        submission_reason = submission_outcome.get('reason', 'max_retries_exceeded')
            
            except Exception as e:
                print(f"Error during submission attempt {attempt + 1}: {e}")
                if attempt < max_retries - 1:
                    print(f"Retrying in {retry_delay} seconds...")
                    time.sleep(retry_delay)
                    retry_delay *= 2
                else:
                    score.rimes.append(False)
                    final_status_for_rails = "FAILED"
                    submission_reason = f"system_error: {str(e)}"

        s_res = score.result(final_status_for_rails, session_code, generate_code, inquiry_id, submission_reason, detection_method)
        print(f"Current accuracy after {generate_code}: {s_res}")
        
        self.check_and_finalize_batch(session_code, form_company_name_for_graph, generate_code)
        return 1
    
    def check_and_finalize_batch(self, session_code, company_name, current_generation_code):
        with self.lock:
            original_tasks_for_session = [
                task.get("generation_key") for task in self.boottime 
                if task.get("reserve_key") == session_code
            ]

            if not original_tasks_for_session:
                if any(item.get("session_code") == session_code for item in score.result_data):
                    score.graph_make(session_code, company_name, current_generation_code)
                    self.boottime = [item for item in self.boottime if item.get("reserve_key") != session_code]
                return
            all_session_tasks_processed = True
            for task_gen_key in original_tasks_for_session:
                if task_gen_key not in score.sended:
                    all_session_tasks_processed = False
                    break
            
            if all_session_tasks_processed:
                print(f"All tasks for session_code {session_code} processed. Finalizing batch.")
                score.graph_make(session_code, company_name, current_generation_code)
                initial_boottime_len = len(self.boottime)
                self.boottime = [item for item in self.boottime if item.get("reserve_key") != session_code]
                print(f"Tasks for session_code {session_code} removed from active queue (removed {initial_boottime_len - len(self.boottime)} items).")
            else:
                remaining_tasks = [tk for tk in original_tasks_for_session if tk not in score.sended]
                print(f"Session {session_code} not yet complete. {len(remaining_tasks)} tasks remaining: {remaining_tasks[:5]}...")

    def inset_schedule(self):
        with self.lock:
            for num, trigger in enumerate(self.boottime):
                if trigger.get("subscription") == True:
                    continue

                strtime = trigger["time"]

                try:
                    datetimes = datetime.datetime.strptime(strtime, "%Y-%m-%d %H:%M:%S.%f")
                except ValueError:
                    try:
                        datetimes = datetime.datetime.strptime(strtime, "%Y-%m-%d %H:%M:%S")
                    except ValueError:
                        try:
                            datetimes = datetime.datetime.fromisoformat(strtime)
                        except ValueError:
                            print(f"Error: Could not parse date string '{strtime}' for {trigger.get('generation_key')}. Skipping schedule.")
                            continue
                
                dtnow = datetime.datetime.now()
                
                if dtnow.date() > datetimes.date():
                    print(f"Task {trigger.get('generation_key')} for {datetimes.strftime('%Y-%m-%d %H:%M')} is in the past. APScheduler will run it ASAP if not already run.")
                
                effective_minute = datetimes.minute + self.fime
                effective_hour = datetimes.hour

                if (num - self.sabun) >= 4:
                    print(f"Adjusting schedule for {trigger['generation_key']} due to task index.")
                    if (num - self.sabun) == 5:
                        print("reach! (adjusting sabun and fime)")
                        self.sabun += 5
                        self.fime += 1
                    
                    effective_minute = datetimes.minute + self.fime

                if effective_minute >= 60:
                    effective_hour += effective_minute // 60
                    effective_minute %= 60
                
                effective_hour %= 24

                target_hour_str = str(effective_hour).zfill(2)
                target_minute_str = str(effective_minute).zfill(2)

                schedule.every().day.at(f"{target_hour_str}:{target_minute_str}").do(
                    self.boot,
                    trigger["url"],
                    trigger["inquiry_id"],
                    trigger["worker_id"],
                    trigger["reserve_key"],
                    trigger["generation_key"],
                ).tag(trigger["reserve_key"], trigger["generation_key"])

                trigger["subscription"] = True
                print(
                    f"Scheduled {trigger['generation_key']} for {trigger['company_name']} at {target_hour_str}:{target_minute_str} "
                    f"(Original: {datetimes.strftime('%H:%M')}, Adjusted fime: {self.fime})"
                )

# NEW: Add the missing sql_reservation function
def sql_reservation():
    print("Reservation Check!!!")
    conn = get_db_connection()
    score.count = 0
    # sqliteを操作するカーソルオブジェクトを作成
    cur = conn.cursor()
    # 自動送信予定のデータを取得
    cur.execute(
        'SELECT contact_url,sender_id,scheduled_date,callback_url,worker_id,id FROM contact_trackings WHERE status = "自動送信予定"'
    )
    #  送信セッションを識別するためのランダムな16文字のコードを生成
    session_code = ''.join(random.choices(string.ascii_letters + string.digits, k=16))

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

        # すでに同じURL和送信元IDが予約リストに登録されているかをチェック
        c = m.check(url, sender_id, worker_id)
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
                m.add("Test Company", gotime, url, sender_id, worker_id, session_code, str(unique_id))
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
    for i, trigger in enumerate(m.boottime):
        strtime = trigger["time"]  # "YYYY-MM-DD HH:MM:SS" 形式
        # 予約日時をパース
        # Handle datetime with microseconds
        try:
            scheduled_dt = datetime.datetime.strptime(strtime, "%Y-%m-%d %H:%M:%S.%f")
        except ValueError:
            try:
                scheduled_dt = datetime.datetime.strptime(strtime, "%Y-%m-%d %H:%M:%S")
            except ValueError:
                print(f"Error: Could not parse date string '{strtime}'. Using current time.")
                scheduled_dt = datetime.datetime.now()

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

            # 毎日 schedule_str の時刻に実行されるように登続
            schedule.every().day.at(schedule_str).do(
                m.boot,
                trigger["url"],
                trigger["inquiry_id"],
                trigger["worker_id"],
                trigger["reserve_key"],
                trigger["generation_key"],
            )
            print(f"登録 -> {schedule_str} / shift={shift_minutes}分後ろ倒し")

    print("-----------------------------------------")
    print(f"      {score.count} 件登録しました。        ")
    print("-----------------------------------------")

# NEW: Add the missing boot function for direct access
def boot(url, inquiry_id, worker_id, session_code, generate_code):
    return m.boot(url, inquiry_id, worker_id, session_code, generate_code)

m = Mother()
sched = BackgroundScheduler(daemon=True, job_defaults={"max_instances": 1})
sched.add_job(sql_reservation, "interval", minutes=1)
sched.start()

@app.route("/api/v1/rocketbumb", methods=["POST"])
def rocketbumb():
    try:
        data = request.get_json()
        
        if not data:
            print("@bot No JSON data received")
            return jsonify({"code": 400, "message": "No JSON data received"}), 400

        worker_id = data.get("worker_id")
        inquiry_id = data.get("inquiry_id")
        contact_url = data.get("contact_url")
        scheduled_date_str = data.get("date")
        reserve_key = data.get("reserve_code")
        generation_key = data.get("generation_code")
        company_name = data.get("company_name")

        print(f"Received data: worker_id={worker_id}, inquiry_id={inquiry_id}, contact_url={contact_url}, date={scheduled_date_str}")

        if not contact_url:
            print("@bot contact_url is missing or empty. Cannot schedule.")
            return jsonify({"code": 400, "message": "contact_url is required"}), 400

        if not all([worker_id, inquiry_id, scheduled_date_str, reserve_key, generation_key, company_name]):
            print("@bot Missing required fields in JSON data")
            return jsonify({"code": 400, "message": "Missing required fields"}), 400

        m.reserve(
            worker_id,
            inquiry_id,
            company_name,
            contact_url,
            scheduled_date_str,
            reserve_key,
            generation_key,
        )

        print(f"[200] API rocketbumb: Task {generation_key} for {company_name} reserved.")
        return jsonify({"code": 200, "message": generation_key})

    except KeyError as e:
        print(f"[400] API Error: Missing key in rocketbumb request: {e}")
        traceback.print_exc()
        return jsonify({"code": 400, "message": f"Missing key: {e}"}), 400
        
    except Exception as e:
        print(f'[500] API Error in rocketbumb: {e}')
        traceback.print_exc()
        return jsonify({"code": 500, "message": "Internal server error"}), 500

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=6400, debug=False, use_reloader=False, threaded=True)