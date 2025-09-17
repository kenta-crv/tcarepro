import sqlite3
import os

def create_tables():
    db_path = '/app/db/development.sqlite3'
    os.makedirs(os.path.dirname(db_path), exist_ok=True)
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    tables_sql = [
        '''CREATE TABLE IF NOT EXISTS contact_trackings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT NOT NULL,
            customer_id INTEGER NOT NULL,
            inquiry_id INTEGER NOT NULL,
            sender_id INTEGER,
            worker_id INTEGER,
            status TEXT NOT NULL,
            contact_url TEXT,
            sended_at DATETIME,
            callbacked_at DATETIME,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL,
            scheduled_date DATETIME,
            callback_url TEXT,
            customers_code TEXT,
            auto_job_code TEXT
        )''',
        '''CREATE TABLE IF NOT EXISTS inquiries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            headline TEXT,
            from_company TEXT,
            person TEXT,
            person_kana TEXT,
            from_tel TEXT,
            from_fax TEXT,
            from_mail TEXT,
            url TEXT,
            address TEXT,
            title TEXT,
            content TEXT,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL,
            sender_id INTEGER
        )'''
    ]
    
    for sql in tables_sql:
        cursor.execute(sql)
    
    conn.commit()
    conn.close()
    print('✅ Database tables created successfully!')

if __name__ == '__main__':
    create_tables()
