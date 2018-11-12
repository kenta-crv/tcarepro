# == Schema Information
#
# Table name: companies
#
#  id                 :integer          not null, primary key
#  user_id            :integer
#  worker_id          :integer
#  company            :string
#  first_name         :string
#  last_name          :string
#  first_kana         :string
#  last_kana          :string
#  tel                :string
#  mobile             :string
#  fax                :string
#  e_mail             :string
#  postnumber         :string
#  prefecture         :string
#  city               :string
#  town               :string
#  caption            :string
#  labor_number       :string
#  employment_number  :string
#  trial_period       :string
#  work_start         :string
#  break_in           :string
#  break_out          :string
#  work_out           :string
#  holiday            :string
#  allowance          :string
#  allowance_contents :string
#  closing_on         :string
#  payment_on         :string
#  method_payment     :string
#  desuction          :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#

class Company < ApplicationRecord
    has_many :comments, dependent: :destroy
    has_many :upload_datum
    has_many :invoices
    belongs_to :user, optional: true


  def self.import(file)
    CSV.foreach(file.path, headers: true) do |row|
      # IDが見つかれば、レコードを呼び出し、見つかれなければ、新しく作成
      company = find_by(id: row["id"]) || new
      # CSVからデータを取得し、設定する
      company.attributes = row.to_hash.slice(*updatable_attributes)
      # 保存する
      company.save!
    end
  end

  def self.updatable_attributes
      [
      "company",  #会社名
      "first_name", #苗字
      "last_name", #名前
      "first_kana", #ミョウジ
      "last_kana", #ナマエ
      "tel", #電話番号
      "mobile", #携帯番号
      "fax", #FAX番号
      "e_mail", #メールアドレス
      "postnumber", #郵便番号
      "prefecture", #都道府県
      "city", #市町村
      "town", #市町村以降
      "caption", #資本金
      "labor_number", #労働保険番号
#就業規則
       "employment_number", #雇用保険番号
       "trial_period", #試用期間
       "work_start", #勤務開始
       "break_in", #休憩開始
       "break_out", #休憩終了
       "work_out", #勤務終了
       "holiday", #休日
       "allowance", #手当
       "allowance_contents", #手当詳細
       "closing_on", #締め日
       "payment_on", #支払い日
       "method_payment", #支払方法
       "desuction" #控除
  		]
  end


  def self.search(search) #self.でクラスメソッドとしている
    if search # Controllerから渡されたパラメータが!= nilの場合は、titleカラムを部分一致検索
      Company.where(['company LIKE ?', "%#{company}%"])
    else
      Company.all #全て表示。
    end
  end

  def address
    self.prefecture + self.city
  end

end
