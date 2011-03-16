require 'fileutils'

java_import "android.database.sqlite.SQLiteDatabase"
java_import "android.os.Environment"
java_import "android.os.StatFs"
java_import "android.content.Context"
java_import "org.apache.http.client.methods.HttpGet"
java_import "org.apache.http.impl.client.BasicResponseHandler"
java_import "org.apache.http.impl.client.DefaultHttpClient"
java_import "java.security.MessageDigest"
java_import "java.io.FileInputStream"

ruboto_import_widgets :TableLayout, :TableRow, :TextView, :LinearLayout, :Button, :ScrollView

class Numeric
  def to_byte_string(dp=2)
    return "None" if self == 0

    rv = self.to_f
    count = 0

    while rv > 1024
      rv /= 1024
      count += 1
    end

    ("%.#{dp}f" % rv).to_s.gsub(/(\d)(?=\d{3}+(?:\.|$))(\d{3}\..*)?/,'\1,\2') + "bkMG"[count..count]
  end
end

class DB
  @internal_db_file = $activity.getDatabasePath("android_api.db").to_s
  @internal_db_dir = @internal_db_file.split("/")[0..-2].join("/")
  @external_db_dir = $external_db_dir # $activity.getExternalCacheDir.to_s
  @external_db_file = @external_db_dir + "/android_api.db"

  def self.open(force_close=false)
    close if $db and force_close
    unless $db
      $db = SQLiteDatabase.openDatabase(file, nil, SQLiteDatabase::OPEN_READONLY) if exists? and not $db
      @api_levels = nil
    end
    $db
  end

  def self.close
    $db.close if $db
    $db = nil
    @api_levels = nil
    SQLiteModel.clear
  end

  def self.api_levels
    if @api_levels.nil?
      @api_levels = []
      c = $db.rawQuery("select * from apiid order by _id", nil)
      c.moveToFirst
      while not c.isAfterLast
        hash = {:id => c.getInt(0), :name => (c.isNull(1) ? nil : c.getString(1)), :version => c.getString(2)}
        hash[:full_name] = "#{hash[:version]} (android-#{hash[:id]}#{c.isNull(1) ? '' : (', ' + hash[:name])})"
        @api_levels << hash
        c.moveToNext
      end
      c.close
    end
    @api_levels
  end

  def self.max_api_level
    api_levels.length
  end

  def self.api_level(num)
    api_levels[num-1]
  end

  def self.get_remote_file(a_url)
    # Problems on handsets with little memory
    #    DefaultHttpClient.new.execute(HttpGet.new(a_url), BasicResponseHandler.new)

     connection = URL.new(a_url).openConnection
     buff_size = 0x2000
     buff = Java::byte[buff_size].new
     rv = ""
     i = BufferedInputStream.new(connection.getInputStream, buff_size)

     x = i.read(buff, 0, buff_size)
     while x != -1
       rv += String.from_java_bytes(x == buff_size ? buff : buff[0..(x-1)])
       x = i.read(buff, 0, buff_size)
     end

     connection.disconnect
     rv
  end

  def self.check_for_updates
    $activity.toast("Checking for updates...")
    $activity.do_in_thread(
      :when_done   => (
        Proc.new do 
          if changed?
            what = [("the application scripts" if code_changed?), ("the API database" if db_changed?)].compact.join(" and ")
            $activity.alert_dialog(
              :title => "Updates Available",
              :message => "There are updates available for #{what}. Would you like to update now?",
              :positive_button => ["Yes", Proc.new{|d, w| d.dismiss; DB.update}],
              :negative_button => ["No", Proc.new{|d, w| d.dismiss}]
            )
          else
            $activity.toast("You're up to date.")
          end
        end
      ),
      :when_failed => Proc.new{$activity.toast("Update check failed! Try again later.")}
    ) do
      get_remote_info
    end
  end

  def self.get_remote_info
    b = $desktop.getPackageManager.getPackageInfo($desktop.getPackageName, 0).versionCode
    remote_info = get_remote_file("#{$remote_site}/android_api_#{b}-#{$local_code_level}.txt").split("\n")
    @remote_md5 = remote_info[0]
    @remote_size = remote_info[1].to_i
    @remote_code_level = remote_info[2].to_i
    @remote_upgrade_message = remote_info[3]
    update_info
  end

  def self.update(new_db_dir=DB.dir, new_db_file=DB.file)
    upgrade_code_in_thread if code_changed? and !db_changed?
    update_db(new_db_dir, new_db_file) if db_changed?
  end

  def self.update_db(new_db_dir=DB.dir, new_db_file=DB.file)
    if ((DB.internal_dir == new_db_dir) & internal_space_sufficient?) | ((DB.external_dir == new_db_dir) & external_space_sufficient?)
      DB.close
      FileUtils.rm new_db_file if File.exists? new_db_file
      $activity.download_in_thread(:from => DB.url, :to => new_db_dir, :size => DB.remote_size,
        :when_starting => Proc.new{download_new_code if code_changed?},
        :when_ending   => Proc.new{($local_code_level = remote_code_level; $main.load_code(:load)) if code_changed?},
        :when_done     => Proc.new{DB.update_info},
        :when_failed   => Proc.new{DB.update_info; $activity.toast("Update failed!\nTry again later.")}
      )
    else
      $activity.alert_dialog(
        :title => "Insufficient Space",
        :message => "You do not have enough #{DB.location} space. You will need #{DB.upgrade_space_required.to_byte_string}. You currently have #{DB.upgrade_space_available.to_byte_string}.",
        :positive_button => ["Ok", Proc.new{|d, w| d.dismiss; DB.manage}]
      )
    end
  end

  def self.upgrade_code_in_thread
    $activity.progress_dialog(:message => "Updating code...").do_in_thread(
      Proc.new{$local_code_level = remote_code_level; $main.load_code(:load); $activity.toast("Code updated to version #{$local_code_level}.")},
      Proc.new{$activity.toast("Update failed!\nTry again later.")}
    ) do
      download_new_code
    end
  end

  def self.download_new_code
    all_code = {}
    $aab_files.each{|i| all_code[i] = get_remote_file("#{$remote_site}/#{@remote_code_level}/#{i}.rb")}
    all_code.each{|k, v| File.open("#{$local_code}/#{k}.rb", "w"){|f| f << v}}
  end

  def self.digest(path=@db_file)
    file = BufferedInputStream.new(FileInputStream.new(@db_file))
    digester = MessageDigest.getInstance("MD5")
    digester.reset
    bytes = Java::byte[8192].new
    while (byteCount = file.read(bytes)) > 0
      digester.update(bytes, 0, byteCount)
    end
    file.close
    rv = Java::java.math.BigInteger.new(1, digester.digest).toString(16)
    ("0" * (32 - rv.length)) + rv
  end

  def self.update_info
    @internal_db_exists = File.exists?(@internal_db_file)
    @external_db_exists = File.exists?(@external_db_file)
    @db_exists = @internal_db_exists || @external_db_exists
    @db_location = @db_exists ? (@internal_db_exists ? "internal" : "external") : "none"
    @db_dir = @internal_db_exists ? @internal_db_dir : @external_db_dir
    @db_file = @internal_db_exists ? @internal_db_file : @external_db_file
    @local_md5 = @db_exists ? digest : -1

    stat = StatFs.new(Environment.getDataDirectory.to_s)
    @internal_space_available = (stat.getBlockSize * stat.getAvailableBlocks)

    stat = StatFs.new(Environment.getExternalStorageDirectory.to_s)
    @external_space_available = (stat.getBlockSize * stat.getAvailableBlocks)
    @current_size = @db_exists ? File.stat(@db_file).size : 0

    @upgrade_space_available = @internal_db_exists ? @internal_space_available : @external_space_available

    if @remote_size
      @upgrade_space_required = @remote_size > @current_size ? (@remote_size - @current_size) : 0
      @internal_space_sufficient = (@internal_db_exists ? @upgrade_space_required : @remote_size) < @internal_space_available
      @external_space_sufficient = (@external_db_exists ? @upgrade_space_required : @remote_size) < @external_space_available
      @upgrade_space_sufficient = (@internal_space_sufficient & @internal_db_exists) | (@external_space_sufficient & @external_db_exists)
    end
  end

  update_info

  def self.url; "#{$remote_site}/#{@remote_code_level}/android_api.db.gz"; end

  def self.changed?;                   code_changed? or db_changed?;            end
  def self.code_changed?;              @remote_code_level != $local_code_level; end
  def self.db_changed?;                @remote_md5 != @local_md5;               end

  def self.exists?;                    @db_exists;                              end
  def self.location;                   @db_location;                            end
  def self.internal_exists?;           @internal_db_exists;                     end
  def self.external_exists?;           @external_db_exists;                     end
  def self.current_size;               @current_size;                           end
  def self.dir;                        @db_dir;                                 end
  def self.internal_dir;               @internal_db_dir;                        end
  def self.external_dir;               @external_db_dir;                        end
  def self.internal_file;              @internal_db_file;                       end
  def self.external_file;              @external_db_file;                       end
  def self.file;                       @db_file;                                end
  def self.local_md5;                  @local_md5;                              end
  def self.remote_code_level;          @remote_code_level;                      end
  def self.remote_md5;                 @remote_md5;                             end
  def self.remote_size;                @remote_size;                            end

  def self.internal_space_available;   @internal_space_available;               end
  def self.external_space_available;   @external_space_available;               end
  def self.upgrade_space_available;    @upgrade_space_available;                end
  def self.internal_space_sufficient?; @internal_space_sufficient;              end
  def self.external_space_sufficient?; @external_space_sufficient;              end
  def self.upgrade_space_required;     @upgrade_space_required;                 end
  def self.upgrade_space_sufficient?;  @upgrade_space_sufficient;               end

  def self.manage
    $activity.start_ruboto_activity "$db_download" do
      setTitle "Management Interface"

      def self.update_db_buttons
        DB.update_info

        @t1.setText $local_code_level.to_s
        @t2.setText DB.remote_size ? DB.remote_code_level.to_s : 'Unknown'
        @t3.setText DB.exists? ? DB.current_size.to_byte_string : 'None'
        @t4.setText DB.remote_size ? DB.remote_size.to_byte_string : 'Unknown'
        @t5.setText DB.internal_space_available.to_byte_string
        @t6.setText DB.external_space_available.to_byte_string

        @b0.setEnabled(DB.exists? | DB.remote_size.nil?)
        @b1.setEnabled(!DB.exists? & !DB.remote_size.nil? & DB.internal_space_sufficient?)
        @b2.setEnabled(!DB.exists? & !DB.remote_size.nil? & DB.external_space_sufficient?)
        @b3.setEnabled DB.external_exists? & DB.internal_space_sufficient? 
        @b4.setEnabled DB.internal_exists? & DB.external_space_sufficient?
        @b5.setEnabled DB.exists?
      end

      setup_content do
       scroll_view do
        linear_layout(:orientation => LinearLayout::VERTICAL) do
          table_layout do
            table_row do
              text_view :text => "Current software version: "
              @t1 = text_view
            end
            table_row do
              text_view :text => "Remote software version: "
              @t2 = text_view
            end
            table_row do
              text_view :text => "Current database size: "
              @t3 = text_view
            end
            table_row do
              text_view :text => "Remote database size: "
              @t4 = text_view
            end
            table_row do
              text_view :text => "Available internal storage: "
              @t5 = text_view
            end
            table_row do
              text_view :text => "Available external storage: "
              @t6 = text_view
            end
          end

          @b0 = button(:text => "Check for updates")
          @b1 = button(:text => "Download to internal storage")
          @b2 = button(:text => "Download to external storage")
          @b3 = button(:text => "Move to internal storage")
          @b4 = button(:text => "Move to external storage")
          @b5 = button(:text => "Remove downloaded database")
        end
       end
      end

      handle_window_focus_changed do |has_focus|
        update_db_buttons if has_focus
      end

      handle_click do |view|
        if view == @b0
          DB.check_for_updates
        elsif view == @b1 or view == @b2
          DB.update(view == @b1 ? DB.internal_dir : DB.external_dir, view == @b1 ? DB.internal_file : DB.external_file)
        elsif view == @b3 or view == @b4
          d, f = (view == @b3 ? DB.internal_dir : DB.external_dir), (view == @b3 ? DB.external_file : DB.internal_file)
          DB.close
          progress_dialog(:message => "Moving...").do_in_thread do
            FileUtils.makedirs d unless File.directory?(d)
            FileUtils.cp f, d
            FileUtils.rm f
          end
        elsif view == @b5
          DB.close
          FileUtils.rm DB.file
          update_db_buttons
        end
      end
    end
  end
end
