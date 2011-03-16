java_import "android.content.SharedPreferences"

ruboto_import_preferences :CheckBoxPreference, :PreferenceCategory, :ListPreference, :PreferenceScreen

class Preferences
  def self.define(value, default, type=:string)
    @defaults ||= {}
    @types ||= {}
    @defaults[value] = default
    @types[value] = type
  end

  def self.[](value)
    @prefs ||= $desktop.getSharedPreferences("Android API Browser", Context::MODE_PRIVATE)
    rv = @prefs.getString(value, @defaults[value])
    @types[value] == :int ? rv.to_i : rv
  end

  define "min_sdk", "3", :int
  define "color_newer", Color::YELLOW.to_s, :int
  define "color_deprecated", Color::LTGRAY.to_s, :int
  define "color_removed", Color::RED.to_s, :int
  define "limit_api", ""
  define "limit_api_qualifier", "="
end

def show_settings
  $desktop.start_ruboto_activity "$preferences", RubotoPreferenceActivity do
    getPreferenceManager.setSharedPreferencesName("Android API Browser")

    setup_preference_screen do
      colors = [
                 "Black",
                 "Blue",
                 "Cyan",
                 "Dark Gray",
                 "Gray",
                 "Green",
                 "Light Gray",
                 "Magenta",
                 "Red",
                 "White",
                 "Yellow",
               ].to_java(:string)

     color_values = [
                 Color::BLACK.to_s,
                 Color::BLUE.to_s,
                 Color::CYAN.to_s,
                 Color::DKGRAY.to_s,
                 Color::GRAY.to_s,
                 Color::GREEN.to_s,
                 Color::LTGRAY.to_s,
                 Color::MAGENTA.to_s,
                 Color::RED.to_s,
                 Color::WHITE.to_s,
                 Color::YELLOW.to_s,
                   ].to_java(:string)

      DB.open
      api_ids = []
      api_names = DB.api_levels.map{|i| api_ids << i[:id].to_s; i[:full_name]}

      preference_screen do
        preference_category(:title => "API Level") do
          list_preference :key => "min_sdk", :title => "Min API", 
                          :entries => api_names.to_java(:string),
                          :entryValues => api_ids.to_java(:string),
                          :default_value => "3",
                          :summary => "select the min API (flags newer items)"
        end
        preference_category(:title => "Colors") do
          list_preference :key => "color_newer", :title => "Newer", 
                          :entries => colors,
                          :entryValues => color_values,
                          :default_value => Color::YELLOW.to_s,
                          :summary => "color for items added after min API"
          list_preference :key => "color_deprecated", :title => "Deprecated", 
                          :entries => colors,
                          :entryValues => color_values,
                          :default_value => Color::LTGRAY.to_s,
                          :summary => "color for deprecated items"
          list_preference :key => "color_removed", :title => "Removed", 
                          :entries => colors,
                          :entryValues => color_values,
                          :default_value => Color::RED.to_s,
                          :summary => "color for removed items"
        end
      end
    end
  end
end