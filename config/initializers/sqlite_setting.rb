# SQLiteのロックタイムアウトを設定（同時リクエスト時のロック待ち時間を延長）
if ActiveRecord::Base.connection.adapter_name == 'SQLite'
  ActiveRecord::Base.connection.execute('PRAGMA busy_timeout = 30000') # 30秒
  ActiveRecord::Base.connection.execute('PRAGMA journal_mode = WAL') # Write-Ahead Logging（同時読み取りを改善）
end