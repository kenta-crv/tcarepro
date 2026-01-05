import sqlite3
from datetime import datetime, timedelta
import os

# Get the database path
db_path = os.path.join(os.path.dirname(__file__), 'db', 'development.sqlite3')

conn = sqlite3.connect(db_path)
cur = conn.cursor()

# Find submissions that are scheduled (自動送信予定) - these are "waiting" to be sent
# Also find any sent submissions without email verification
cur.execute('''
    SELECT id, scheduled_date, contact_url, status, sended_at, email_received
    FROM contact_trackings 
    WHERE (
        (status = '自動送信予定' AND contact_url IS NOT NULL AND contact_url != '')
        OR 
        (status IN ('送信済', '送信成功') 
         AND (email_received = 0 OR email_received IS NULL) 
         AND contact_url IS NOT NULL 
         AND contact_url != '')
    )
    ORDER BY id ASC
''')

results = cur.fetchall()

if results:
    # Set all to run starting 30 seconds from now (staggered by 30 seconds each)
    base_time = datetime.now() + timedelta(seconds=30)
    updated_count = 0
    
    print("=" * 80)
    print(f"RESUBMIT WAITING SUBMISSIONS")
    print("=" * 80)
    print(f"Found {len(results)} submissions waiting to be sent or resubmitted")
    print("=" * 80)
    print()
    
    scheduled_count = 0
    waiting_email_count = 0
    
    for index, (ct_id, scheduled_date, contact_url, status, sended_at, email_received) in enumerate(results):
        # Stagger submissions by 30 seconds each to avoid conflicts
        new_time = (base_time + timedelta(seconds=index * 30)).strftime('%Y-%m-%d %H:%M:%S')
        
        if status == '自動送信予定':
            # Already scheduled, just update the time
            cur.execute('UPDATE contact_trackings SET scheduled_date = ? WHERE id = ?', (new_time, ct_id))
            scheduled_count += 1
            status_note = "Already scheduled"
        else:
            # Reset to scheduled status and clear email verification data
            cur.execute('''
                UPDATE contact_trackings 
                SET status = ?,
                    scheduled_date = ?,
                    email_received = 0,
                    email_received_at = NULL,
                    email_subject = NULL,
                    email_from = NULL,
                    email_matched_at = NULL,
                    sended_at = NULL,
                    sending_started_at = NULL,
                    sending_completed_at = NULL,
                    response_data = NULL
                WHERE id = ?
            ''', ('自動送信予定', new_time, ct_id))
            waiting_email_count += 1
            status_note = f"Resubmitting (was {status})"
        
        updated_count += 1
        print(f'[{index + 1}] ID: {ct_id}')
        print(f'    {status_note}')
        print(f'    New scheduled: {new_time}')
        print(f'    URL: {contact_url[:70]}...' if contact_url and len(contact_url) > 70 else f'    URL: {contact_url or "N/A"}')
        print()
    
    conn.commit()
    
    total_duration_minutes = (len(results) * 30) / 60.0
    last_time = base_time + timedelta(seconds=(len(results) - 1) * 30)
    
    print("=" * 80)
    print(f'✅ Successfully updated {updated_count} submissions!')
    print(f'   - Already scheduled: {scheduled_count}')
    print(f'   - Resubmitting (waiting for email): {waiting_email_count}')
    print()
    print(f'   First submission will run at: {base_time.strftime("%Y-%m-%d %H:%M:%S")}')
    print(f'   Last submission will run at: {last_time.strftime("%Y-%m-%d %H:%M:%S")}')
    print(f'   Total duration: {total_duration_minutes:.1f} minutes')
    print()
    print(f'   These will be submitted to check for auto-reply emails.')
    print(f'   Python bootio.py service will pick these up in the next Reservation Check!!! (within 1 minute)')
    print(f'   Make sure bootio.py is running with the fixed lxml library!')
    print("=" * 80)
else:
    print("=" * 80)
    print('✗ No waiting submissions found')
    print("=" * 80)
    print()
    # Show summary
    cur.execute('SELECT status, COUNT(*) FROM contact_trackings GROUP BY status')
    status_counts = cur.fetchall()
    if status_counts:
        print("Current status breakdown:")
        for status, count in status_counts:
            print(f"  {status}: {count}")

conn.close()

