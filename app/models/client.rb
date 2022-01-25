class Client < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  has_many :customers
  has_many :calls

  validates :industry, presence: true

  validate :specify_the_industry_that_exists

  def specify_the_industry_that_exists
    return if industry.blank?

    unless Customer.where(industry: industry).exists?
      errors.add(:industry, "は存在しません")
    end
  end
end
