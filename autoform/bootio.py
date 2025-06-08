import sqlite3
import datetime
import time
import os
import random
import string
import traceback
import argparse

import hardware

print(f"bootio.py CWD: {os.getcwd()}")

DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'db', 'development.sqlite3')
print(f"Using DB_PATH: {DB_PATH}")

# The Score class is not strictly necessary here if hardware.py returns detailed status
# and boot() updates the DB directly. Keeping it minimal.
class Score:
    def __init__(self):
        pass # No state needed for this simplified version

score = Score() # Instantiate if any part of hardware.py or future logic might expect it

def randomname(n): # This function is not used in the current flow but kept from original
    return "".join(random.choices(string.ascii_letters + string.digits, k=n))

# Modified boot function to use hardware.py
def boot(db_connection, url, unique_id, formdata_for_hardware, session_code="N/A", sender_id="N/A", worker_id="N/A"):
    # unique_id is contact_tracking.id
    # formdata_for_hardware is the dictionary prepared from command-line args
    print(f"Booting for: unique_id='{unique_id}', url='{url}', session_code='{session_code}'")
    
    status_to_set = "自動送信エラー" # Default to error
    submission_notes = "" # To store reason from hardware.py

    try:
        if not formdata_for_hardware:
            print(f"Error: Form data not provided for unique_id {unique_id}.")
            submission_notes = "Form data missing"
            # Fall through to finally to update DB
        else:
            print(f"Attempting submission to: {url} with provided form data.")
            # Instantiate Place_enter from hardware.py
            automation_instance = hardware.Place_enter(url, formdata_for_hardware)
            
            # Check if the form was found by hardware.py's init (optional, based on hardware.py's behavior)
            if not automation_instance.form and not automation_instance.iframe_mode: # if form is 0 and not iframe mode
                print(f"hardware.py's Place_enter could not find a form on {url} for unique_id {unique_id}")
                submission_notes = "No form found by hardware.py parser"
                # Fall through to finally
            else:
                # Call go_selenium to perform the submission
                result_dict = automation_instance.go_selenium()
                print(f"Selenium outcome for unique_id {unique_id}: {result_dict}")

                if result_dict.get("status") == "OK":
                    status_to_set = "送信済"
                else:
                    status_to_set = "自動送信エラー"
                submission_notes = result_dict.get("reason", "No reason provided by hardware.py")

    except Exception as e:
        status_to_set = "自動送信エラー"
        submission_notes = f"Exception during boot: {str(e)[:200]}"
        print(f"Exception during boot process for unique_id {unique_id}:")
        print(e)
        traceback.print_exc()
    finally:
        # Update the contact_trackings table
        try:
            cursor = db_connection.cursor()
            sql_update = """
                UPDATE contact_trackings 
                SET status = ?, sended_at = ?
                WHERE id = ?
            """
            cursor.execute(
                sql_update,
                (status_to_set, datetime.datetime.now(), unique_id),
            )
            db_connection.commit()
            print(f"DB updated for unique_id {unique_id}: status='{status_to_set}'")
        except Exception as db_e:
            print(f"Failed to update database for unique_id {unique_id}: {db_e}")
            traceback.print_exc()
            
    return status_to_set, submission_notes

