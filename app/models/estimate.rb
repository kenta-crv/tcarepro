class Estimate < ApplicationRecord
  belongs_to :customer
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
		(self.calc1 + self.calc2 + self.calc3 + self.calc4 + self.calc5) * 1.00
	end

	def total
		(self.calc1 + self.calc2 + self.calc3 + self.calc4 + self.calc5) * 1.00
	end
end
