ruboto_import "#{$callbacks_package}.RubotoCursorViewBinder"
java_import "android.graphics.Color"
java_import "com.commonsware.cwac.merge.MergeAdapter"
java_import "android.content.Intent"
java_import "android.net.Uri"

class RubotoCursorViewBinder
  def self.main
    @vb ||= RubotoCursorViewBinder.new.handle_set_view_value do |view, cursor, index|
              extra = cursor.getColumnIndex("name_extra")
              added = cursor.getInt(cursor.getColumnIndex('api_added'))
              dep_col = cursor.getColumnIndex("deprecated")
              dep_null = cursor.isNull(dep_col)
              rem_col = cursor.getColumnIndex("api_removed")
              rem_null = cursor.isNull(rem_col)

              view.setText cursor.getString(index) + ((extra == -1 or cursor.isNull(extra)) ? "" : "(#{cursor.getString(extra)})")

              if (not SQLiteModel::get_api_limit.nil?) and (SQLiteModel.get_api_limit[0..0] != "<")
                comparison = "#{SQLiteModel.get_api_limit[0..0] == '=' ? '=' : ''}#{SQLiteModel.get_api_limit}"
                a = ["(#{added} #{comparison})"]
                a << (dep_null ? "false" : "(#{cursor.getInt(dep_col)} #{comparison})")
                a << (rem_null ? "false" : "(#{cursor.getInt(rem_col)} #{comparison})")
                view.setTextColor(eval(a.join(" or ")) ? Color::WHITE : Color::GRAY)
              else
                view.setTextColor Color::WHITE
              end

              view.setCompoundDrawablePadding(5)
              if !rem_null
                view.setCompoundDrawables(RubotoCursorViewBinder.removed_drawable, nil, nil, nil) 
              elsif !dep_null
                view.setCompoundDrawables(RubotoCursorViewBinder.deprecated_drawable, nil, nil, nil) 
              elsif added > Preferences['min_sdk']
                view.setCompoundDrawables(RubotoCursorViewBinder.warning_drawable, nil, nil, nil) 
              else
                view.setCompoundDrawables(RubotoCursorViewBinder.default_drawable, nil, nil, nil) 
              end

              view.setPadding 0, 0, 0, 0
              true
            end
  end

  def self.new_drawable(color)
    drawable = Java::android.graphics.drawable.PaintDrawable.new(color)
    drawable.setBounds 0, 0, 5, 40 * $activity.getResources().getDisplayMetrics().density
    drawable
  end

  def self.default_drawable
    @default_drawable ||= new_drawable(Color::BLACK)
  end

  def self.warning_drawable
    if @old_color_newer != Preferences['color_newer']
      @warning_drawable = new_drawable(Preferences['color_newer'])
      @old_color_newer = Preferences['color_newer']
    end
    @warning_drawable
  end

  def self.deprecated_drawable
    if @old_color_deprecated != Preferences['color_deprecated']
      @deprecated_drawable = new_drawable(Preferences['color_deprecated'])
      @old_color_deprecated = Preferences['color_deprecated']
    end
    @deprecated_drawable
  end

  def self.removed_drawable
    if @old_color_removed != Preferences['color_removed']
      @removed_drawable = new_drawable(Preferences['color_removed'])
      @old_color_removed = Preferences['color_removed']
    end
    @removed_drawable 
  end
end

