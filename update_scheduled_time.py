import sqlite3
from datetime import datetime, timedelta
import os

# Get the database path
db_path = os.path.join(os.path.dirname(__file__), 'db', 'development.sqlite3')

conn = sqlite3.connect(db_path)
cur = conn.cursor()

# Find the latest pending submission
cur.execute('SELECT id, scheduled_date FROM contact_trackings WHERE status = ? ORDER BY id DESC LIMIT 1', ('自動送信予定',))
result = cur.fetchone()

if result:
    ct_id, old_time = result
    # Set to 2 minutes from now
    new_time = (datetime.now() + timedelta(minutes=2)).strftime('%Y-%m-%d %H:%M:%S')
    
    # Update the scheduled_date
    cur.execute('UPDATE contact_trackings SET scheduled_date = ? WHERE id = ?', (new_time, ct_id))
    conn.commit()
    
    print(f'✓ Updated ContactTracking ID: {ct_id}')
    print(f'  Old time: {old_time}')
    print(f'  New time: {new_time}')
    print(f'\n✅ Python service will pick this up in the next Reservation Check!!! (within 1 minute)')
    print(f'   Watch your Python bootio.py window for execution!')
else:
    print('✗ No pending submissions found')

conn.close()

