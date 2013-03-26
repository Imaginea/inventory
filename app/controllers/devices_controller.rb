class DevicesController < ApplicationController
  before_filter :login_required
  before_filter :admin_required, only: [:new, :create, :edit, :update, :destroy, :unavailable]

  # GET /devices
  def index
    @devices = Device.list_for(current_user)
    respond_to do |format|
      format.html # index.html.erb 
    end
  end

  # GET /admin/devices/unavailable
  def unavailable
    @devices = Device.unavailable

    respond_to do |format|
      format.html
    end
  end

  # Exporting devices list to a Excel file
  def export
    @devices = Device.all
    respond_to do |format|
      format.xls do
        workbook = Spreadsheet::Workbook.new
        worksheet = workbook.create_worksheet(name: 'Devices List')
        worksheet.row(0).concat [
          'Manufacturer',
          'Product',
          'Label',
          'Serial Number',
          'OS',
          'OS Version',
          'Environment',
          'Project',
          'Status',
          'Provider',
          'IMEI',
          'Phone',
          'MAC Address',
          'IP Address',
          'Owner',
          'Possessor',
          'Property Of'
        ] 
        @devices.each_with_index { |device, i|
          worksheet.row(i+1).push(
            device.manufacturer,
            device.model,
            device.label,
            device.serial_num,
            device.os,
            device.os_version,
            device.environment,
            device.project,
            device.state,
            device.service_provider,
            device.imei,
            device.phone_num,
            device.mac_addr,
            device.ip_addr,
            device.owner,
            device.possessor,
            device.property_of
          )
        }
        header_format = Spreadsheet::Format.new(color: :green, weight: :bold)
        worksheet.row(0).default_format = header_format
        #output to blob object
        blob = StringIO.new('')
        workbook.write(blob)
        #respond with blob object as a file
        send_data(blob.string, :type => "application/ms-excel", :filename => "Mobile Devices List.xls")
      end
    end
  end
  
  #Import Devices Data from Excel
  def import
    if params[:device_import_file]
      imp_filename = params[:device_import_file].tempfile.path
      Spreadsheet.open(imp_filename) do |spreadsheet|
        ws = spreadsheet.worksheets.first

        # No worksheets
        if ws.nil?
          flash[:error] = 'No worksheets in the Excel sheet provided'
        else
          ws.each do |row|
            d = Device.new
            #break if row[0].nil?
            d.serial_num       = row[1]
            d.manufacturer     = row[2]
            d.model            = row[3]
            d.os               = row[4]
            d.os_version       = row[5]
            d.environment      = row[6]
            d.project          = row[7]
            d.service_provider = row[8]
            d.phone_num        = ( row[9].blank? ? nil : row[9].to_i )
            d.mac_addr         = row[10]
            d.ip_addr          = row[11]
            d.possessor        = row[12]
            d.owner            = row[13]
            d.property_of      = row[14]
            d.state            = :available
            d.save
            Event.record_event(d.id, "Device has been imported by #{current_user}")
          end
          flash[:notice] = 'Import successful, new records added to the database.'
        end
      end
    else
      flash[:error] = 'No file uploaded'
    end

    respond_to do |format|
      format.html { redirect_to devices_path }
    end
  end

  # GET /devices/search
  # GET /devices/search.json
  def search
    @devices = Device.search(params[:q])

    respond_to do |format|
      format.html # search.html.erb
      format.json { render json: @devices }
    end
  end

  # GET /devices/1
  # GET /devices/1.json
  def show
    @device = Device.find(params[:id])
    @events = @device.events.limit(10)
    @accessory = Accessory.new

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @device }
    end
  end

  # GET /devices/new
  # GET /devices/new.json
  def new
    @device = Device.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @device }
    end
  end

  # GET /devices/1/edit
  def edit
    @device = Device.find(params[:id])

    respond_to do |format|
      format.html # edit.html.erb
      format.json { render json: @device }
    end
  end

  # POST /devices
  # POST /devices.json
  def create
    params[:device].merge!({:created_by => current_user})
    @device = Device.new(params[:device])

    respond_to do |format|
      if @device.save
        Event.record_event(@device.id, "Device has been created by #{current_user}")
        format.html { redirect_to @device, notice: 'Device was successfully created.' }
        format.json { render json: @device, status: :created, location: @device }
      else
        flash.now[:error] = "Some errors prevented the device from saving"
        format.html { render action: "new" }
        format.json { render json: @device.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /devices/1
  def update
    @device = Device.find(params[:id])

    params[:device].merge!({:updated_by => current_user})
    respond_to do |format|
      if @device.update_attribs(params[:device], params[:comment])
        format.html { redirect_to @device, notice: 'Device was successfully updated.' }
      else
        flash.now[:error] = "Some errors prevented the data from updating"
        format.html { render action: "edit" }
      end
    end
  end

  # PUT /devices/:id/ask.js
  def ask
    @device = Device.find(params[:id])

    ActiveRecord::Base.transaction do
      @device.ask!
      req = @device.requests.build(params[:request]) do |req|
        req.owner     = @device.owner
        req.requestor = current_user
      end
      req.save!
      @asked = true
    end

    if @asked
      flash.now[:notice] = 'Sent a request successfully.'
    else
      flash.now[:error] = 'Unable to add a request.'
    end

    respond_to do |format|
      format.js
    end
  end

  # PUT /devices/:id/receive
  def receive
    @device = Device.find(params[:id])

    respond_to do |format|
      if @device.receive
        Event.record_event(@device.id, "Device has been returned by #{current_user}")
        format.html { redirect_to @device, notice: 'Returned the device successfully. It\'s now available to other users' }
      else
        format.html { redirect_to @device, notice: 'Unable to receive the device' }
      end
    end
  end

  def make_unavailable
    @device = Device.find(params[:id])

    respond_to do |format|
      if @device.make_unavailable
        Event.record_event(@device.id, "Device has been made unavailable to other users by #{current_user}")
        format.html { redirect_to edit_device_path, notice: 'The device is now marked unavailable to other users.' }
      else
        format.html { redirect_to edit_device_path, error: 'Unable to mark the device as unavailable.' }
      end
    end
  end

  def make_available
    @device = Device.find(params[:id])

    respond_to do |format|
      if @device.make_available
        Event.record_event(@device.id, "Device has been made available to other users by #{current_user}")
        format.html { redirect_to edit_device_path, notice: 'The device is now marked available to other users.' }
      else
        format.html { redirect_to edit_device_path, error: 'Unable to mark the device as available.' }
      end
    end
  end

  # DELETE /devices/1
  # DELETE /devices/1.json
  def destroy
    @device = Device.find(params[:id])
    @device.destroy

    respond_to do |format|
      format.html { redirect_to devices_url }
      format.json { head :no_content }
    end
  end
end
