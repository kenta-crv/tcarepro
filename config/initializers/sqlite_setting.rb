if ActiveRecord::Base.connection.adapter_name == 'SQLite'
  ActiveRecord::Base.connection.execute('PRAGMA busy_timeout = 300000') # 5000ミリ秒 = 5秒
end