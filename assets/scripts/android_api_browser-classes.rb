class SQLiteModel
  def self.inherited(subclass)
    @subclasses ||= []
    @subclasses << subclass
  end

  def self.clear
    if self.class == SQLiteModel
      @@instances = {}
      @subclasses.each(&:clear)
    end
  end

  def self.table_name(name); @table_name = name.to_s; end 
  def self.get_table_name; @table_name; end 
  def self.level_name(name); @level_name = name.to_s; end 
  def self.get_level_name; @level_name; end 

  # Either <= #, = #, or >= #
  def self.api_limit(str); @@api_limit = str; end
  def self.get_api_limit;  @@api_limit; end 

  def self.register_class_type type
    @@registered_types ||= {}
    @@registered_types[type] = self
    @my_type = type
  end

  def self.class_for_type type
    @@registered_types ||= {}
    @@registered_types[type]
  end

  def self.column(name, type=:text, default=nil)
    name = name.to_sym
    @columns ||= []
    @column_types ||= {}
    @column_defaults ||= {}
    @columns << name unless @columns.include?(name)
    @column_types[name] = type.to_sym
    @column_defaults[name] = default
  end

  def self.columns; @columns; end
  def self.column_types; @column_types; end
  def self.column_defaults; @column_defaults; end

  def self.belongs_to name, type=nil, reference=nil
    reference = "#{type or name}_id" unless reference
    column reference.to_s , :int

    class_eval "
      def #{name}_id
        unless @#{name}_id
          ref = self['#{reference.to_s}']
          @#{name}_id = (ref ? ref.to_i : nil)
        end
        @#{name}_id
      end

      def #{name}
        @#{name} ||= self['#{reference.to_s}'] ? #{(type or name).to_s.capitalize}.find(self['#{reference.to_s}'].to_i) : nil
      end
    "
  end

  def self.has_many(name, type, order_by="name")
    class_eval "
      def #{name}
        #{type.to_s.capitalize}.all({'#{get_level_name}_id' => @id}, \"#{order_by}\")
      end
    "
  end

  def self.has_and_belongs_to_many(name, table, foreign_key, join, order_by="name")
    class_eval "
      def #{name}
        $db.rawQuery(
          'select main._id _id, main.name name, main.name_extra name_extra, main.api_added api_added,' + 
          ' main.deprecated deprecated, main.api_removed api_removed' + 
          ' from main, #{table} where #{join} and #{foreign_key} = ? ' + 
          (SQLiteModel.get_api_limit.nil? ? 
            '' : 
            ('and ((api_added ' + SQLiteModel.get_api_limit + 
             ') or (deprecated ' + SQLiteModel.get_api_limit + 
             ') or (api_removed ' + SQLiteModel.get_api_limit + '))')) + 
          ' order by #{order_by};', [@id.to_s].to_java(:string)
        )
      end
    "
  end

  def self.one_query(id)
    "select * from main where _id = #{id};"
  end

  def self.all_query(where={}, order_by=nil)
    rv = "select * from main where object_type = '#{@my_type}';"
    if get_api_limit
      rv = rv.gsub(";", (get_level_name ? 
                           " and _id in (select distinct(#{get_level_name}_id) from main where " :
                           " and (") +
                         "api_added #{get_api_limit} or deprecated #{get_api_limit} or api_removed #{get_api_limit});")
    end
    unless where.empty?
      tmp = []
      where.each{|k, v| tmp << "#{k}=#{v.is_a?(String) ? ("'" + v + "'") : v }"}
      rv.gsub!(";", " and #{tmp.join(" and ")};")
    end
    rv.gsub!(";", " order by #{order_by};") if order_by
    rv
  end

  def self.all(where={}, order_by="name")
    $db.rawQuery(all_query(where, order_by), nil)
  end

  def self.one(id)
    $db.rawQuery(one_query(id), nil)
  end

  def self.find(id)
    @@instances ||= {}
    unless @@instances[id]
      cursor = one(id)
      cursor.moveToFirst
      @@instances[id] = class_for_type(cursor.getString(cursor.getColumnIndex('object_type'))).new(id, cursor)
    end
    @@instances[id]
  end

  def initialize(id, cursor=nil)
    @id = id
    @values = {}

    if cursor
      0.upto(cursor.getColumnCount-1) {|i| @values[cursor.getColumnName(i).to_sym] = cursor.getString(i) unless cursor.isNull(i)} 
      cursor.close
    end

    cursor = $db.rawQuery("select * from #{self.class.get_table_name} where _id = #{id};", nil)
    cursor.moveToFirst
    0.upto(cursor.getColumnCount-1) {|i| @values[cursor.getColumnName(i).to_sym] = cursor.getString(i) unless cursor.isNull(i)} 
    cursor.close
  end

  def [](key)
    @values[key.to_sym] || self.class.column_defaults[key.to_sym]
  end

  def id
    @id
  end
end

