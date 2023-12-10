class List < ApplicationRecord
    belongs_to :worker
    validates :number, presence: true
    validates :url, presence: true
    validate :check_1_must_be_checked
    validate :check_2_must_be_checked
    validate :check_3_must_be_checked
    validate :check_4_must_be_checked
    validate :check_5_must_be_checked
    validate :check_6_must_be_checked
    validate :check_7_must_be_checked
    validate :check_8_must_be_checked
    validate :check_9_must_be_checked
    validate :check_10_must_be_checked

    private
    def check_1_must_be_checked
        errors.add(:check_1, 'must be checked') unless check_1
    end
    def check_2_must_be_checked
        errors.add(:check_2, 'must be checked') unless check_2
    end
    def check_3_must_be_checked
        errors.add(:check_3, 'must be checked') unless check_3
    end
    def check_4_must_be_checked
        errors.add(:check_4, 'must be checked') unless check_4
    end
    def check_5_must_be_checked
        errors.add(:check_5, 'must be checked') unless check_5
    end
    def check_6_must_be_checked
        errors.add(:check_6, 'must be checked') unless check_6
    end
    def check_7_must_be_checked
        errors.add(:check_7, 'must be checked') unless check_7
    end
    def check_8_must_be_checked
        errors.add(:check_8, 'must be checked') unless check_8
    end
    def check_9_must_be_checked
        errors.add(:check_9, 'must be checked') unless check_9
    end
    def check_10_must_be_checked
        errors.add(:check_10, 'must be checked') unless check_10
    end
end
