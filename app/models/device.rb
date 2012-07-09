class Device < ActiveRecord::Base
  attr_accessible :environment, :ip_addr, :mac_addr, :make, :model, :os, :os_version, :owner_id, :phone_num, :possesser_id, :project, :serial_num, :service_provider, :device_type, :status
  validates_presence_of :environment, :ip_addr, :mac_addr, :make, :model, :os, :os_version,  :phone_num, :project, :serial_num, :service_provider, :device_type
  belongs_to :user

  def self.search(query)
    q = "%#{query}%"
    self.where(["make LIKE ? OR model LIKE ? OR os LIKE ? OR os_version LIKE ? OR project LIKE ?", q, q, q, q, q])
  end
end
