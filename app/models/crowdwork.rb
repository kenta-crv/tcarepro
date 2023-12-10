class Crowdwork < ApplicationRecord
    has_many :assignments
    has_many :workers, through: :assignments
    def area=(values)
        values = values.reject(&:blank?)
        write_attribute(:area, values)
    end
end
