java_import "android.widget.SimpleCursorAdapter"
java_import "android.graphics.Typeface"
java_import "android.view.Gravity"

ruboto_import_widgets :ImageButton, :RelativeLayout, :ScrollView, :Spinner, :EditText

def desktop
  $activity.start_ruboto_activity "$desktop" do
    requestWindowFeature(Java::android.view.Window::FEATURE_NO_TITLE)

    def self.create_button(title, img, manage=true, &block)
      @current_id ||= 50000
      ll = relative_layout do
        ib = image_button(
          :id => (@current_id += 1),
          :image_resource => img, 
          :background_color => Color::WHITE, 
          :height => :wrap_content, 
          :width => :fill_parent,
          :enabled => manage ? DB.exists? : true,
          :color_filter => manage ? (DB.exists? ? Color::TRANSPARENT : 0x7fffffff) : Color::TRANSPARENT,
          :on_click_listener => block_given? ? RubotoOnClickListener.new.handle_click{|v| block.call} : nil
        )
        ib.getLayoutParams.addRule RelativeLayout::CENTER_IN_PARENT
        @db_icons << ib if manage
        tv = text_view(
          :text => title, 
          :gravity => Gravity::CENTER_HORIZONTAL,
          :text_size => 16,
          :height => :wrap_content, 
          :width => :fill_parent,
          :text_color => manage ? (DB.exists? ? Color::BLACK : Color::GRAY) : Color::BLACK
        )
        tv.getLayoutParams.addRule(@rotation == 1 ? RelativeLayout::ALIGN_BOTTOM : RelativeLayout::BELOW, @current_id)
        @db_text << tv if manage
      end
      @set_weight << ll 
      ll
    end

    setup_content do
      @rotation = getSystemService(Java::android.content.Context::WINDOW_SERVICE).getDefaultDisplay.getRotation % 2

      @set_weight = []
      @db_icons = []
      @db_text = []

      ll = linear_layout(:orientation => LinearLayout::VERTICAL, :background_color => Color::WHITE) do
        text_view(:text => "Android API Browser", 
                  :gravity => Java::android.view.Gravity::CENTER_HORIZONTAL,
                  :text_size => 24,
                  :text_color => Color::BLACK,
                  :padding => [0,10,0,10])

        @set_weight << linear_layout(:height => :fill_parent, :width => :fill_parent) do
          create_button("Browse", Ruboto::R::drawable::browse3){show_browse}
          create_button("Search", Ruboto::R::drawable::search) {show_search}
          create_button("API Levels", Ruboto::R::drawable::level_info){show_apis} if @rotation == 1
        end
        unless @rotation == 1
          @set_weight << linear_layout(:height => :fill_parent, :width => :fill_parent) do
            create_button("Manage Data", Ruboto::R::drawable::database, false){DB.manage}
            create_button("API Levels", Ruboto::R::drawable::level_info) {show_apis}
          end
        end
        @set_weight << linear_layout(:height => :fill_parent, :width => :fill_parent) do
          create_button("Manage Data", Ruboto::R::drawable::database, false){DB.manage} if @rotation == 1
          create_button("Settings", Ruboto::R::drawable::settings){show_settings}
          create_button("Help", Ruboto::R::drawable::about, false){show_help}
        end

        @toaster = text_view(
                  :gravity => Gravity::CENTER,
                  :text_size => 14,
                  :height => :wrap_content, 
                  :width => :fill_parent,
                  :text_color => Color::GRAY,
                  :padding => [5,10,5,10])
      end
      @set_weight.each{|i| i.getLayoutParams.weight = 1.0}
      ll
    end

    handle_configuration_changed do |config|
      @view_parent = nil
      setContentView(instance_eval &@content_view_block) if @content_view_block
      @toaster.text = @last_toast
    end

    handle_finish_create do |bundle|
      if DB.exists?
         DB.check_for_updates
      else
        DB.get_remote_info
        alert_dialog :title => "No API Database",
          :message => "Next we are going to need to download a database containing the Android API information. The database is #{DB.remote_size.to_byte_string}. You can download the database to internal storage (#{DB.internal_space_available.to_byte_string} available) or external storage (#{DB.external_space_available.to_byte_string} available).",
          :positive_button => ["Internal", Proc.new{DB.update(DB.internal_dir, DB.internal_file)}],
          :neutral_button  => ["External", Proc.new{DB.update(DB.external_dir, DB.external_file)}],
          :negative_button => ["Cancel", Proc.new{$desktop.toast("You'll need to download a database to continue. Use 'Manage Data.'")}]
      end
    end

    handle_window_focus_changed do |has_focus|
      if has_focus
        @db_icons.each do |ib|
          ib.setEnabled DB.exists?
          ib.setColorFilter DB.exists? ? Color::TRANSPARENT : 0x7fffffff
        end
        @db_text.each {|tv| tv.setTextColor DB.exists? ? Color::BLACK : Color::GRAY}
      end
    end

    handle_create_options_menu do
      add_menu("About") {show_about}
      true
    end

    def self.toast(text)
