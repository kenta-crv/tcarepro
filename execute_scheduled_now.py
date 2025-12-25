import sqlite3
from datetime import datetime, timedelta
import os

# Get the database path
db_path = os.path.join(os.path.dirname(__file__), 'db', 'development.sqlite3')

conn = sqlite3.connect(db_path)
cur = conn.cursor()

# Find submissions that are scheduled for future (sended_at in future or status is 自動送信予定)
# These are the ones showing as "Scheduled" in the dashboard
cur.execute('''
    SELECT id, scheduled_date, contact_url, status, sended_at 
    FROM contact_trackings 
    WHERE (
        status = ? 
        OR (status IN ('送信済', '送信成功') AND sended_at > datetime('now'))
    )
    AND email_received = 0
    ORDER BY id DESC
''', ('自動送信予定',))

results = cur.fetchall()

if results:
    # Set all to run starting 1 minute from now (staggered by 20 seconds each for faster execution)
    base_time = datetime.now() + timedelta(minutes=1)
    updated_count = 0
    
    print("=" * 80)
    print(f"Found {len(results)} scheduled submissions to execute NOW")
    print("=" * 80)
    print()
    
    for index, (ct_id, scheduled_date, contact_url, status, sended_at) in enumerate(results):
        # Stagger submissions by 20 seconds each for faster execution
        new_scheduled_time = (base_time + timedelta(seconds=index * 20)).strftime('%Y-%m-%d %H:%M:%S')
        
        # Reset to "自動送信予定" status and update scheduled_date to run now
        cur.execute('''
            UPDATE contact_trackings 
            SET status = ?, 
                scheduled_date = ?, 
                sended_at = NULL 
            WHERE id = ?
        ''', ('自動送信予定', new_scheduled_time, ct_id))
        
        updated_count += 1
        company_name = contact_url.split('/')[-2] if contact_url else 'Unknown'
        print(f'[{index + 1}] Updated ID: {ct_id}')
        print(f'    Company: {company_name}')
        print(f'    Old status: {status}')
        print(f'    Old scheduled: {scheduled_date}')
        if sended_at:
            print(f'    Old sended_at: {sended_at}')
        print(f'    New scheduled: {new_scheduled_time} (will execute in ~1 minute)')
        print(f'    URL: {contact_url[:70]}...' if contact_url and len(contact_url) > 70 else f'    URL: {contact_url or "N/A"}')
        print()
    
    conn.commit()
    print("=" * 80)
    print(f'✅ Successfully updated {updated_count} submissions to execute NOW!')
    print(f'   First submission will run at: {base_time.strftime("%Y-%m-%d %H:%M:%S")}')
    print(f'   Last submission will run at: {(base_time + timedelta(seconds=(updated_count-1) * 20)).strftime("%Y-%m-%d %H:%M:%S")}')
    print()
    print(f'   ⚡ Python bootio.py will pick these up in the next Reservation Check!!!')
    print(f'   ⚡ Submissions will execute within 1-2 minutes!')
    print(f'   ⚡ Watch your Python bootio.py window for execution logs!')
    print("=" * 80)
else:
    print('✗ No scheduled submissions found to execute')

conn.close()

