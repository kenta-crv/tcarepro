require 'securerandom'

class SaveRecord
    def find
        Contact_tracking.all.each do |customers|
            begin
                print("Updated")
                cus = Customer.where(id: customers.id)
                cus.update(customers_code: SecureRandom.alphanumeric(15))
            rescue => exception
                print("error")
            end
        end
    end
end

t = SaveRecord.new
t.saver()
print("END")