#      @last_toast = text
#      @toaster.setText text
      super text
    end
  end
end

#########################################################################################

def show_browse(api_limit=nil)
  DB.open
  SQLiteModel.api_limit api_limit
  $desktop.launch_list("Packages", Package.all) do |c, av, v, p, id|
    PackageController.new(Package.find(id)).start_activity
  end
end

#########################################################################################

def show_apis
  $desktop.start_ruboto_activity "$apis" do
    setTitle "Android API Data"

    setup_content do
      DB.open

      @@max_api ||= 0
      @@old_max_api = @@max_api
      @@max_api = DB.max_api_level

      unless (@@data ||= nil) and (@@max_api == @@old_max_api)
        cursor = $db.rawQuery("select * from summary;", nil)
        cursor.moveToFirst
        @@data = {}
        while not cursor.isAfterLast
          api = cursor.getInt(0)
          type = cursor.getString(1).to_sym
          @@data[api] ||= {}
          @@data[api][type] = [cursor.getString(2), cursor.getString(3), cursor.getString(4)]
          cursor.moveToNext
        end
        cursor.close
      end

      scroll_view do
        table_layout(:width => :fill_parent, :column_stretchable => [0, true]) do
          1.upto(@@max_api) do |i|
            table_row do
              tv = text_view :text => DB.api_level(i)[:full_name], 
                             :gravity => Gravity::CENTER_HORIZONTAL,
                             :background_color => Color::DKGRAY, 
                             :text_size => 20, 
                             :typeface => [Typeface::DEFAULT, Typeface::BOLD]
              tv.getLayoutParams.span = 4
            end
            table_row do
              ll = linear_layout
              ["<=", "=", ">="].each do |j|
                # Create the Button directly...using the button method puts us over the stack limit
                b = Button.new(self)
                ll.addView(b)
                b.setText j
                b.setOnClickListener RubotoOnClickListener.new.handle_click{|v| show_browse("#{j} #{i}")}
                b.getLayoutParams.width = ViewGroup::LayoutParams::FILL_PARENT
                b.getLayoutParams.weight = 1.0
              end
              ll.getLayoutParams.span = 4
            end

            @@actions ||= %w(Add Dep Rem)
            @@types ||= %w(Package Class Interface Field Constructor Method)
            @@types_sym ||= @@types.map(&:to_sym)
            @@types_string ||= "\n" + @@types.join("\n")

            table_row do
              text_view(:text => @@types_string)
              0.upto(2) do |k|
                text_view(:text => ([@@actions[k]] + @@types_sym.map{|j| @@data[i][j][k]}).join("\n"), 
                          :gravity => Gravity::RIGHT, :min_width => 100, :padding => [0,0,5,0])
              end
            end
          end
        end
      end
    end
  end
end

#########################################################################################

