import sqlite3
from datetime import datetime, timedelta
import os

# Get the database path
db_path = os.path.join(os.path.dirname(__file__), 'db', 'development.sqlite3')

conn = sqlite3.connect(db_path)
cur = conn.cursor()

# All possible error statuses (based on the codebase)
error_statuses = [
    '自動送信エラー',
    '自動送信システムエラー',
    '自動送信システムエラー(Py無)',
    '自動送信システムエラー(スクリプト失敗)',
    '自動送信エラー(スクリプト未更新)',
    '自動送信エラー(タイムアウト)',
    '自動送信エラー(データ無)',
    '自動送信システムエラー(ワーカー例外)',
    'Automatic sending system error (no Python)',  # English version
    'Automatic sending system error (script failure)',  # English version
    'Automatic submission error'  # English version
]

# Build query to find all error submissions
placeholders = ','.join(['?' for _ in error_statuses])
query = f'SELECT id, status, contact_url, scheduled_date, sended_at FROM contact_trackings WHERE status IN ({placeholders}) ORDER BY id DESC'

cur.execute(query, error_statuses)
results = cur.fetchall()

if results:
    print("=" * 80)
    print(f"Found {len(results)} error submissions to reset")
    print("=" * 80)
    print()
    
    # Reset all to "自動送信予定" with scheduled time 2 minutes from now (staggered)
    base_time = datetime.now() + timedelta(minutes=2)
    updated_count = 0
    
    for index, (ct_id, old_status, contact_url, scheduled_date, sended_at) in enumerate(results):
        # Stagger submissions by 30 seconds each to avoid conflicts
        new_scheduled_time = (base_time + timedelta(seconds=index * 30)).strftime('%Y-%m-%d %H:%M:%S')
        
        # Reset status and clear sended_at
        cur.execute('''
            UPDATE contact_trackings 
            SET status = ?, 
                scheduled_date = ?,
                sended_at = NULL,
                response_data = NULL
            WHERE id = ?
        ''', ('自動送信予定', new_scheduled_time, ct_id))
        
        updated_count += 1
        print(f'[{index + 1}] Reset ID: {ct_id}')
        print(f'    Company URL: {contact_url[:70]}...' if contact_url and len(contact_url) > 70 else f'    Company URL: {contact_url or "N/A"}')
        print(f'    Old status: {old_status}')
        print(f'    New status: 自動送信予定')
        print(f'    New scheduled time: {new_scheduled_time}')
        print()
    
    conn.commit()
    print("=" * 80)
    print(f'✅ Successfully reset {updated_count} error submissions!')
    print(f'   First submission will run at: {base_time.strftime("%Y-%m-%d %H:%M:%S")}')
    print(f'   Last submission will run at: {(base_time + timedelta(seconds=(updated_count-1) * 30)).strftime("%Y-%m-%d %H:%M:%S")}')
    print(f'   Python bootio.py service will pick these up in the next Reservation Check!!! (within 1 minute)')
    print(f'   Watch your Python bootio.py window for execution!')
    print("=" * 80)
else:
    print('✗ No error submissions found to reset')

conn.close()

