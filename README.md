Android API Browser
=============

The Basics
-------

The Android API Browser provides a convenient UI for exploring the Android APIs across versions. The Android Open Source Project publishes an XML specification of the API each time they release a new version. I've taken the specifications for each API available and built a single database for use with this application.

To use this application you will need to download the API database. The database is ~8MB and can be stored on either your internal or external storage. You will be prompted to download the database and notified when updates are available.

### Here's what you can do...

* Browse: Walk through the API beginning with Packages. You should be able to follow obvious paths through the API (e.g., clicking on a return type will take you to the related class). Relevant information has been added where possible (e.g., browsing an interface will show all classes that implement that interface). As you're browsing you will see color coding based on the status on an object (e.g., deprecated, removed, or added after a specific API level). You can set the colors and the API boundary through Settings.

* Search: Allows text searching on the entire API. You can constrain your search by type and/or API level.

* Manage Data: Allows you to download an API database, move the database between internal and external storage, or remove the database from your device.

* API Levels: Shows you statistical information for each API level (totals for objects added, deprecated, or removed). You can also use this interface to constrain your browsing by API level. When you're constraining your browsing you will see some items in gray text. These items do not meet the criteria of your constraint, but they are needed to get you to items that do meet your constraint (e.g., showing you a package that has new classes).

* Settings: As you're browsing you will see color coding based on the status on an object (e.g., deprecated, removed, or added after a specific API level). You can set the colors and the API boundary here.

* Help: You're looking at it.

* About (menu): Some more information on this software.

### Here's what you can see...

- Package
-- Interface 
--- Field
--- Method
-- Class 
--- Field
--- Constructor
--- Method

### Including...

* Package: name, API added

* Interface: name, package, modifiers, API added/deprecated/removed, fields, methods, implemented by (classes), returned by (methods), parameter for (methods)

* Class: name, package, extends, modifiers, API added/deprecated/removed, fields, constructors, methods, returned by (methods), parameter for (methods), raised by (method, if exception)

* Field: name, class/interface, package, type, value, modifiers, API added/deprecated/removed

* Constructor: name, class, package, modifiers, API added/deprecated/removed, parameters, raises

* Method: name, class/interface, package, returns, modifiers, API added/deprecated/removed, parameters, raises

* Bring up the menu on any of these objects and you can select 'Go to web' to pop up a browser window on the http://developer.android.com documentation.

About the Android API Browser
-------

This application was developed in Ruby through the Ruboto project (JRuby on Android). This project also uses two libraries from Mark Murphy (commonsguy): cwac-merge and cwac-sacklist.

Please send feedback or feature requests to [scott@rubyandroid.org](mailto:scott@rubyandroid.org).

* Developer: Scott Moyer; [scott@rubyandroid.org](mailto:scott@rubyandroid.org); [http://rubyandroid.org](http://rubyandroid.org)

* Android Open Source Project: [http://source.android.com](http://source.android.com); [Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0)

* Ruboto Core: [http://github.com/ruboto/ruboto-core](http://github.com/ruboto/ruboto-core); MIT License

* Join the Ruboto Community: [http://groups.google.com/group/ruboto](http://groups.google.com/group/ruboto)

* Source for Mark Murphy's libraries can be found on Github: [cwac-merge](https://github.com/commonsguy/cwac-merge); [cwac-sacklist](https://github.com/commonsguy/cwac-sacklist); [Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0)

* JRuby Project: [http://jruby.org](http://jruby.org); Common Public License version 1.0; GNU General Public License version 2; GNU Lesser General Public License version 2.1

* Icons: [Ahmad Hania](http://portfolio.ahmadhania.com); The Spherical Icon set; Creative Commons (Attribution-NonCommercial-ShareAlike 3.0 Unported)