def show_search
  $desktop.start_ruboto_activity "$search" do
    setTitle "Search"

    DB.open
    @types = {"Packages" => "P", "Classes" => "C", "Interfaces" => "I", "Fields" => "f", "Constructors" => "c", "Methods" => "m"}
    @apis = ["All APIs"]
    @apis_map = {}
    DB.api_levels.each_with_index{|a, i| @apis << a[:full_name]; @apis_map[a[:full_name]] = (i+1)}

    setup_content do

      linear_layout(:orientation => LinearLayout::VERTICAL) do
        adapter_list = ArrayList.new
        adapter_list.addAll(["All types"] + %w(Packages Classes Interfaces Fields Constructors Methods))
        adapter1 = ArrayAdapter.new(self, R::layout::simple_spinner_item, adapter_list)
        adapter1.setDropDownViewResource(R::layout::simple_spinner_dropdown_item)

        adapter_list = ArrayList.new
        adapter_list.addAll(@apis)
        adapter2 = ArrayAdapter.new(self, R::layout::simple_spinner_item, adapter_list)
        adapter2.setDropDownViewResource(R::layout::simple_spinner_dropdown_item)

        linear_layout do
          @type_spinner = spinner :adapter => adapter1
          @type_spinner.getLayoutParams.weight = 1.0
          @api_spinner = spinner :adapter => adapter2
          @api_spinner.getLayoutParams.weight = 1.0
        end

        linear_layout do
          @et = edit_text :width => :fill_parent
          @et.getLayoutParams.weight = 1.0
          button :text => "Go"
        end

        @cursor_adaptor = SimpleCursorAdapter.new(self, R::layout::two_line_list_item, nil,
                     ["name", "parent"].to_java(:string), [AndroidIds::text1, AndroidIds::text2].to_java(:int))
        @cursor_adaptor.setViewBinder(
          RubotoCursorViewBinder.new.handle_set_view_value do |view, cursor, index|
            if view.getId == AndroidIds::text1
              view.setText cursor.getString(cursor.getColumnIndex("name"))
              view.setTextColor Color::WHITE
            else
              view.setText [
                             cursor.getString(cursor.getColumnIndex("package")), 
                             cursor.getString(cursor.getColumnIndex("class"))
                           ].compact.join(".")
              view.setHorizontallyScrolling true
            end
            true
          end
        )
        @ev = text_view :text => "No results found", :visibility => View::GONE, 
                        :gravity => Gravity::CENTER_HORIZONTAL,
                        :background_color => Color::WHITE, :text_color => Color::BLACK
        @lv = list_view :adapter => @cursor_adaptor
      end
    end

    handle_click do |view|
      @cursor.close if @cursor

      select_clause = "main._id _id, package.name package, class.name class, main.name name"
      from_clause   = "main left outer join main class on main.class_id=class._id left outer join main package on main.package_id=package._id"
      where_clause  = []
      where_clause << "main.name like '%#{@et.getText.to_s.strip}%'" unless @et.getText.to_s.strip == ""
      where_clause << "main.object_type='#{@types[@type_spinner.getSelectedView.getText.to_s]}'" unless @type_spinner.getSelectedView.getText == "All types"
      api = @apis_map[@api_spinner.getSelectedView.getText]
      where_clause << "(main.api_added=#{api} or main.deprecated=#{api} or main.api_removed=#{api})" if api

      @cursor = $db.rawQuery("select #{select_clause} from #{from_clause} #{where_clause.empty? ? '' : 'where '}#{where_clause.join(' and ')} order by name;", nil)

      @ev.setVisibility(View::VISIBLE)
      @ev.setText("#{@cursor.getCount == 0 ? 'No' : @cursor.getCount} results found")
      @lv.setVisibility(@cursor.getCount == 0 ? View::GONE : View::VISIBLE)
      @cursor_adaptor.changeCursor @cursor
    end

    handle_item_click do |av, v, p, id| 
      SQLiteModel.api_limit nil
      Controller.start_activity_for(SQLiteModel.find(id))
    end
  end
end

#########################################################################################