def main():
    parser = argparse.ArgumentParser(description="Process a single autoform submission task using hardware.py.")
    parser.add_argument("--url", required=True, help="Contact form URL")
    parser.add_argument("--unique_id", required=True, type=int, help="Unique ID of the contact_tracking record (PK)")
    
    # Arguments for data that might be logged or used for context, but not directly for form fields yet
    parser.add_argument("--sender_id", help="Sender ID (for context/logging)")
    parser.add_argument("--worker_id", help="Worker ID (for context/logging, optional)")
    parser.add_argument("--session_code", help="Session code (auto_job_code, for context/logging)")

    # Based on hardware.py's self.formdata.get('key') usage.
    parser.add_argument("--company", help="Company Name")
    parser.add_argument("--company_kana", help="Company Name Kana")
    parser.add_argument("--manager", help="Manager Full Name")
    parser.add_argument("--manager_kana", help="Manager Full Name Kana")
    parser.add_argument("--manager_first", help="Manager First Name")
    parser.add_argument("--manager_last", help="Manager Last Name")
    parser.add_argument("--manager_first_kana", help="Manager First Name Kana")
    parser.add_argument("--manager_last_kana", help="Manager Last Name Kana")
    parser.add_argument("--pref", help="Prefecture (used by hardware.py if select, or part of address)") 
    parser.add_argument("--phone", help="Telephone Number (e.g., 090-1234-5678)")
    parser.add_argument("--phone0", help="Telephone Number Part 1 (if split)")
    parser.add_argument("--phone1", help="Telephone Number Part 2 (if split)")
    parser.add_argument("--phone2", help="Telephone Number Part 3 (if split)")
    parser.add_argument("--fax", help="Fax Number")
    parser.add_argument("--address", help="Full Address (or main part if split)")
    parser.add_argument("--address_pref", help="Address Prefecture (if split)")
    parser.add_argument("--address_city", help="Address City (if split)")
    parser.add_argument("--address_thin", help="Address Street/番地 (if split)")
    parser.add_argument("--zip", help="Zip Code")
    parser.add_argument("--mail", help="Email Address")
    parser.add_argument("--form_url", help="Website URL (if there's a field for it on the form)")
    parser.add_argument("--subjects", help="Inquiry Subject/Title")
    parser.add_argument("--body", help="Inquiry Body/Message")

    args = parser.parse_args()

    # --- Assemble the formdata dictionary for hardware.Place_enter ---
    formdata_for_hardware = {}
    # List all keys that hardware.py might .get() from self.formdata
    possible_formdata_keys = [
        'company', 'company_kana', 'manager', 'manager_kana', 
        'manager_first', 'manager_last', 'manager_first_kana', 'manager_last_kana',
        'pref', 'phone', 'phone0', 'phone1', 'phone2', 'fax', 
        'address', 'address_pref', 'address_city', 'address_thin', 'zip', 
        'mail', 'url', 'subjects', 'body'
    ]

    for key in possible_formdata_keys:
        value = getattr(args, key, None)
        if value is not None: # Only add if the argument was provided
            formdata_for_hardware[key] = value
    
    print(f"Formdata prepared for hardware.py: {formdata_for_hardware}")

    conn = None
    try:
        conn = sqlite3.connect(DB_PATH)
        print(f"Connected to database: {DB_PATH}")
        
        if not args.url or not args.url.startswith("http"):
            print(f"Invalid or missing URL: {args.url}. Marking as error for unique_id {args.unique_id}.")
            cursor = conn.cursor()
            sql_update_invalid_url = """
                UPDATE contact_trackings SET status = ?, sended_at = ?, notes = ? WHERE id = ?
            """
            cursor.execute(
                sql_update_invalid_url,
                ("自動送信エラー", datetime.datetime.now(), "Invalid or missing URL provided to bootio.py", args.unique_id),
            )
            conn.commit()
            return

        boot(conn, args.url, args.unique_id, formdata_for_hardware,
             session_code=args.session_code, sender_id=args.sender_id, worker_id=args.worker_id)

    except Exception as e:
        print(f"Unhandled error in main execution for unique_id {args.unique_id}: {e}")
        traceback.print_exc()
        if conn and args.unique_id:
            try:
                cursor = conn.cursor()
                sql_update_main_error = """
                    UPDATE contact_trackings SET status = ?, sended_at = ?, notes = ? WHERE id = ?
                """
                cursor.execute(
                    sql_update_main_error,
                    ("自動送信システムエラー", datetime.datetime.now(), f"bootio.py main error: {str(e)[:200]}", args.unique_id),
                )
                conn.commit()
            except Exception as final_db_e:
                 print(f"Failed to mark final error in DB for unique_id {args.unique_id}: {final_db_e}")
    finally:
        if conn:
            conn.close()
            print("Database connection closed.")

if __name__ == "__main__":
    print("bootio.py executed as command-line script.")
    main()