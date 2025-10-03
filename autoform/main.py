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

matplotlib.use("agg")

app = Flask(__name__)


# ローカルで起動する場合は、『python main.py local』
# とコマンドを書いてください。

statment = ""

try:
    statment = sys.argv[1]
except Exception as e:
    statment = ""

print(statment)

# statment = sys.argv[0]
server_domain = "http://tcare.pro"

if statment == "local":
    server_domain = "http://localhost:3000"

print(server_domain)


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

    def result(self, status_keyword, session_code, generation_code, inquiry_id, reason=""):
        print(f"Score.result: status={status_keyword}, code={generation_code}, inquiry_id={inquiry_id}, reason='{reason[:100]}...'") # Log reason
        
        truecount = sum(1 for r in self.rimes if r is True)
        current_accuracy_percentage = 0
        if self.rimes: # Avoid ZeroDivisionError if self.rimes is empty
            current_accuracy_percentage = int((truecount / len(self.rimes)) * 100)
        # self.sumdic.append(current_accuracy_percentage) # If you still want to track historical percentages

        self.sended.append(generation_code)

        api_endpoint_path = "/api/v1/pybotcenter_failed" # Default to failed
        if status_keyword == "SUCCESS":
            api_endpoint_path = "/api/v1/pybotcenter_success"
            
        # Parameters for the Rails API
        api_params = {
            "generation_code": generation_code,
            "inquiry_id": str(inquiry_id),
            "reason": str(reason)[:255], # Truncate reason if it's too long for DB/URL
            "session_code": session_code # Pass session_code back to Rails
        }
        
        try:
            print(f"Sending to Rails: {server_domain + api_endpoint_path} with params {api_params}")
            # Using GET with params, ensure Rails API endpoints are designed for this
            r = requests.get(server_domain + api_endpoint_path, params=api_params, timeout=15)
            r.raise_for_status() 
            print(f"Rails callback response: {r.status_code} for {generation_code}")
            
            # Store for graph_make
            self.result_data.append({
                "session_code": session_code,
                "generation_code": generation_code,
                "status": "送信済" if status_keyword == "SUCCESS" else "送信エラー",
                "inquiry_id": inquiry_id,
                "reason": reason # Store full reason here
            })
        except requests.exceptions.RequestException as e:
            print(f"Failed to send {status_keyword} data to Rails for {generation_code}: {e}")
            # Log this failure, but don't let it stop the Python script if Rails is down
            # Potentially add to result_data with a note about Rails communication failure
            self.result_data.append({
                "session_code": session_code,
                "generation_code": generation_code,
                "status": "送信エラー" if status_keyword == "FAILED" else "送信済 (Rails CB Fail)",
                "inquiry_id": inquiry_id,
                "reason": reason + " | Rails CB Error: " + str(e)
            })


        return f"{current_accuracy_percentage}%"


    def graph_make(self, session_code, company_name, representative_generate_code):
        print(f"Graph_make called for session: {session_code}")
        
        session_results = [res for res in self.result_data if res.get("session_code") == session_code]
        
        if not session_results:
            print(f"No results found for session {session_code} to make graph.")
            return

        success_count = sum(1 for res in session_results if res.get("status") == "送信済")
        error_count = len(session_results) - success_count
        
        # Removed local graph plotting with pyplot as it's complex in a server environment
        # and Rails side should handle presentation.
        # self.count = 0 # Resetting self.count here, ensure this is intended.

        headers = {"content-type": "application/json"}
        
        # Notify Rails about batch completion and stats
        autoform_result_payload = {
            "session_code": session_code,
            "success_count": success_count,
            "failed_count": error_count,
            # "representative_generate_code": representative_generate_code, # If Rails needs one code from batch
            # "company_name": company_name # If Rails needs this for the batch record
        }
        try:
            print(f"Sending autoform_data_register to Rails: {autoform_result_payload}")
            reg_response = requests.post(
                f"{server_domain}/api/v1/autoform_data_register",
                data=json.dumps(autoform_result_payload),
                headers=headers,
                timeout=15
            )
            reg_response.raise_for_status()
            print(f"Autoform batch data registered with Rails for session {session_code}. Response: {reg_response.status_code}")
        except requests.exceptions.RequestException as e:
            print(f"Failed to send autoform_data_register to Rails for session {session_code}: {e}")
        
        # Clean up result_data for this session to free up memory
        self.result_data = [res for res in self.result_data if res.get("session_code") != session_code]
        print(f"Cleaned result_data for session {session_code}")

    def graph_summary(self):
        print("グラフサマリーを作成します。")

        sqldata = []

        frame = {"score": []}

        # SQL抽出
        success = 0
        error = 0
        for curs in self.result_data:
            if curs[3] == "送信済":
                success += 1
            elif curs[3] == "送信不可":
                error += 1

        df = pd.DataFrame(frame, columns=["score"])
        df.columns = ["Score"]

        date = tdatetime.strftime("%Y-%m-%d")

        pyplot.title(date + "今まで実行したグラフ", fontname="Hiragino sans")
        pyplot.rcParams["font.family"] = "Hiragino sans"

        df["status"].plot.pie(autopct="%.f%%")

        df.plot()
        cd = os.path.abspath(".")
        tdatetime = datetime.datetime.now()
        strings = tdatetime.strftime("%Y%m%d-%H%M%S")
        pyplot.savefig(cd + "/autoform/graph_image/day/" + strings + ".png")

        headers = {"content-type": "application/json"}
        data = {
            "title": "autoの実行完了",
            "message": "autoの実行を全て終えました。グラフ",
            "status": "notify",
        }
        message_post = requests.post(
            server_domain + "/api/v1/pycall", data=json.dumps(data), headers=headers
        )


