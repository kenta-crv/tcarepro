class Crowdwork < ApplicationRecord
    has_many :assignments, dependent: :destroy
    has_many :workers, through: :assignments
  
    def area=(values)
      values = values.reject(&:blank?)
      write_attribute(:area, values.join(','))  # カンマ区切りで保存
    end
  
    def area
      read_attribute(:area).to_s.split(',')  # 配列として読み出す
    end
  end
  