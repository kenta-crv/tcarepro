class Recruit < ApplicationRecord
    mount_uploader :voice_data, VoiceUploader
    mount_uploader :identification, UploadFileUploader
    validates :name, presence: true
    validates :age, presence: true
    validates :email, presence: true
    validates :experience, presence: true
    #validates :voice_data, presence: true
    validates :tel, presence: true
    validates :agree_1, presence: true, on: :update
    validates :agree_2, presence: true, on: :update
    validates :emergency_name, presence: true, on: :update
    validates :emergency_relationship, presence: true, on: :update
    validates :emergency_tel, presence: true, on: :update
    #:identification,
    validates :bank, presence: true, on: :update
    validates :branch, presence: true, on: :update
    validates :bank_number, presence: true, on: :update
    validates :bank_name, presence: true, on: :update

    def check_agree_1
        errors.add(:agree_1, '動画を閲覧してください。') unless agree_1
    end

    def check_agree_2
        errors.add(:agree_2, '約款をお読みください。') unless agree_2
    end
end
