# # rroonga-windows-test 

rroonga for Windowsでエラーが起きるのを再現するスクリプトです。

## Install

(1) Install NougakuDo 1.3.4

```
http://www.artonx.org/data/nougakudo/index.html
```

(2) checkout script

```
$ git clone git://github.com/ongaeshi/rroonga-windows-test.git
```
   
(3) Install archive-zip gem

```
$ gem install archive-zip
```

(3) 1st exec (Success)

```
$ cd rroonga-windows-test
$ ruby main.rb
--- download file ---
--- setup database ---
--- add record ---
--- access test ---
```

(4) 2nd exec (Error on Windows)

```
$ ruby main.rb
.
.
Z:/Documents/rroonga-windows-test/download/ruby-1.9.2-p290-2/ruby-1.9.2-p290/test/ruby/test_transcode.rb
C:/Users/ongaeshi/AppData/Roaming/NOUGAK~1/lib/ruby/gems/1.9.1/gems/rroonga-2.0.6/lib/groonga/record.rb:329:in `[]': unknown error: syscall error 'CreateFile' (unknown error): #<Groonga::VariableSizeColumn id: <260>, name: <documents.content>, path: <database/test.db.0000104>, domain: <documents>, range: <Text>, flags: <>> (Groonga::UnknownError)
C:\Users\arton\Documents\projects\groonga-2.0.7\lib\io.c:1636: grn_open()
        from C:/Users/ongaeshi/AppData/Roaming/NOUGAK~1/lib/ruby/gems/1.9.1/gems/rroonga-2.0.6/lib/groonga/record.rb:329:in `method_missing'
        from test-04-download.rb:174:in `block in access_test'
        from test-04-download.rb:171:in `each'
        from test-04-download.rb:171:in `access_test'
        from test-04-download.rb:199:in `<main>'
```