score = Score()


class Mother:
    def __init__(self):
        self.boottime = []
        self.count = 0
        self.sabun = 0
        self.fime = 0

    def add(
        self,
        company_name,
        time,
        url,
        inquiry_id,
        worker_id,
        reserve_key,
        generation_key,
    ):
        print("@bot railsから " + company_name + "の送信データを受け取りました。 [", time, url, "]")
        if len(self.boottime) == 0:
            print(score.count)
            self.boottime.append(
                {
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
                }
            )
        else:
            if self.boottime[-1]["reserve_key"] == reserve_key:
                print(score.count)
                sum = self.boottime[-1]["priority"] + 1
                self.boottime[-1]["finalist"] = False
                self.boottime.append(
                    {
                        "time": time,
                        "url": url,
                        "company_name": company_name,
                        "inquiry_id": inquiry_id,
                        "worker_id": worker_id,
                        "priority": sum,
                        "reserve_key": reserve_key,
                        "generation_key": generation_key,
                        "subscription": False,
                        "finalist": True,
                    }
                )

    def check(self, url, inquiry_id, worker_id):
        for time in self.boottime:
            if (
                time["url"] == url
                and time["inquiry_id"] == inquiry_id
                and time["worker_id"] == worker_id
            ):
                return True

        return False

    def reserve(
        self,
        worker_id,
        inquiry_id,
        company_name,
        contact_url,
        scheduled_date,
        reserve_key,
        generation_key,
    ):
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
                    self.add(
                        company_name,
                        scheduled_date,
                        contact_url,
                        inquiry_id,
                        worker_id,
                        reserve_key,
                        generation_key,
                    )
                    self.inset_schedule()
                else:
                    print("@bot 無効なURL")
                    raise ValueError("httpからはじまっていません。")

    def boot(self, url, inquiry_id, worker_id, session_code, generate_code):
        print(f"Boot process started for generation_code: {generate_code}, URL: {url}, Session: {session_code}")
        
        for sended_id in score.sended:
            if sended_id == generate_code:
                print(f"Skipping {generate_code}: Already processed in this run.")
                return 0 # Return a value that indicates it was skipped, or handle appropriately

        headers = {"content-type": "application/json"}
        inquiry_data_payload = {}
        form_company_name_for_graph = "UnknownCompany" # Default
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
            # Call score.result with the failure reason
            s_res = score.result("FAILED", session_code, generate_code, inquiry_id, f"inquiry_fetch_failed: {str(e)}")
            print(f"Score after inquiry fetch failure: {s_res}")
            # Check if this was the last item for the session to potentially call graph_make
            self.check_and_finalize_batch(session_code, form_company_name_for_graph, generate_code)
            return 1 # Indicate processing happened, albeit with failure

        form_details = {
            "company": data.get("from_company"),
            "company_kana": data.get("from_company_kana") or data.get("company_kana") or "カカシ",
            "manager": data.get("person"),
            "manager_first": data.get("person_first_name"), # Assuming Rails might send split names
            "manager_last": data.get("person_last_name"),
            "manager_kana": data.get("person_kana"),
            "manager_first_kana": data.get("person_first_name_kana"),
            "manager_last_kana": data.get("person_last_name_kana"),
            "phone": data.get("from_tel"),
            "fax": data.get("from_fax"),
            "zip": data.get("zip_code"), # Assuming Rails might send zip
            "address": data.get("address"),
            "mail": data.get("from_mail"),
            "subjects": data.get("title") or data.get("headline"),
            "body": data.get("content"),
            "url": data.get("url") # This is the target company's URL, not the inquiry form URL
        }
        print(f"Form data prepared for {generate_code}: { {k: (v[:30] + '...' if isinstance(v, str) and len(v) > 30 else v) for k,v in form_details.items()} }")

        submission_outcome = {"status": "NG", "reason": "selenium_module_not_initialized"}
        try:
            # hardware.Place_enter's __init__ should call logicer internally after fetching the page.
            # url here is the contact_url for the specific company.
            automaton = hardware.Place_enter(url, form_details) 
            if not automaton.form: # Check if Place_enter successfully found a form
                submission_outcome = {"status": "NG", "reason": "form_not_found_by_place_enter_init"}
            else:
                submission_outcome = automaton.go_selenium()
            print(f"Selenium submission outcome for {generate_code}: {submission_outcome}")
        except Exception as e:
            submission_outcome = {"status": "NG", "reason": f"selenium_execution_error: {str(e)}"}
            print(f"Error during Place_enter or go_selenium for {generate_code}: {e}")
            traceback.print_exc()

        final_status_for_rails = "FAILED"
        submission_reason = submission_outcome.get('reason', 'unknown_selenium_error')

        if submission_outcome.get("status") == "OK":
            print(f"Submission successful for {generate_code}. Reason: {submission_reason}")
            score.rimes.append(True)
            final_status_for_rails = "SUCCESS"
        else:
            print(f"Submission failed for {generate_code}. Reason: {submission_reason}")
            score.rimes.append(False)
            
        s_res = score.result(final_status_for_rails, session_code, generate_code, inquiry_id, submission_reason)
        print(f"Current accuracy after {generate_code}: {s_res}")
        
        # Check if this is the last item for the session and call graph_make
        self.check_and_finalize_batch(session_code, form_company_name_for_graph, generate_code)
        return 1 # Indicate processing happened
    
    def check_and_finalize_batch(self, session_code, company_name, current_generation_code):
        """
        Checks if all tasks for a given session_code have been processed (i.e., are in score.sended).
        If so, calls score.graph_make.
        """
        # Find all generation_keys originally scheduled for this session_code
        original_tasks_for_session = [
            task.get("generation_key") for task in self.boottime 
            if task.get("reserve_key") == session_code
        ]

        if not original_tasks_for_session:
            # This might happen if boottime was cleared or if session_code is unexpected
            print(f"Warning: No original tasks found in boottime for session_code {session_code} during finalization check.")
            # Check if there are any results in score.result_data for this session as a fallback
            if any(item.get("session_code") == session_code for item in score.result_data) and \
               not any(item.get("session_code") == session_code and item.get("generation_code") not in score.sended for item in score.result_data): # A bit redundant
                print(f"Finalizing batch for session_code {session_code} based on score.result_data (boottime empty for session).")
                score.graph_make(session_code, company_name, current_generation_code) # Pass one gen_code as representative
                # Clean up boottime for this session if any stragglers (though ideally it's managed elsewhere)
                self.boottime = [item for item in self.boottime if item.get("reserve_key") != session_code]
            return

        all_session_tasks_processed = True
        for task_gen_key in original_tasks_for_session:
            if task_gen_key not in score.sended:
                all_session_tasks_processed = False
                break
        
        if all_session_tasks_processed:
            print(f"All tasks for session_code {session_code} processed. Finalizing batch.")
            score.graph_make(session_code, company_name, current_generation_code) # Pass one gen_code as representative
            
            # Clean up completed tasks for this session from the active queue self.boottime
            # This ensures that if the script restarts, these aren't re-queued from an old state
            # (assuming boottime is not persisted across restarts without other mechanisms)
            initial_boottime_len = len(self.boottime)
            self.boottime = [item for item in self.boottime if item.get("reserve_key") != session_code]
            print(f"Tasks for session_code {session_code} removed from active queue (removed {initial_boottime_len - len(self.boottime)} items).")
        else:
            # Count remaining tasks for this session
            remaining_tasks = [tk for tk in original_tasks_for_session if tk not in score.sended]
            print(f"Session {session_code} not yet complete. {len(remaining_tasks)} tasks remaining: {remaining_tasks[:5]}...")


    def inset_schedule(self):
        for num, trigger in enumerate(self.boottime):
            if trigger.get("subscription") == True: # Already scheduled
                # print(f"Task {trigger.get('generation_key')} for {trigger.get('company_name')} already scheduled.")
                continue

            strtime = trigger["time"] # Expects "YYYY-MM-DD HH:MM:SS"
            try:
                datetimes = datetime.datetime.strptime(strtime, "%Y-%m-%d %H:%M:%S")
            except ValueError:
                try: # Try ISO format as well, which Rails might send
                    datetimes = datetime.datetime.fromisoformat(strtime)
                except ValueError:
                    print(f"Error: Could not parse date string '{strtime}' for {trigger.get('generation_key')}. Skipping schedule.")
                    continue
            
            dtnow = datetime.datetime.now()
            
            # Simplified scheduling logic: schedule for the given day and time.
            # The complex minute adjustment logic (self.fime, self.sabun) is kept for now but might need review.
            # It seems to aim at distributing tasks if many are scheduled for the exact same minute.

            # Only schedule if it's for today or a future date (APScheduler handles past jobs appropriately by default - runs immediately if overdue)
            # However, the original code has a specific check for today.
            if dtnow.date() > datetimes.date():
                print(f"Task {trigger.get('generation_key')} for {datetimes.strftime('%Y-%m-%d %H:%M')} is in the past. APScheduler will run it ASAP if not already run.")
                # APScheduler handles this, but you might want to log or skip explicitly if it's too old.
            
            # The original code has complex logic for adjusting minutes (self.fime, self.sabun)
            # This is an attempt to simplify while respecting the intent if it's about load distribution.
            # For now, directly using the parsed time.
            # If the minute adjustment is critical, it needs to be carefully integrated.
            
            target_hour_str = str(datetimes.hour).zfill(2)
            target_minute_str = str(datetimes.minute).zfill(2) # Ignoring self.fime for now for simplicity

            # The original code had a complex minute adjustment based on 'num - self.sabun'
            # This part is highly specific and kept as is, but might be a candidate for simplification
            # if the goal is just to run at the specified time.
            effective_minute = datetimes.minute + self.fime # self.fime seems to be an offset
            effective_hour = datetimes.hour

            if (num - self.sabun) >= 4: # This condition triggers minute adjustments
                print(f"Adjusting schedule for {trigger['generation_key']} due to task index.")
                if (num - self.sabun) == 5: # Original logic: == 4, then == 5
                    print("reach! (adjusting sabun and fime)")
                    self.sabun += 5
                    self.fime += 1 # This fime increments, affecting subsequent tasks in this scheduling pass
                
                effective_minute = datetimes.minute + self.fime # Re-calculate with potentially updated self.fime

            # Handle minute overflow
            if effective_minute >= 60:
                effective_hour += effective_minute // 60
                effective_minute %= 60
            
            # Handle hour overflow (e.g., if it pushes to next day, APScheduler handles date part)
            effective_hour %= 24 

            target_hour_str = str(effective_hour).zfill(2)
            target_minute_str = str(effective_minute).zfill(2)

            # Schedule the job
            schedule.every().day.at(f"{target_hour_str}:{target_minute_str}").do(
                self.boot,
                trigger["url"],
                trigger["inquiry_id"],
                trigger["worker_id"],
                trigger["reserve_key"],
                trigger["generation_key"],
            ).tag(trigger["reserve_key"], trigger["generation_key"]) # Tagging jobs for potential management

            trigger["subscription"] = True # Mark as scheduled
            print(
                f"Scheduled {trigger['generation_key']} for {trigger['company_name']} at {target_hour_str}:{target_minute_str} "
                f"(Original: {datetimes.strftime('%H:%M')}, Adjusted fime: {self.fime})"
            )


