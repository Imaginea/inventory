class AddLocationAndTeamColumnsToDevice < ActiveRecord::Migration
  def change
    add_column :devices, :location, :string
    add_column :devices, :team, :string
  end
end