class Controller
  def self.has_many(name, type, on_click=nil)
    name = name.to_sym
    @has_many ||= []
    @has_many_types ||= {}
    @has_many_click ||= {}
    @has_many << name unless @has_many.include?(name)
    @has_many_types[name] = type
    @has_many_click[name] = on_click if on_click
  end

  def self.get_has_many; @has_many or []; end
  def self.has_many_types; @has_many_types or {}; end
  def self.has_many_click; @has_many_click or {}; end

  def self.for_class klass
    const_get("#{klass.name}Controller")
  end

  def initialize(obj)
    @object = obj
  end

  def activity=(value)
    @activity = value
  end

  def self.start_activity_for(item)
    for_class(item.class).new(item).start_activity
  end

  def start_activity
    controller = self
    $activity.start_ruboto_activity activity_variable do
      setTitle controller.title

      setup_content do
        controller.activity = self
        @lv = list_view :adapter => controller.adapter
      end

      handle_item_click do |av, v, p, id| 
        controller.start_activity_for_child(p, id)
      end

      handle_create_options_menu do
        add_menu("Go to web") {startActivity Intent.new(Intent::ACTION_VIEW, Uri.parse(controller.url)) }
        true
      end
    end
  end

  def start_activity_for_child(p, id)
    click = self.class.has_many_click[@adapters[@merge_adapter.getAdapter(p)]]
    if click
      click.call(id)
    else
      item = self.class.has_many_types[@adapters[@merge_adapter.getAdapter(p)]].find(id)
      Controller.start_activity_for(item)
    end
  end

  def activity_variable
    "$activity"
  end

  def title
    @object['name']
  end

  def base_info
    []
  end

  def modifier_info
    []
  end

  def url
    "http://developer.android.com/reference"
  end

  def modifiers
    l = modifier_info.map{|t, v| v == "false" ? nil : (v == "true" ? t.downcase : v)}.compact
    l.empty? ? nil : l.join(" ")
  end

  def adapter
    @merge_adapter = MergeAdapter.new

    @merge_adapter.addView(
      @activity.text_view(:text => "Limiting view (API #{SQLiteModel.get_api_limit})", 
                :gravity => Gravity::CENTER_HORIZONTAL,
                :text_size => 20,
                :background_color => Color::WHITE, 
                :text_color => Color::BLACK)
    ) unless SQLiteModel::get_api_limit.nil?

    @merge_adapter.addView(
      @activity.table_layout(:padding => [10,0,0,0]) do
        l = base_info 
        l << ["Modifiers", modifiers]
        l.each do |title, value, block|
          if value
            @activity.table_row(block ? {
              :background_resource => R::drawable::list_selector_background, 
              :on_click_listener   => (RubotoOnClickListener.new.handle_click{block.call}), 
              :focusable           => true 
            } : {}) do
              @activity.text_view :text => "#{title}: ", :text_size => 14
              @activity.text_view :text => value, :text_size => 20, :text_color => Color::WHITE, :width => :fill_parent
            end
          end
        end
      end 
    )

    if (@object['api_added'] != "1") or @object['deprecated'] or @object['api_removed']
      @merge_adapter.addView(
        @activity.text_view(
          :text => "API Level", 
          :background_color => Color::DKGRAY, 
          :typeface => [Typeface::DEFAULT, Typeface::BOLD]
        )
      )

      @merge_adapter.addView(
        @activity.table_layout(:padding => [10,0,0,0]) do
          [["Added",      @object['api_added'] != "1" ? "android-#{@object['api_added']}"   : nil],
           ["Deprecated", @object['deprecated']  ? "android-#{@object['deprecated']}"  : nil],
           ["Removed",    @object['api_removed'] ? "android-#{@object['api_removed']}" : nil],
          ].each do |title, value|
            if value
              @activity.table_row do
                @activity.text_view :text => "#{title}: ", :text_size => 14
                @activity.text_view :text => value, :text_size => 20, :text_color => Color::WHITE
              end
            end
          end
        end 
      )
    end

    @adapters = {}

    self.class.get_has_many.each do |i| 
      cursor = @object.send(i)
      if cursor.getCount > 0
        @merge_adapter.addView(
          @activity.text_view(
            :text => i.to_s.capitalize.gsub("_", " ") + " (#{cursor.getCount.to_i})", 
            :background_color => Color::DKGRAY, 
            :typeface => [Typeface::DEFAULT, Typeface::BOLD]
          )
        )

        @activity.startManagingCursor(cursor)
        @merge_adapter.addAdapter(
          a = SimpleCursorAdapter.new(
            @activity, 
            Ruboto::R::layout::list_item_single,
            cursor,
            ["name"].to_java(:string), 
            [Ruboto::Id::text1].to_java(:int)
          )
        )

        a.setViewBinder(RubotoCursorViewBinder.main)

        @adapters[a] = i
      end
    end

    @merge_adapter
  end
end

class PackageController < Controller
  has_many :interfaces, Interface
  has_many :classes, Klass

  def title
    "Package: #{@object['name']}"
  end

  def base_info
    [["Package", @object[:name]],
    ]
  end

  def url
    "#{super}/#{@object[:name].gsub('.','/')}/package-summary.html"
  end
end

class KlassController < Controller
  has_many :implements, Interface
  has_many :fields, Field
  has_many :constructors, Constructor
  has_many :methods, Nethod
  has_many :parameter_for, Nethod
  has_many :returned_by, Nethod
  has_many :raised_by, Nethod

  def title
    "Class: #{@object.package['name']}.#{@object['name']}"
  end

  def base_info
    [
     ["Class",          @object[:name]],
     ["Package",        @object.package['name'], Proc.new{Controller.start_activity_for(@object.package)}],
     ["Extends",        @object.extends ? @object.extends['name'] : nil, Proc.new{Controller.start_activity_for(@object.extends)}],
    ]
  end

  def modifier_info
    [
     ["Visibility",     @object[:visibility]],
     ["Final",          @object[:final]],
     ["Abstract",       @object[:abstract]],
     ["Static",         @object[:static]],
    ]
  end

  def url
    "#{super}/#{@object.package[:name].gsub('.','/')}/#{@object[:name]}.html"
  end
