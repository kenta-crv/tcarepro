# == Schema Information
#
# Table name: comments
#
#  id                          :integer          not null, primary key
#  body                        :string
#  status                      :string           default("0")
#  integer                     :string           default("0")
#  picture                     :string
#  approval_data               :string
#  ahead_data                  :string
#  term_data                   :string
#  regular_data                :string
#  attendance_data             :string
#  wage_data                   :string
#  labor_data                  :string
#  limited_progress            :string
#  limited_start               :string
#  limited_each_name           :string
#  limited_each_start          :string
#  limited_each_curriculum     :string
#  limited_offjt_time          :string
#  limited_ojt_time            :string
#  limited_supply              :string
#  limited_comment             :string
#  carriaup_progress           :string
#  carriaup_start              :string
#  carriaup_each_name          :string
#  carriaup_each_limited_start :string
#  carriaup_each_regular       :string
#  carriaup_each_supply        :string
#  carriaup_comment            :string
#  system_progress             :string
#  system_start                :string
#  system_subsidyname          :string
#  system_each_name            :string
#  system_implementation       :string
#  system_supply               :string
#  system_comment              :string
#  company_id                  :integer
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  status_cd                   :integer          default(0)
#

class Comment < ApplicationRecord
  belongs_to :company
  as_enum :status, %i{normal limited carriaup system picture}
  SYSTEM_NAMES = ["（企）職業能力評価制度","（形）職業能力評価制度","（形）セルフキャリアドッグ制度","（形）技能検定合格報奨金制度","（形）教育訓練休暇等制度","（人）セルフキャリアドッグ制度","（人）技能検定合格報奨金制度","（人）教育訓練休暇等制度","東京都キャリアアップ助成金","人事評価改善等助成金","職場定着支援等助成金"]
  mount_uploader :picture, UploadFileUploader
end