def show_text(title, text)
  $desktop.alert_dialog :title => title,
    :positive_button => ["Done", Proc.new{|d, w| d.dismiss}],
    :view => ($desktop.scroll_view do
      tv = $desktop.text_view :padding => [5,5,5,5], :text => text, :text_color => Color::WHITE
      Java::android.text.util::Linkify.addLinks(tv, Java::android.text.util::Linkify::ALL)
    end)
end

#########################################################################################

def show_about
  show_text "About the Android API Browser",
"This application was developed in Ruby through the Ruboto project (JRuby on Android). This project also uses two libraries from Mark Murphy (commonsguy): cwac-merge and cwac-sacklist.

Please send feedback or feature requests to scott@rubyandroid.com.

Developer:
Scott Moyer
scott@rubyandroid.com
http://rubyandroid.com

Android Open Source Project:
http://source.android.com
Apache License 2.0: http://www.apache.org/licenses/LICENSE-2.0

Ruboto Core:
http://github.com/ruboto/ruboto-core
MIT License

Join the Ruboto Community:
http://groups.google.com/group/ruboto

Source for Mark Murphy's libraries can be found on Github:
https://github.com/commonsguy/cwac-merge
https://github.com/commonsguy/cwac-sacklist
Apache License 2.0: http://www.apache.org/licenses/LICENSE-2.0

JRuby Project:
http://jruby.org
Common Public License version 1.0
GNU General Public License version 2
GNU Lesser General Public License version 2.1

Icons:
Ahmad Hania
The Spherical Icon set
http://portfolio.ahmadhania.com
Creative Commons (Attribution-NonCommercial-ShareAlike 3.0 Unported)"
end

#########################################################################################

def show_help
  show_text "Help Information",
"The Android API Browser provides a convenient UI for exploring the Android APIs across versions. The Android Open Source Project publishes an XML specification of the API each time they release a new version. I've taken the specifications for each API available and built a single database for use with this application.

To use this application you will need to download the API database. The database is ~8MB and can be stored on either your internal or external storage. You will be prompted to download the database and notified when updates are available.

-----

Here's what you can do...

Browse: Walk through the API beginning with Packages. You should be able to follow obvious paths through the API (e.g., clicking on a return type will take you to the related class). Relevant information has been added where possible (e.g., browsing an interface will show all classes that implement that interface). As you're browsing you will see color coding based on the status on an object (e.g., deprecated, removed, or added after a specific API level). You can set the colors and the API boundary through Settings.

Search: Allows text searching on the entire API. You can constrain your search by type and/or API level.

Manage Data: Allows you to download an API database, move the database between internal and external storage, or remove the database from your device.

API Levels: Shows you statistical information for each API level (totals for objects added, deprecated, or removed). You can also use this interface to constrain your browsing by API level. When you're constraining your browsing you will see some items in gray text. These items do not meet the criteria of your constraint, but they are needed to get you to items that do meet your constraint (e.g., showing you a package that has new classes).

Settings: As you're browsing you will see color coding based on the status on an object (e.g., deprecated, removed, or added after a specific API level). You can set the colors and the API boundary here.

Help: You're looking at it.

About (menu): Some more information on this software.

-----

Here's what you can see...

- Package
-- Interface 
--- Field
--- Method
-- Class 
--- Field
--- Constructor
--- Method

Including...

Package: name, API added

Interface: name, package, modifiers, API added/deprecated/removed, fields, methods, implemented by (classes), returned by (methods), parameter for (methods)

Class: name, package, extends, modifiers, API added/deprecated/removed, fields, constructors, methods, returned by (methods), parameter for (methods), raised by (method, if exception)

Field: name, class/interface, package, type, value, modifiers, API added/deprecated/removed

Constructor: name, class, package, modifiers, API added/deprecated/removed, parameters, raises

Method: name, class/interface, package, returns, modifiers, API added/deprecated/removed, parameters, raises

Bring up the menu on any of these objects and you can select 'Go to web' to pop up a browser window on the http://developer.android.com documentation."
end
