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
# and boot() updates the DB directly.
class Score:
    def __init__(self):
        pass

score = Score()

def randomname(n): # This function is not used in the current flow but kept from original
    return "".join(random.choices(string.ascii_letters + string.digits, k=n))

# Modified boot function to use hardware.py
def boot(db_connection, url, unique_id, formdata_for_hardware, session_code="N/A", sender_id="N/A", worker_id="N/A"):
    # unique_id is contact_tracking.id
    # formdata_for_hardware is the dictionary prepared from command-line args
    print(f"Booting for: unique_id='{unique_id}', url='{url}', session_code='{session_code}'")
    
    status_to_set = "自動送信システムエラー" # Default status for unexpected issues in bootio
    detailed_reason_from_hardware = ""

    try:
        if not formdata_for_hardware:
            print(f"Error: Form data not provided for unique_id {unique_id}.")
            status_to_set = "Form data missing"
            # Fall through to finally to update DB
        else:
            print(f"Attempting submission to: {url} with provided form data.")
            automation_instance = hardware.Place_enter(url, formdata_for_hardware)
            
            # Check if any fields were mapped or iframe mode is detected
            mapped_fields = len(automation_instance.field_mappings) if hasattr(automation_instance, 'field_mappings') else 0
            iframe_mode = getattr(automation_instance, 'iframe_mode', False)
            
            if mapped_fields == 0 and not iframe_mode:
                print(f"hardware.py's Place_enter could not find mappable forms on {url}")
                status_to_set = "No mappable form found by parser on url"
            else:
                print(f"Form analysis: {mapped_fields} fields mapped, iframe_mode: {iframe_mode}")
                if mapped_fields > 0:
                    print(f"Mapped fields: {list(automation_instance.field_mappings.keys())}")
                
                # Proceed with form submission
                result_dict = automation_instance.go_selenium()
                
                if result_dict:
                    if result_dict.get('status') == 'OK':
                        reason = result_dict.get('reason', 'Unknown success')
                        if 'captcha' in reason.lower():
                            status_to_set = "CAPTCHA detected - requires manual intervention"
                        elif 'success' in reason.lower():
                            status_to_set = "送信成功"
                        else:
                            status_to_set = f"送信完了: {reason}"
                        print(f"SUCCESS: Form submission successful - {reason}")
                    else:
                        reason = result_dict.get('reason', 'Unknown failure')
                        status_to_set = f"送信失敗: {reason}"
                        print(f"FAILURE: Form submission failed - {reason}")
                else:
                    status_to_set = "No result returned from selenium automation"
                    print("ERROR: automation_instance.go_selenium() returned None/empty result")

    except Exception as e:
        status_to_set = f"Exception during processing: {str(e)[:200]}" # Store exception in status
        print(f"Exception during boot process for unique_id {unique_id}:")
        print(str(e))
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
            current_time = datetime.datetime.now()
            # Ensure status_to_set is not excessively long for the DB field, truncate if necessary.
            # Assuming the 'status' column can hold up to 255 chars. Adjust if different.
            status_for_db = status_to_set[:255] if status_to_set else "Unknown status"

            cursor.execute(
                sql_update,
                (status_for_db, current_time, unique_id),
            )
            db_connection.commit()
            print(f"DB updated for unique_id {unique_id}: status='{status_for_db}'")
        except Exception as db_e:
            print(f"Failed to update database for unique_id {unique_id}: {db_e}")
            traceback.print_exc()
            
    return status_to_set # Return the status that was attempted to be set

