class Estimate < ApplicationRecord
  belongs_to :customer
	def calc1
		price1.to_i * quantity1.to_i
	end
	def calc2
		price2.to_i * quantity2.to_i
	end
	def calc3
		price3.to_i * quantity3.to_i
	end
	def calc4
		price4.to_i * quantity4.to_i
	end
	def calc5
		price5.to_i * quantity5.to_i
	end

	def summary
		self.calc1 + self.calc2 + self.calc3 + self.calc4 + self.calc5
	end

	def tax
		(self.calc1 + self.calc2 + self.calc3 + self.calc4 + self.calc5) * 0.1
	end

	def total
		summary + tax
	end

  def company
    customer.company
  end
end