sched = BackgroundScheduler(daemon=True, job_defaults={"max_instances": 1})
sched.add_job(scheds, "interval", minutes=0.1)
sched.start()


m = Mother()

# 配列を取得するべきでは？
# これでは１レコードずつしかの処理しかできない。
# データ投下
@app.route("/api/v1/rocketbumb", methods=["POST"])
def rocketbumb():
    try:
        # ... (existing request parsing) ...
        worker_id = request.json["worker_id"]
        inquiry_id = request.json["inquiry_id"]
        contact_url = request.json.get("contact_url") # Use .get for safety
        scheduled_date_str = request.json["date"] # Expecting "YYYY-MM-DD HH:MM:SS" or ISO
        # customers_key = request.json["customers_code"] # Unused in m.reserve
        reserve_key = request.json["reserve_code"]
        generation_key = request.json["generation_code"]
        company_name = request.json["company_name"]

        if not contact_url:
            print("@bot contact_url is missing or empty. Cannot schedule.")
            # Optionally, send a failure back to Rails or log prominently
            # For now, m.reserve will raise FileNotFoundError
            # return jsonify({"code": 400, "message": "contact_url is required"}), 400

        m.reserve( # Call the instance method
            worker_id,
            inquiry_id,
            company_name,
            contact_url,
            scheduled_date_str, # Pass the string, inset_schedule will parse
            reserve_key,
            generation_key,
        )

        print(f"[200] API rocketbumb: Task {generation_key} for {company_name} reserved.")
        return jsonify({"code": 200, "message": generation_key})

    except KeyError as e:
        print(f"[400] API Error: Missing key in rocketbumb request: {e}")
        traceback.print_exc()
        # Notify Rails about the error
        error_data = {"title":f"API Key Error: {e}","message":f"Missing key in /api/v1/rocketbumb request: {traceback.format_exc()}","status":"error"}
        try:
            requests.post(server_domain + "/api/v1/pycall",data=json.dumps(error_data),headers={"content-type": "application/json"}, timeout=5)
        except Exception as notify_e:
            print(f"Failed to notify Rails about API error: {notify_e}")
        return jsonify({"code": 400, "message": f"Missing key: {e}"}), 400
    except Exception as e:
        print(f'[500] API Error in rocketbumb: {e}')
        traceback.print_exc()
        # Notify Rails about the error
        error_data = {"title":f"API Error: {e.__class__.__name__}","message":f"System error in /api/v1/rocketbumb: {traceback.format_exc()}","status":"error"}
        try:
            requests.post(server_domain + "/api/v1/pycall",data=json.dumps(error_data),headers={"content-type": "application/json"}, timeout=5)
        except Exception as notify_e:
            print(f"Failed to notify Rails about API error: {notify_e}")
        return jsonify({"code": 500, "message": "Internal server error"}), 500


if __name__ == "__main__":
    app.run(host='0.0.0.0', port=6400, debug=True, use_reloader=False)
