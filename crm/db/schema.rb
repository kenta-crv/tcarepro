# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20181011092839) do

  create_table "admins", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admins_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admins_on_reset_password_token", unique: true
  end

  create_table "comments", force: :cascade do |t|
    t.string "body"
    t.string "status", default: "0"
    t.string "integer", default: "0"
    t.string "picture"
    t.string "approval_data"
    t.string "ahead_data"
    t.string "term_data"
    t.string "regular_data"
    t.string "attendance_data"
    t.string "wage_data"
    t.string "labor_data"
    t.string "limited_progress"
    t.string "limited_start"
    t.string "limited_each_name"
    t.string "limited_each_start"
    t.string "limited_each_curriculum"
    t.string "limited_offjt_time"
    t.string "limited_ojt_time"
    t.string "limited_supply"
    t.string "limited_comment"
    t.string "carriaup_progress"
    t.string "carriaup_start"
    t.string "carriaup_each_name"
    t.string "carriaup_each_limited_start"
    t.string "carriaup_each_regular"
    t.string "carriaup_each_supply"
    t.string "carriaup_comment"
    t.string "system_progress"
    t.string "system_start"
    t.string "system_subsidyname"
    t.string "system_each_name"
    t.string "system_implementation"
    t.string "system_supply"
    t.string "system_comment"
    t.integer "company_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "status_cd", default: 0
    t.index ["company_id"], name: "index_comments_on_company_id"
  end

  create_table "companies", force: :cascade do |t|
    t.integer "user_id"
    t.integer "worker_id"
    t.string "company"
    t.string "first_name"
    t.string "last_name"
    t.string "first_kana"
    t.string "last_kana"
    t.string "tel"
    t.string "mobile"
    t.string "fax"
    t.string "e_mail"
    t.string "postnumber"
    t.string "prefecture"
    t.string "city"
    t.string "town"
    t.string "caption"
    t.string "labor_number"
    t.string "employment_number"
    t.string "trial_period"
    t.string "work_start"
    t.string "break_in"
    t.string "break_out"
    t.string "work_out"
    t.string "holiday"
    t.string "allowance"
    t.string "allowance_contents"
    t.string "closing_on"
    t.string "payment_on"
    t.string "method_payment"
    t.string "desuction"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_companies_on_user_id"
    t.index ["worker_id"], name: "index_companies_on_worker_id"
  end

  create_table "contacts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "details", force: :cascade do |t|
    t.string "name"
    t.string "product_type"
    t.string "method"
    t.integer "tel"
    t.string "post"
    t.string "address"
    t.string "point"
    t.integer "prefecture_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["prefecture_id"], name: "index_details_on_prefecture_id"
  end

  create_table "documents", force: :cascade do |t|
    t.string "upload_file_name"
    t.binary "upload_file"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "faqs", force: :cascade do |t|
    t.string "title"
    t.string "select"
    t.string "contents"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "invoices", force: :cascade do |t|
    t.string "status"
    t.string "deadline"
    t.string "payment"
    t.string "subject"
    t.string "item1"
    t.string "item2"
    t.string "item3"
    t.string "item4"
    t.string "item5"
    t.string "price1"
    t.string "price2"
    t.string "price3"
    t.string "price4"
    t.string "price5"
    t.string "quantity1"
    t.string "quantity2"
    t.string "quantity3"
    t.string "quantity4"
    t.string "quantity5"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "prefectures", force: :cascade do |t|
    t.string "labor"
    t.string "product_type"
    t.string "method"
    t.integer "tel"
    t.string "post"
    t.string "address"
    t.string "point"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "reads", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_reads_on_email", unique: true
    t.index ["reset_password_token"], name: "index_reads_on_reset_password_token", unique: true
  end

  create_table "todos", force: :cascade do |t|
    t.string "execution"
    t.string "title"
    t.string "select"
    t.string "deadline"
    t.string "state"
    t.string "name"
    t.string "contents"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "upload_data", force: :cascade do |t|
    t.string "name"
    t.string "file"
    t.integer "company_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_upload_data_on_company_id"
  end

  create_table "upload_files", force: :cascade do |t|
    t.string "name"
    t.string "file"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

end
