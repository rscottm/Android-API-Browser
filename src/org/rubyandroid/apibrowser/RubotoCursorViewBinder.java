package org.rubyandroid.apibrowser;

import org.jruby.Ruby;
import org.jruby.javasupport.util.RuntimeHelpers;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.javasupport.JavaUtil;
import org.jruby.exceptions.RaiseException;
import org.ruboto.Script;

public class RubotoCursorViewBinder implements android.widget.SimpleCursorAdapter.ViewBinder {
  private Ruby __ruby__;

  public static final int CB_SET_VIEW_VALUE = 0;
  private IRubyObject[] callbackProcs = new IRubyObject[1];



  private Ruby getRuby() {
    if (__ruby__ == null) __ruby__ = Script.getRuby();
    return __ruby__;
  }

  public void setCallbackProc(int id, IRubyObject obj) {
    callbackProcs[id] = obj;
  }
	
  public boolean setViewValue(android.view.View view, android.database.Cursor cursor, int columnIndex) {
    if (callbackProcs[CB_SET_VIEW_VALUE] != null) {
      try {
        return (Boolean)RuntimeHelpers.invoke(getRuby().getCurrentContext(), callbackProcs[CB_SET_VIEW_VALUE], "call" , JavaUtil.convertJavaToRuby(getRuby(), view), JavaUtil.convertJavaToRuby(getRuby(), cursor), JavaUtil.convertJavaToRuby(getRuby(), columnIndex)).toJava(boolean.class);
      } catch (RaiseException re) {
        re.printStackTrace();
        return false;
      }
    } else {
      return false;
    }
  }
}
