import sqlite3
import os

# Path to the database file - FIXED for external access
base_dir = os.path.dirname(os.path.abspath(__file__))
db_name = "development.sqlite3"

possible_paths = [
    os.path.join(base_dir, "../../db/development.sqlite3"),
    os.path.join(base_dir, "../db/development.sqlite3"),
    os.path.join(base_dir, "db/development.sqlite3"),
    "/myapp/db/development.sqlite3",
    "/app/db/development.sqlite3"
]

db_path = None
for path in possible_paths:
    normalized_path = os.path.normpath(path)
    if os.path.exists(normalized_path):
        db_path = normalized_path
        print(f"Found database at: {db_path}")
        break

if not db_path:
    # Create directory and file if doesn't exist
    db_path = os.path.normpath(os.path.join(base_dir, "../db/development.sqlite3"))
    os.makedirs(os.path.dirname(db_path), exist_ok=True)
    print(f"Creating new database at: {db_path}")

print(f"Using database path: {db_path}")

# Ensure the directory exists
os.makedirs(os.path.dirname(db_path), exist_ok=True)

conn = None
try:
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    print("Successfully connected to the database.")

    # --- SQLITE Data Type Mappings from Rails ---
    # string, text -> TEXT
    # integer, limit: 8 -> INTEGER
    # datetime, date -> DATETIME (SQLite stores this as TEXT, NUMERIC, or INTEGER)
    # boolean -> INTEGER (0 for false, 1 for true)
    # float -> REAL
    # jsonb -> TEXT

    tables_sql = {
        "admins": """
        CREATE TABLE IF NOT EXISTS admins (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_name TEXT DEFAULT '' NOT NULL,
            email TEXT DEFAULT '' NOT NULL,
            encrypted_password TEXT DEFAULT '' NOT NULL,
            select_option TEXT, -- Renamed from 'select' as it's a keyword
            reset_password_token TEXT,
            reset_password_sent_at DATETIME,
            remember_created_at DATETIME,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL
        );""",
        "assignments": """
        CREATE TABLE IF NOT EXISTS assignments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            crowdwork_id INTEGER,
            worker_id INTEGER,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL
        );""",
        "attendances": """
        CREATE TABLE IF NOT EXISTS attendances (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER,
            month INTEGER,
            year INTEGER,
            hours_worked REAL,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL
        );""",
        "autoform_results": """
        CREATE TABLE IF NOT EXISTS autoform_results (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER,
            sender_id INTEGER,
            worker_id INTEGER,
            success_sent INTEGER,
            failed_sent INTEGER,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL
        );""",
        "calls": """
        CREATE TABLE IF NOT EXISTS calls (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            statu TEXT,
            time DATETIME,
            comment TEXT,
            customer_id INTEGER,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL,
            admin_id INTEGER,
            user_id INTEGER,
            latest_confirmed_time DATETIME
        );""",
        "contact_trackings": """
        CREATE TABLE IF NOT EXISTS contact_trackings (
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
        );""",
        "contacts": """
        CREATE TABLE IF NOT EXISTS contacts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            worker_id INTEGER,
            question TEXT,
            body TEXT,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL
        );""",
        "contracts": """
        CREATE TABLE IF NOT EXISTS contracts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            search TEXT -- Mapped from jsonb
            -- Add other columns from your schema.rb for contracts if they exist before the error
            -- For example:
            -- company_name TEXT,
            -- start_date DATE,
            -- end_date DATE,
            -- created_at DATETIME NOT NULL,
            -- updated_at DATETIME NOT NULL
        );""", # Note: schema.rb had an error dumping this table. Add columns manually if known.
        "counts": """
        CREATE TABLE IF NOT EXISTS counts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            company TEXT,
            title TEXT,
            statu TEXT,
            time DATETIME,
            comment TEXT,
            customer_id INTEGER,
            sender_id INTEGER,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL
        );""",
        "crowdworks": """
        CREATE TABLE IF NOT EXISTS crowdworks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            sheet TEXT,
            tab TEXT,
            area TEXT,
            business TEXT,
            genre TEXT,
            bad TEXT,
            attention TEXT,
            worker_id INTEGER,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL
        );""",
        "customers": """
        CREATE TABLE IF NOT EXISTS customers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            company TEXT,
            store TEXT,
            first_name TEXT,
            last_name TEXT,
            first_kana TEXT,
            last_kana TEXT,
            tel TEXT,
            tel2 TEXT,
            fax TEXT,
            mobile TEXT,
            industry TEXT,
            mail TEXT,
            url TEXT,
            people TEXT,
            postnumber TEXT,
            address TEXT,
            caption TEXT,
            remarks TEXT,
            status TEXT,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL,
            choice TEXT,
            title TEXT,
            other TEXT,
            url_2 TEXT,
            inflow TEXT,
            business TEXT,
            price TEXT,
            number TEXT,
            history TEXT,
            area TEXT,
            target TEXT,
            start DATE,
            contact_url TEXT,
            meeting TEXT,
            experience TEXT,
            extraction_count TEXT,
            send_count TEXT,
            worker_id INTEGER,
            genre TEXT,
            forever TEXT,
            customers_code TEXT,
            industry_code INTEGER,
            company_name TEXT,
            payment_date TEXT,
            industry_mail TEXT,
            worker_update_count_day INTEGER,
            worker_update_count_week INTEGER,
            worker_update_count_month INTEGER,
            sender_id INTEGER
        );""",
        "direct_mail_contact_trackings": """
        CREATE TABLE IF NOT EXISTS direct_mail_contact_trackings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT NOT NULL,
            customer_id INTEGER NOT NULL,
            sender_id INTEGER,
            worker_id INTEGER,
            status TEXT NOT NULL,
            contact_url TEXT,
            sended_at DATETIME,
            callbacked_at DATETIME,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL,
            user_id INTEGER
        );""",
        "email_histories": """
        CREATE TABLE IF NOT EXISTS email_histories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER NOT NULL,
            inquiry_id INTEGER NOT NULL,
            sent_at DATETIME NOT NULL,
            status TEXT DEFAULT 'pending' NOT NULL,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL
        );""",
        "images": """
        CREATE TABLE IF NOT EXISTS images (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            contract_id INTEGER,
            title TEXT,
            picture TEXT,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL
        );""",
        "incentives": """
        CREATE TABLE IF NOT EXISTS incentives (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_summary_key TEXT NOT NULL,
            year INTEGER NOT NULL,
            month INTEGER NOT NULL,
            value INTEGER NOT NULL,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL
        );""",
        "inquiries": """
        CREATE TABLE IF NOT EXISTS inquiries (
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
        );""",
        "knowledges": """
        CREATE TABLE IF NOT EXISTS knowledges (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            category TEXT,
            genre TEXT,
            file TEXT,
            file_2 TEXT,
            priority TEXT,
            body TEXT,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL,
            name_1 TEXT,
            name_2 TEXT,
            name_3 TEXT,
            url_1 TEXT,
            url_2 TEXT,
            url_3 TEXT
        );""",
        "lists": """
        CREATE TABLE IF NOT EXISTS lists (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            worker_id INTEGER,
            number TEXT,
            url TEXT,
            check_1 TEXT,
            check_2 TEXT,
            check_3 TEXT,
            check_4 TEXT,
            check_5 TEXT,
            check_6 TEXT,
            check_7 TEXT,
            check_8 TEXT,
            check_9 TEXT,
            check_10 TEXT,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL
        );""",
        "ng_customers": """
        CREATE TABLE IF NOT EXISTS ng_customers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER NOT NULL,
            inquiry_id INTEGER NOT NULL,
            sender_id INTEGER,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL,
            admin_id INTEGER
        );""",
        "pynotifies": """
        CREATE TABLE IF NOT EXISTS pynotifies (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            message TEXT,
            status TEXT,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL,
            sended_at DATETIME
        );""",
        "recruits": """
        CREATE TABLE IF NOT EXISTS recruits (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            age TEXT,
            email TEXT,
            experience TEXT,
            voice_data TEXT,
            year TEXT,
            commodity TEXT,
            hope TEXT,
            period TEXT,
            pc TEXT,
            start TEXT,
            encoded_voice_data TEXT,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL,
            tel TEXT,
            agree_1 TEXT,
            agree_2 TEXT,
            emergency_name TEXT,
            emergency_relationship TEXT,
            emergency_tel TEXT,
            identification TEXT,
            bank TEXT,
            branch TEXT,
            bank_number TEXT,
            bank_name TEXT,
            status TEXT,
            history TEXT
        );""",
        "scripts": """
        CREATE TABLE IF NOT EXISTS scripts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            company TEXT,
            name TEXT,
            tel TEXT,
            address TEXT,
            front_talk TEXT,
            first_talk TEXT,
            introduction TEXT,
            hearing_1 TEXT,
            hearing_2 TEXT,
            hearing_3 TEXT,
            hearing_4 TEXT,
            closing TEXT,
            requirement TEXT,
            price TEXT,
            experience TEXT,
            refund TEXT,
            usp TEXT,
            other_receive_1 TEXT,
            other_receive_2 TEXT,
            other_receive_3 TEXT,
            remarks TEXT,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL,
            contract_id INTEGER,
            title TEXT,
            requirement_title TEXT,
            price_title TEXT,
            experience_title TEXT,
            refund_title TEXT,
            usp_title TEXT,
            other_receive_1_title TEXT,
            other_receive_2_title TEXT,
            other_receive_3_title TEXT
        );""",
        "sender_assignments": """
        CREATE TABLE IF NOT EXISTS sender_assignments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            worker_id INTEGER NOT NULL,
            sender_id INTEGER NOT NULL,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL
        );""",
        "senders": """
        CREATE TABLE IF NOT EXISTS senders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_name TEXT DEFAULT '' NOT NULL,
            email TEXT DEFAULT '' NOT NULL,
            encrypted_password TEXT DEFAULT '' NOT NULL,
            reset_password_token TEXT,
            reset_password_sent_at DATETIME,
            remember_created_at DATETIME,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL,
            rate_limit INTEGER,
            default_inquiry_id INTEGER,
            url TEXT
        );""",
        "smartphone_logs": """
        CREATE TABLE IF NOT EXISTS smartphone_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            token TEXT NOT NULL,
            log_data TEXT NOT NULL,
            created_at DATETIME NOT NULL
        );""",
        "smartphones": """
        CREATE TABLE IF NOT EXISTS smartphones (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_name TEXT NOT NULL,
            token TEXT NOT NULL,
            delete_flag INTEGER DEFAULT 0 NOT NULL, -- boolean
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL
        );""",
        "staffs": """
        CREATE TABLE IF NOT EXISTS staffs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT DEFAULT '' NOT NULL,
            encrypted_password TEXT DEFAULT '' NOT NULL,
            reset_password_token TEXT,
            reset_password_sent_at DATETIME,
            remember_created_at DATETIME,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL
        );""",
        "tests": """
        CREATE TABLE IF NOT EXISTS tests (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            worker_id INTEGER,
            company TEXT,
            tel TEXT,
            address TEXT,
            title TEXT,
            business TEXT,
            genre TEXT,
            url TEXT,
            contact_url TEXT,
            url_2 TEXT,
            store TEXT,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL
        );""",
        "users": """
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_name TEXT DEFAULT '' NOT NULL,
            email TEXT DEFAULT '' NOT NULL,
            encrypted_password TEXT DEFAULT '' NOT NULL,
            select_option TEXT, -- Renamed from 'select'
            reset_password_token TEXT,
            reset_password_sent_at DATETIME,
            remember_created_at DATETIME,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL
        );""",
        "versions": """
        CREATE TABLE IF NOT EXISTS versions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            item_type TEXT NOT NULL,
            item_id INTEGER NOT NULL, -- limit: 8 in Rails, standard INTEGER in SQLite
            event TEXT NOT NULL,
            whodunnit TEXT,
            object_data TEXT, -- Renamed from 'object', limit: 1073741823 in Rails, TEXT in SQLite
            created_at DATETIME
        );""",
        "workers": """
        CREATE TABLE IF NOT EXISTS workers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_name TEXT DEFAULT '' NOT NULL,
            first_name TEXT,
            last_name TEXT,
            tel TEXT,
            email TEXT DEFAULT '' NOT NULL,
            encrypted_password TEXT DEFAULT '' NOT NULL,
            reset_password_token TEXT,
            reset_password_sent_at DATETIME,
            remember_created_at DATETIME,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL,
            select_option TEXT, -- Renamed from 'select'
            number_code INTEGER,
            deleted_customer_count INTEGER DEFAULT 0
        );""",
        "writers": """
        CREATE TABLE IF NOT EXISTS writers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            worker_id INTEGER,
            title_1 TEXT,
            url_1 TEXT,
            title_2 TEXT,
            url_2 TEXT,
            title_3 TEXT,
            url_3 TEXT,
            title_4 TEXT,
            url_4 TEXT,
            title_5 TEXT,
            url_5 TEXT,
            title_6 TEXT,
            url_6 TEXT,
            title_7 TEXT,
            url_7 TEXT,
            title_8 TEXT,
            url_8 TEXT,
            title_9 TEXT,
            url_9 TEXT,
            title_10 TEXT,
            url_10 TEXT,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL
        );""",
        # Table used by bootio.py but NOT in schema.rb
        # Definition based on commented-out INSERT in bootio.py Score.result
        "autoform_shot": """
        CREATE TABLE IF NOT EXISTS autoform_shot (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sender_id INTEGER,
            worker_id INTEGER,
            url TEXT,
            status TEXT,
            current_score INTEGER,
            session_code TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );"""
    }

    for table_name, sql_command in tables_sql.items():
        try:
            cursor.execute(sql_command)
            print(f"Table '{table_name}' created or already exists.")
        except sqlite3.Error as e:
            print(f"Error creating table {table_name}: {e}")


    conn.commit()
    print("\nDatabase schema setup complete based on schema.rb translation.")
    print(f"The 'autoform_shot' table was added based on bootio.py usage, as it was not in schema.rb.")
    print(f"The 'contracts' table definition might be incomplete due to the 'jsonb' error in schema.rb dump.")

except sqlite3.Error as e:
    print(f"SQLite error: {e}")
finally:
    if conn:
        conn.close()
        print("Database connection closed.")