end

class InterfaceController < Controller
  has_many :implements, Interface
  has_many :implemented_by, Klass
  has_many :fields, Field
  has_many :methods, Nethod
  has_many :parameter_for, Nethod
  has_many :returned_by, Nethod

  def title
    "Interface: #{@object.package['name']}.#{@object['name']}"
  end

  def base_info
    [
     ["Interface",      @object[:name]],
     ["Package",        @object.package['name'], Proc.new{Controller.start_activity_for(@object.package)}],
    ]
  end

  def modifier_info
    [
     ["Visibility",     @object[:visibility]],
     ["Final",          @object[:final]],
     ["Abstract",       @object[:abstract]],
     ["Static",         @object[:static]],
    ]
  end

  def url
    "#{super}/#{@object.package[:name].gsub('.','/')}/#{@object[:name]}.html"
  end
end

class FieldController < Controller
  def title
    "Field: #{@object.klass['name']}.#{@object['name']}"
  end

  def base_info
    [
     ["Field",          @object[:name]],
     [@object.klass.is_a?(Klass) ? "Class" : "Interface", @object.klass['name'], 
       Proc.new{Controller.start_activity_for(@object.klass)}],
     ["Package",        @object.package['name'], Proc.new{Controller.start_activity_for(@object.package)}],
     ["Type",           @object.type ? (@object.type['name'] + (@object['type_extra'] or "")) : @object['type_extra'],
       @object.type ? Proc.new{Controller.start_activity_for(@object.type)} : nil],
     ["Value",          @object[:value]],
    ]
  end

  def modifier_info
    [
     ["Visibility",     @object[:visibility]],
     ["Transient",      @object[:Transient]],
     ["Final",          @object[:final]],
     ["Static",         @object[:static]],
     ["Volatile",       @object[:volatile]],
    ]
  end

  def url
    "#{super}/#{@object.package[:name].gsub('.','/')}/#{@object.klass[:name]}.html##{@object[:name]}"
  end
end

class ConstructorController < Controller
  has_many :exceptions, Klass
  has_many :parameters, Parameter, Proc.new{|id| p = Parameter.find(id); Controller.start_activity_for(p.type) if p.type}

  def title
    "Constructor: new #{@object['name']}"
  end

  def base_info
    [
     ["Constructor",    @object[:name]],
     ["Class",          @object.klass[:name]],
     ["Package",        @object.package['name']],
    ]
  end

  def modifier_info
    [
     ["Visibility",     @object[:visibility]],
     ["Final",          @object[:final]],
     ["Static",         @object[:static]],
    ]
  end

  def url
    "#{super}/#{@object.package[:name].gsub('.','/')}/#{@object.klass[:name]}.html##{@object[:name]}(#{@object[:name_extra]})"
  end
end

class NethodController < Controller
  has_many :exceptions, Klass
  has_many :parameters, Parameter, Proc.new{|id| p = Parameter.find(id); Controller.start_activity_for(p.type) if p.type}

  def title
    "Method: #{@object.klass['name']}.#{@object['name']}"
  end

  def base_info
    [
     ["Method",         @object[:name]],
     [@object.klass.is_a?(Klass) ? "Class" : "Interface", @object.klass['name'], 
       Proc.new{Controller.start_activity_for(@object.klass)}],
     ["Package",        @object.package['name'], Proc.new{Controller.start_activity_for(@object.package)}],
     ["Returns",        @object.return ? (@object.return['name'] + (@object['return_extra'] or "")) : (@object['return_extra'] or "void"),
       @object.return ? Proc.new{Controller.start_activity_for(@object.return)} : nil],
    ]
  end

  def modifier_info
    [
     ["Visibility",     @object[:visibility]],
     ["Final",          @object[:final]],
     ["Synchronized",   @object[:synchronized]],
     ["Native",         @object[:native]],
     ["Abstract",       @object[:abstract]],
     ["Static",         @object[:static]],
    ]
  end

  def url
    "#{super}/#{@object.package[:name].gsub('.','/')}/#{@object.klass[:name]}.html##{@object[:name]}(#{@object[:name_extra]})"
  end
end
