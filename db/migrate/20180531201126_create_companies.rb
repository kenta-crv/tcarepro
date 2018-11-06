class CreateCompanies < ActiveRecord::Migration[5.1]
  def change
    create_table :companies do |t|
        t.belongs_to :user, index: true # 追加：usersテーブルと紐付け
        t.belongs_to :worker, index: true     # 追加：workersテーブルと紐付け

#会社情報
      t.string :company #会社名
      t.string :first_name #苗字
      t.string :last_name #名前
      t.string :first_kana #ミョウジ
      t.string :last_kana #ナマエ
      t.string :tel #電話番号
      t.string :mobile #携帯番号
      t.string :fax #FAX番号
      t.string :e_mail #メールアドレス
      t.string :postnumber #郵便番号
      t.string :prefecture #都道府県
      t.string :city #市町村
      t.string :town #市町村以降
      t.string :caption #資本金
      t.string :labor_number #労働保険番号
      t.string :employment_number #雇用保険番禺


#就業規則      
        t.string :trial_period #試用期間
        t.string :work_start #勤務開始
        t.string :break_in #休憩開始
        t.string :break_out #休憩終了
        t.string :work_out #勤務終了
        t.string :holiday #休日
        t.string :allowance #手当
        t.string :allowance_contents #手当詳細
        t.string :closing_on #締め日
        t.string :payment_on #支払い日
        t.string :method_payment #支払方法
        t.string :desuction #控除



      t.timestamps
    end
  end
end
