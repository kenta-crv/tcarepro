# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)


# Customer.create(:company => "株式会社CroldValieat", :store => "クールドバリエイト", :first_name => "奥山", :last_name => "健太", :first_kana => "オクヤマ", :last_kana => "ケンタ", :tel => "03-6712-7837", :tel2 => "080-2034-0000", :fax => "03-6712-7838", :mobile => "00-0000-0000", :industry => "飲食店", :mail => "adp@crold-valieat.jp", :url => "http://www.crold-valieat.jp/", :people => "1名",:postnumber => "150-0032" ,:address => "東京都渋谷区鶯谷町19-19第三叶ビル303号室",:caption => "1000万円",:remarks => "なし",:status => "CTI")
# Customer.create(:company => "株式会社aui", :store => "クールドバリエイト", :first_name => "奥山", :last_name => "健太", :first_kana => "オクヤマ", :last_kana => "ケンタ", :tel => "03-6712-7837", :tel2 => "080-2034-0000", :fax => "03-6712-7838", :mobile => "00-0000-0000", :industry => "飲食店", :mail => "adp@crold-valieat.jp", :url => "http://www.crold-valieat.jp/", :people => "1名",:postnumber => "150-0032" ,:address => "東京都渋谷区鶯谷町19-19第三叶ビル303号室",:caption => "1000万円",:remarks => "なし",:status => "CTI")
# Customer.create(:company => "株式会社いいい", :store => "クールドバリエイト", :first_name => "奥山", :last_name => "健太", :first_kana => "オクヤマ", :last_kana => "ケンタ", :tel => "03-6712-7837", :tel2 => "080-2034-0000", :fax => "03-6712-7838", :mobile => "00-0000-0000", :industry => "飲食店", :mail => "adp@crold-valieat.jp", :url => "http://www.crold-valieat.jp/", :people => "1名",:postnumber => "150-0032" ,:address => "東京都渋谷区鶯谷町19-19第三叶ビル303号室",:caption => "1000万円",:remarks => "なし",:status => "CTI")
# Customer.create(:company => "株式会社あああ", :store => "クールドバリエイト", :first_name => "奥山", :last_name => "健太", :first_kana => "オクヤマ", :last_kana => "ケンタ", :tel => "03-6712-7837", :tel2 => "080-2034-0000", :fax => "03-6712-7838", :mobile => "00-0000-0000", :industry => "飲食店", :mail => "adp@crold-valieat.jp", :url => "http://www.crold-valieat.jp/", :people => "1名",:postnumber => "150-0032" ,:address => "東京都渋谷区鶯谷町19-19第三叶ビル303号室",:caption => "1000万円",:remarks => "なし",:status => "CTI")
# Customer.create(:company => "株式会社っっw", :store => "クールドバリエイト", :first_name => "奥山", :last_name => "健太", :first_kana => "オクヤマ", :last_kana => "ケンタ", :tel => "03-6712-7837", :tel2 => "080-2034-0000", :fax => "03-6712-7838", :mobile => "00-0000-0000", :industry => "飲食店", :mail => "adp@crold-valieat.jp", :url => "http://www.crold-valieat.jp/", :people => "1名",:postnumber => "150-0032" ,:address => "東京都渋谷区鶯谷町19-19第三叶ビル303号室",:caption => "1000万円",:remarks => "なし",:status => "CTI")

# user = User.new(
# user_name: "admin",
# email: "admin@admin.com",
# password: "adminadmin"
# )

# if user.save
# puts "User created: #{user.email}"
# else
# puts "Error creating user: #{user.errors.full_messages.join(", ")}"
# end

# worker = Worker.new(
# user_name: "admin",
# email: "adminWorker@admin.com",
# password: "adminadmin"
# )

# if worker.save
# puts "User created: #{worker.email}"
# else
# puts "Error creating user: #{worker.errors.full_messages.join(", ")}"
# end

# admin = Admin.new(
# user_name: "admin1",
# email: "admin1@admin.com",
# password: "adminadmin"
# )

# if admin.save
# puts "User created: #{admin.email}"
# else
# puts "Error creating user: #{admin.errors.full_messages.join(", ")}"
# end

Smartphone = Smartphone.new(
device_name: "test",
token: "de1bl6lo-nw:APA91bH5PW1lsRLq7sGA8WCP388ZovcqHW8FojC-K_aYvjfvLkEOTaHbKDNaKxBy3yje1KRJMRea8ET3u7nUwYlgsKeAVF3KuYFB2X127IIcpaBP4NebqUESp-JNUb0AjLlPCUOsIji2"
)

if Smartphone.save
puts "User created: #{Smartphone.device_name}"
else
puts "Error creating user: #{Smartphone.errors.full_messages.join(", ")}"
end
