import sqlite3
from datetime import datetime, timedelta
import os

# Get the database path
db_path = os.path.join(os.path.dirname(__file__), 'db', 'development.sqlite3')

conn = sqlite3.connect(db_path)
cur = conn.cursor()

# Find all pending submissions (自動送信予定) or scheduled ones with future sended_at
cur.execute('''
    SELECT id, scheduled_date, contact_url, status, sended_at 
    FROM contact_trackings 
    WHERE (status = ? OR (status IN ('送信済', '送信成功') AND sended_at > datetime('now')))
    ORDER BY id DESC
''', ('自動送信予定',))

results = cur.fetchall()

if results:
    # Set all to run starting 2 minutes from now (staggered by 30 seconds each)
    base_time = datetime.now() + timedelta(minutes=2)
    updated_count = 0
    
    print("=" * 80)
    print(f"Found {len(results)} scheduled submissions")
    print("=" * 80)
    print()
    
    for index, (ct_id, scheduled_date, contact_url, status, sended_at) in enumerate(results):
        # Stagger submissions by 30 seconds each to avoid conflicts
        new_time = (base_time + timedelta(seconds=index * 30)).strftime('%Y-%m-%d %H:%M:%S')
        
        # Update both scheduled_date and sended_at if it's in the future
        if status == '自動送信予定':
            # Update scheduled_date for pending submissions
            cur.execute('UPDATE contact_trackings SET scheduled_date = ? WHERE id = ?', (new_time, ct_id))
        elif sended_at:
            # Update sended_at for already "sent" but scheduled submissions
            cur.execute('UPDATE contact_trackings SET sended_at = ? WHERE id = ?', (new_time, ct_id))
        
        updated_count += 1
        print(f'[{index + 1}] Updated ID: {ct_id}')
        print(f'    Status: {status}')
        print(f'    Old scheduled: {scheduled_date}')
        if sended_at:
            print(f'    Old sended_at: {sended_at}')
        print(f'    New time: {new_time}')
        print(f'    URL: {contact_url[:70]}...' if contact_url and len(contact_url) > 70 else f'    URL: {contact_url or "N/A"}')
        print()
    
    conn.commit()
    print("=" * 80)
    print(f'✅ Successfully updated {updated_count} submissions!')
    print(f'   First submission will run at: {base_time.strftime("%Y-%m-%d %H:%M:%S")}')
    print(f'   Last submission will run at: {(base_time + timedelta(seconds=(updated_count-1) * 30)).strftime("%Y-%m-%d %H:%M:%S")}')
    print(f'   Python bootio.py service will pick these up in the next Reservation Check!!! (within 1 minute)')
    print(f'   Watch your Python bootio.py window for execution!')
    print("=" * 80)
else:
    print('✗ No scheduled submissions found')

conn.close()

