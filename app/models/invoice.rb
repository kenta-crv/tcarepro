# == Schema Information
#
# Table name: invoices
#
#  id         :integer          not null, primary key
#  status     :string
#  deadline   :string
#  payment    :string
#  subject    :string
#  item1      :string
#  item2      :string
#  item3      :string
#  item4      :string
#  item5      :string
#  price1     :integer
#  price2     :integer
#  price3     :integer
#  price4     :integer
#  price5     :integer
#  quantity1  :integer
#  quantity2  :integer
#  quantity3  :integer
#  quantity4  :integer
#  quantity5  :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  company_id :integer
#

class Invoice < ApplicationRecord
	belongs_to :crm

	def calc1
		price1 * quantity1
	end
	def calc2
		price2 * quantity2
	end
	def calc3
		price3 * quantity3
	end
	def calc4
		price4 * quantity4
	end
	def calc5
		price5 * quantity5
	end

	def summary
		self.calc1 + self.calc2 + self.calc3 + self.calc4 + self.calc5
	end

	def tax
		(self.calc1 + self.calc2 + self.calc3 + self.calc4 + self.calc5) * 0.08
	end

	def total
		(self.calc1 + self.calc2 + self.calc3 + self.calc4 + self.calc5) * 1.8
	end
end
