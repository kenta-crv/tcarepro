class EmailHistory < ApplicationRecord
    belongs_to :customer
    belongs_to :inquiry
end