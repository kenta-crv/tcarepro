import sqlite3
from datetime import datetime, timedelta
import os

# Get the database path
db_path = os.path.join(os.path.dirname(__file__), 'db', 'development.sqlite3')

conn = sqlite3.connect(db_path)
cur = conn.cursor()

cur.execute('''
    SELECT id, scheduled_date, contact_url, status, sended_at, email_received
    FROM contact_trackings 
    WHERE status IN ('送信済', '送信成功')
      AND (email_received = 0 OR email_received IS NULL OR email_received = 'false')
      AND contact_url IS NOT NULL 
      AND contact_url != ''
      AND contact_url != ''
    ORDER BY id ASC
''')

results = cur.fetchall()

if results:
    # Set all to run starting 30 seconds from now (staggered by 30 seconds each)
    base_time = datetime.now() + timedelta(seconds=30)
    updated_count = 0
    
    print("=" * 80)
    print(f"RESUBMIT SUBMISSIONS WAITING FOR EMAIL")
    print("=" * 80)
    print(f"Found {len(results)} submissions waiting for email verification")
    print("=" * 80)
    print()
    
    for index, (ct_id, scheduled_date, contact_url, status, sended_at, email_received) in enumerate(results):
        new_time = (base_time + timedelta(seconds=index * 30)).strftime('%Y-%m-%d %H:%M:%S')
        
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
        
        updated_count += 1
        print(f'[{index + 1}] Reset ID: {ct_id}')
        print(f'    Old status: {status} (waiting for email)')
        print(f'    New status: 自動送信予定')
        print(f'    New scheduled: {new_time}')
        print(f'    URL: {contact_url[:70]}...' if contact_url and len(contact_url) > 70 else f'    URL: {contact_url or "N/A"}')
        print()
    
    conn.commit()
    
    total_duration_minutes = (len(results) * 30) / 60.0
    last_time = base_time + timedelta(seconds=(len(results) - 1) * 30)
    
    print("=" * 80)
    print(f'Successfully reset {updated_count} submissions')
    print(f'   First: {base_time.strftime("%Y-%m-%d %H:%M:%S")}')
    print(f'   Last: {last_time.strftime("%Y-%m-%d %H:%M:%S")}')
    print(f'   Duration: {total_duration_minutes:.1f} minutes')
    print("=" * 80)
else:
    print("=" * 80)
    print('No submissions found waiting for email verification')
    print("=" * 80)
    print()
    cur.execute('''
        SELECT 
            COUNT(*) as total_sent,
            SUM(CASE WHEN email_received = 1 THEN 1 ELSE 0 END) as with_email,
            SUM(CASE WHEN email_received = 0 OR email_received IS NULL THEN 1 ELSE 0 END) as waiting_email
        FROM contact_trackings 
        WHERE status IN ('送信済', '送信成功')
    ''')
    stats = cur.fetchone()
    if stats:
        total_sent, with_email, waiting_email = stats
        print("Current email verification status:")
        print(f"  Total sent: {total_sent}")
        print(f"  With email: {with_email}")
        print(f"  Waiting for email: {waiting_email}")

conn.close()