class Package < SQLiteModel
  table_name :main
  level_name :package
  register_class_type "P"

  column :_id,       :int
  column :name
  column :api_added, :int

  has_many :classes,    :klass
  has_many :interfaces, :interface

  def self.one_query(id)
    "select * from main where _id = #{id};"
  end
end

class Klass < SQLiteModel
  table_name "class"
  level_name :class
  register_class_type "C"

  column :_id,        :int
  column :name
  column :final,      :boolean, "false"
  column :abstract,   :boolean, "false"
  column :static,     :boolean, "false"
  column :visibility, :text,    "public"
  column :deprecated, :int
  column :api_added,  :int
  column :api_removed,:int

  belongs_to :package
  belongs_to :extends, :klass, :extends_id

  has_and_belongs_to_many :implements, :implements, :parent_id, "interface_id = _id"
  has_and_belongs_to_many :returned_by, :method, :return_id, "method._id = main._id and object_type=\"m\""
  has_and_belongs_to_many :parameter_for, :parameter, :type_id, "parameter.method_id = main._id and object_type=\"m\""
  has_and_belongs_to_many :raised_by, :exception, :exception_id, "parent_id = _id"

  has_many :fields,       :field
  has_many :constructors, :constructor
  has_many :methods,      :nethod
end

class Interface < SQLiteModel
#  table_name "interface"
  table_name "class"
  level_name :class
  register_class_type "I"

  column :_id,       :int
  column :name
  column :final,      :boolean, "false"
  column :abstract,   :boolean, "false" #"true"
  column :static,     :boolean, "false"
  column :visibility, :text,    "public"
  column :deprecated, :int
  column :api_added,  :int
  column :api_removed,:int

  belongs_to :package

  has_many :fields,     :field
  has_many :methods,    :nethod

  has_and_belongs_to_many :implements, :implements, :parent_id, "interface_id = _id"
  has_and_belongs_to_many :implemented_by, :implements, :interface_id, "parent_id = _id"
  has_and_belongs_to_many :returned_by, :method, :return_id, "method._id = main._id and object_type=\"m\""
  has_and_belongs_to_many :parameter_for, :parameter, :type_id, "parameter.method_id = main._id and object_type=\"m\""
end

class Field < SQLiteModel
  table_name :field
  register_class_type "f"

  column :_id,          :int
  column :name
  column :type_extra
  column :value
  column :transient,    :boolean, "false"
  column :final,        :boolean, "true"
  column :static,       :boolean, "true"
  column :volatile,     :boolean, "false"
  column :visibility,   :text,    "public"
  column :deprecated,   :int
  column :api_added,    :int
  column :api_removed,  :int

  belongs_to :klass, :klass, :class_id
  belongs_to :type, :klass, :type
  belongs_to :package
end

class Constructor < SQLiteModel
#  table_name :constructor
  table_name :method
#  level_name :method
  register_class_type "c"

  column :_id,          :int
  column :name
  column :name_extra
  column :final,        :boolean, "false"
  column :static,       :boolean, "false"
  column :visibility,   :text,    "public"
  column :deprecated,   :int
  column :api_added,    :int
  column :api_removed,  :int

  belongs_to :klass, :klass, :class_id
  belongs_to :package

  has_many :parameters, :parameter, "position"
  has_and_belongs_to_many :exceptions, :exception, :parent_id, "exception_id = _id"
end

class Nethod < SQLiteModel
  table_name :method
  register_class_type "m"
 
  column :_id,          :int
  column :name
  column :name_extra
  column :return_extra
  column :final,        :boolean, "false"
  column :synchronized, :boolean, "false"
  column :native,       :boolean, "false"
  column :abstract,     :boolean, "false"
  column :static,       :boolean, "false"
  column :visibility,   :text,    "public"
  column :deprecated,   :int
  column :api_added,    :int
  column :api_removed,  :int

  has_many :parameters, :parameter, "position"
  has_and_belongs_to_many :exceptions, :exception, :parent_id, "exception_id = _id"

  belongs_to :return, :klass, :return_id
  belongs_to :klass, :klass, :class_id
  belongs_to :package
end

class Parameter < SQLiteModel
  table_name :parameter
  level_name :method

  column :name
  column :type_id
  column :position

  belongs_to :nethod
  belongs_to :type, :klass, :type_id

  def self.clear
    @instances = {}
  end

  def self.find(id)
    @instances ||= {}
    unless @instances[id]
      @instances[id] = new(id)
    end
    @instances[id]
  end

  def self.all_query(where={}, order_by=nil)
    rv = "select * from parameter;"
    unless where.empty?
      tmp = []
      where['method_id'] = where.delete('_id')
      where.each{|k, v| tmp << "#{k}=#{v.is_a?(String) ? ("'" + v + "'") : v }"}
      rv.gsub!(";", " where #{tmp.join(" and ")};")
    end
    rv.gsub!(";", " order by #{order_by};") if order_by
    rv
  end
end
