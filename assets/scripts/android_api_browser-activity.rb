ruboto_import "#{$callbacks_package}.RubotoRunnable"
ruboto_import "#{$callbacks_package}.RubotoDialogOnClickListener"

java_import "android.os.Message"
java_import "android.os.Handler"
java_import "android.app.ProgressDialog"
java_import "java.net.URL"
java_import "java.io.BufferedInputStream"
java_import "java.util.zip.GZIPInputStream"

class Activity
  def alert_dialog(options)
    dialog = Java::android.app::AlertDialog::Builder.new(self)
    options.each do |k, v|
      if v.is_a?(Array)
        if v[-1].is_a?(Proc)
          proc = v[-1]
          v[-1] = RubotoDialogOnClickListener.new.handle_click{|d, w| proc.call(d,w)}
        end
        dialog.send("set#{k.to_s.gsub(/(^|_)([a-z])/) {$2.upcase}}", *v)
      else
        dialog.send("set#{k.to_s.gsub(/(^|_)([a-z])/) {$2.upcase}}", v)
      end
    end
    dialog.create.show
  end

  def launch_list(a_title, query_or_array, &block)
    self.start_ruboto_activity "$list" do
      setTitle a_title

      setup_content do
        if query_or_array.is_a?(Array)
          @lv = list_view :list => query_or_array
        else
          if query_or_array.is_a?(String) 
            @cursor = $db.rawQuery(query_or_array, nil)
            startManagingCursor(@cursor)
          else
            @cursor = query_or_array
          end

          setTitle "#{a_title} (#{@cursor.getCount})"

          merge_adapter = MergeAdapter.new

          merge_adapter.addView(
            text_view(:text => "Limiting view (API #{SQLiteModel.get_api_limit})", 
                :gravity => Gravity::CENTER_HORIZONTAL,
                :text_size => 20,
                :background_color => Color::WHITE, 
                :text_color => Color::BLACK)
          ) unless SQLiteModel::get_api_limit.nil?

          adapter = SimpleCursorAdapter.new(self, Ruboto::R::layout::list_item_single, @cursor,
                       ["name"].to_java(:string), [Ruboto::Id::text1].to_java(:int));
          adapter.setViewBinder(RubotoCursorViewBinder.main)
          merge_adapter.addAdapter adapter

          @lv = list_view :adapter => merge_adapter
        end
      end

      handle_item_click do |adapter_view, view, pos, item_id| 
        block.call(self, adapter_view, view, pos, item_id)
      end
    end
  end

  def progress_dialog(argh={})
    pd = ProgressDialog.new(self)
    pd.setTitle(argh[:title]) if argh[:title]
    pd.setMessage(argh[:message]) if argh[:message]
    pd.setProgressStyle((argh[:style] and argh[:style] == :horizontal) ? 
                          ProgressDialog::STYLE_HORIZONTAL : ProgressDialog::STYLE_SPINNER)
    pd.setMax(argh[:max]) if argh[:max]
    pd.setIndeterminate argh[:indeterminate] if argh[:indeterminate]
    pd.show
    pd
  end

  def do_in_thread(argh = {}, &block)
    handler = Handler.new()

    Thread.new do
      begin
        block.call
        handler.post(RubotoRunnable.new.handle_run{argh[:when_done].call if argh[:when_done]})
      rescue
        handler.post(RubotoRunnable.new.handle_run{argh[:when_failed].call if argh[:when_failed]})
      end
    end
  end

  def download_in_thread(args)
    gzipped = args[:from][-3..-1] == ".gz"
    base_file_name = args[:from].split("/")[-1]
    base_file_name = base_file_name[0..-4] if gzipped

    progress_dialog(:style => :horizontal, :title => "Downloading...", 
        :max => args[:size]).do_in_thread(args[:when_done], args[:when_failed]) do
      args[:when_starting].call if args[:when_starting]
      f = nil

      begin
        connection = URL.new(args[:from]).openConnection
        FileUtils.makedirs args[:to] unless File.directory? args[:to]
        f = File.open("#{args[:to]}/#{base_file_name}", "w")
        buff_size = 0x2000
        buff = Java::byte[buff_size].new

        i = connection.getInputStream
        i = GZIPInputStream.new(i) if gzipped
        i = BufferedInputStream.new(i, buff_size)
        x = i.read(buff, 0, buff_size)

        while x != -1
          f << String.from_java_bytes(x == buff_size ? buff : buff[0..(x-1)])
          $progress_dialog.increment_progress(x)
          x = i.read(buff, 0, buff_size)
        end
        $progress_dialog.success = true
      rescue
        $progress_dialog.success = false
        FileUtils.rm "#{args[:to]}/#{base_file_name}" if f and File.exists?("#{args[:to]}/#{base_file_name}")
      ensure
        connection.disconnect
        f.close
        args[:when_ending].call if args[:when_ending]
      end
    end
  end
end

class ProgressDialog
  attr_reader :handler
  attr_writer :success

  def success?
    @success.nil? ? true : @success
  end

  def increment_progress(amount)
    @handler.post(RubotoRunnable.new.handle_run{$progress_dialog.incrementProgressBy(amount)})
  end

  def do_in_thread(when_done=nil, when_failed=nil, &block)
    $progress_dialog = self
    @handler = Handler.new()

    Thread.new do
      block.call

      $progress_dialog.handler.post(RubotoRunnable.new.handle_run do
        $progress_dialog.dismiss
        finish_with = $progress_dialog.success? ? when_done : when_failed
        finish_with.call if finish_with
        $progress_dialog = nil
      end)
    end
  end
end