def main():
    parser = argparse.ArgumentParser(description="Process a single autoform submission task using hardware.py.")
    parser.add_argument("--url", required=True, help="Contact form URL")
    parser.add_argument("--unique_id", required=True, type=int, help="Unique ID of the contact_tracking record (PK)")
    
    parser.add_argument("--sender_id", help="Sender ID (for context/logging)")
    parser.add_argument("--worker_id", help="Worker ID (for context/logging, optional)")
    parser.add_argument("--session_code", help="Session code (auto_job_code, for context/logging)")

    # Form data arguments for hardware.py
    parser.add_argument("--company", help="Company Name")
    parser.add_argument("--company_kana", help="Company Name Kana")
    parser.add_argument("--manager", help="Manager Full Name")
    parser.add_argument("--manager_kana", help="Manager Full Name Kana")
    parser.add_argument("--manager_first", help="Manager First Name")
    parser.add_argument("--manager_last", help="Manager Last Name")
    parser.add_argument("--manager_first_kana", help="Manager First Name Kana")
    parser.add_argument("--manager_last_kana", help="Manager Last Name Kana")
    parser.add_argument("--pref", help="Prefecture (e.g., 東京都)") 
    parser.add_argument("--phone", help="Telephone Number (e.g., 090-1234-5678)")
    parser.add_argument("--phone0", help="Telephone Number Part 1 (if split)")
    parser.add_argument("--phone1", help="Telephone Number Part 2 (if split)")
    parser.add_argument("--phone2", help="Telephone Number Part 3 (if split)")
    parser.add_argument("--fax", help="Fax Number")
    parser.add_argument("--address", help="Full Address (or main part if split)")
    parser.add_argument("--address_pref", help="Address Prefecture (if split and separate field)")
    parser.add_argument("--address_city", help="Address City (if split)")
    parser.add_argument("--address_thin", help="Address Street/番地 (if split)")
    parser.add_argument("--zip", help="Zip Code")
    parser.add_argument("--mail", help="Email Address")
    parser.add_argument("--url_on_form", help="Website URL (if there's a field for it on the contact form)") 
    parser.add_argument("--subjects", help="Inquiry Subject/Title")
    parser.add_argument("--body", help="Inquiry Body/Message")

    args = parser.parse_args()

    formdata_for_hardware = {}
    possible_formdata_keys = [
        'company', 'company_kana', 'manager', 'manager_kana', 
        'manager_first', 'manager_last', 'manager_first_kana', 'manager_last_kana',
        'phone', 'phone0', 'phone1', 'phone2', 'fax', 
        'address', 'address_city', 'address_thin', 'zip', 'postal_code',
        'mail', 'subjects', 'body',
        'address_pref', 
        'address_pref_value',
        'url' 
    ]

    for key_in_dict in possible_formdata_keys:
        arg_name = key_in_dict
        if key_in_dict == 'url': 
            arg_name = 'url_on_form'
        elif key_in_dict == 'address_pref_value': 
            arg_name = 'pref'
        elif key_in_dict == 'address_pref' and not hasattr(args, 'address_pref'):
             arg_name = 'pref'
        elif key_in_dict == 'postal_code':
            arg_name = 'zip'  # Map postal_code to zip argument

        value = getattr(args, arg_name, None)
        if value is not None: 
            formdata_for_hardware[key_in_dict] = value
    
    # Additional mappings for zip/postal_code
    if args.zip is not None:
        formdata_for_hardware['postal_code'] = args.zip
        if 'zip' not in formdata_for_hardware:
            formdata_for_hardware['zip'] = args.zip
    
    if args.pref is not None:
        formdata_for_hardware['address_pref_value'] = args.pref 
        if 'address_pref' not in formdata_for_hardware : 
             formdata_for_hardware['address_pref'] = args.pref

    print(f"Formdata prepared for hardware.py: {formdata_for_hardware}")

    conn = None
    try:
        conn = sqlite3.connect(DB_PATH)
        print(f"Connected to database: {DB_PATH}")
        
        if not args.url or not (args.url.startswith("http://") or args.url.startswith("https://")):
            invalid_url_status = f"Invalid URL: {args.url}"[:255]
            print(f"{invalid_url_status}. Marking as error for unique_id {args.unique_id}.")
            cursor = conn.cursor()
            sql_update_invalid_url = """
                UPDATE contact_trackings SET status = ?, sended_at = ? WHERE id = ?
            """
            cursor.execute(
                sql_update_invalid_url,
                (invalid_url_status, datetime.datetime.now(), args.unique_id),
            )
            conn.commit()
            return

        boot(conn, args.url, args.unique_id, formdata_for_hardware,
             session_code=args.session_code, sender_id=args.sender_id, worker_id=args.worker_id)

    except Exception as e:
        main_error_status = f"bootio.py main error: {str(e)[:200]}"
        print(f"Unhandled error in main execution for unique_id {args.unique_id}: {e}")
        traceback.print_exc()
        if conn and args.unique_id: 
            try:
                cursor = conn.cursor()
                sql_update_main_error = """
                    UPDATE contact_trackings SET status = ?, sended_at = ? WHERE id = ?
                """
                cursor.execute(
                    sql_update_main_error,
                    (main_error_status, datetime.datetime.now(), args.unique_id),
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