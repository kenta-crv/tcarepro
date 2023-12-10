class AddWorkerToCrowdworks < ActiveRecord::Migration[5.1]
  def change
    add_reference :crowdworks, :worker, foreign_key: true
  end
end
