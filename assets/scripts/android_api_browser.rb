$local_code_level = 1

def load_code(form=:require)
  $aab_files.each{|i| self.class.method(form).call("#{i}.rb") unless i == "android_api_browser"}
end

def startup
  require 'ruboto'

  $remote_site = "http://downloads.rubyandroid.org"

  if $package_name == "org.rubyandroid.apibrowser"
    $callbacks_package = $package_name
    $local_code = "#{$activity.getFilesDir.to_s}/scripts"
  else
    $callbacks_package = "org.ruboto.callbacks"
    $local_code = "/sdcard/jruby"
  end

  # To match getExternalCacheDir only available in froyo
  $external_db_dir = Java::android.os.Environment.getExternalStorageDirectory.to_s + "/Android/data/" + $package_name + "/cache"
  $main = self
  $main_binding = self.instance_eval{binding}
  $aab_files = %w(android_api_browser android_api_browser-activity android_api_browser-classes android_api_browser-controller android_api_browser-management android_api_browser-settings android_api_browser-desktop)
  load_code # :load
end

def show_splash
  rl = Java::android.widget.RelativeLayout.new($activity)
  rl.setBackgroundColor Java::android.graphics.Color::WHITE
  ll = Java::android.widget.LinearLayout.new($activity)
  ll.setOrientation Java::android.widget.LinearLayout::VERTICAL

  tv = Java::android.widget.TextView.new($activity)
  tv.setTextColor Java::android.graphics.Color::BLACK
  tv.setText "Android API Browser"
  tv.setTextSize 24
  ll.addView tv

  iv = Java::android.widget.ImageView.new($activity)
  iv.setImageResource(JavaUtilities.get_proxy_class("#{$activity.java_class.package.name}.R$drawable")::splash)
  ll.addView iv

  tv = Java::android.widget.TextView.new($activity)
  tv.setTextColor Java::android.graphics.Color::BLACK
  tv.setText "Loading..."
  tv.setTextSize 18
  tv.setGravity Java::android.view.Gravity::CENTER_HORIZONTAL
  ll.addView tv
  tv.getLayoutParams.width = Java::android.view.ViewGroup::LayoutParams::FILL_PARENT

  rl.addView ll
  ll.getLayoutParams.addRule(Java::android.widget.RelativeLayout::CENTER_IN_PARENT)

  $activity.setContentView rl
  $activity.instance_eval{@initialized = true} 
end

if $activity.class.name != "Java::OrgRubotoIrb::IRB"
  show_splash if $package_name.nil?
  $activity.instance_eval{@initialized = true} 

  Java::org.rubyandroid.apibrowser::RubotoRunnable.class_eval do
    def handle_run &block
      setCallbackProc(Java::org.rubyandroid.apibrowser::RubotoRunnable::CB_RUN, block)
      self
    end
  end

  handler = Java::android.os.Handler.new()

  Thread.new do
    startup
    handler.post(Java::org.rubyandroid.apibrowser::RubotoRunnable.new.handle_run{desktop;$activity.finish})
  end
else
  startup
  desktop
end
