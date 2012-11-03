# -*- coding: utf-8 -*-
#
# @author ongaeshi
# @date   2012/11/03
#
# @brief rroonga for Windowsでエラーが起きるのを再現
#
# Install:
#
#  0. Install NougakuDo 1.3.4
#    http://www.artonx.org/data/nougakudo/index.html
#
#  1. checkout or download script
#    $ git clone git://github.com/ongaeshi/rroonga-windows-test.git
#
#  2. Install archive-zip gem
#    $ gem install archive-zip
#
#  3. 1st exec (Success)
#    $ cd rroonga-windows-test
#    $ ruby main.rb
#    --- download file ---
#    --- setup database ---
#    --- add record ---
#    --- access test ---
#
#  4. 2nd exec (Error on Windows)
#    $ ruby main.rb
#    .
#    .
#    Z:/Documents/rroonga-windows-test/download/ruby-1.9.2-p290-2/ruby-1.9.2-p290/test/ruby/test_transcode.rb
#    C:/Users/ongaeshi/AppData/Roaming/NOUGAK~1/lib/ruby/gems/1.9.1/gems/rroonga-2.0.6/lib/groonga/record.rb:329:in `[]': unknown error: syscall error 'CreateFile' (unknown error): #<Groonga::VariableSizeColumn id: <260>, name: <documents.content>, path: <database/test.db.0000104>, domain: <documents>, range: <Text>, flags: <>> (Groonga::UnknownError)
#    C:\Users\arton\Documents\projects\groonga-2.0.7\lib\io.c:1636: grn_open()
#            from C:/Users/ongaeshi/AppData/Roaming/NOUGAK~1/lib/ruby/gems/1.9.1/gems/rroonga-2.0.6/lib/groonga/record.rb:329:in `method_missing'
#            from test-04-download.rb:174:in `block in access_test'
#            from test-04-download.rb:171:in `each'
#            from test-04-download.rb:171:in `access_test'
#            from test-04-download.rb:199:in `<main>'
# 

require 'rubygems'
require 'groonga'
require 'fileutils'
require 'kconv'
require 'find'
require 'open-uri'
require 'archive/zip'

DB_DIR       = "database"
DB_PATH      = File.join(DB_DIR, "test.db")
DOWNLOAD_DIR = 'download'

def zip_extract(filename, dst_dir)
  raise ZipfileNotFound unless File.exist?(filename)
  
  root_list = root_entrylist(filename)
  
  if (root_list.size == 1)
    # そのまま展開
    Archive::Zip.extract filename, dst_dir
    return root_list[0].gsub("/", "")
  else
    # ディレクトリを作ってその先で展開
    dir = File.basename(filename).sub(/#{File.extname(filename)}$/, "")
    FileUtils.mkdir_p File.join(dst_dir, dir)
    Archive::Zip.extract filename, File.join(dst_dir, dir)
    return dir
  end
end

def root_entrylist(filename)
  list = []
  
  Archive::Zip.open(filename) do |archive|
    archive.each do |entry|
      list << entry.zip_path if entry.zip_path.split('/').size == 1
    end
  end

  list
end

def download_file
  unless File.exist?(DOWNLOAD_DIR)
    # create dir
    FileUtils.mkdir_p DOWNLOAD_DIR

    # download ruby-1.9.2-p290.zip
    open('http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-1.9.2-p290.zip') do |src|
      open('download/ruby-1.9.2-p290.zip', "wb") do |dst|
        dst.write(src.read)
      end
    end

    # extract
    zip_extract('download/ruby-1.9.2-p290.zip', 'download/ruby-1.9.2-p290-1')
    zip_extract('download/ruby-1.9.2-p290.zip', 'download/ruby-1.9.2-p290-2')
  end
end

def init_db
  FileUtils.mkdir_p DB_DIR
  Groonga::Context.default_options = {:encoding => :utf8} 
  Groonga::Database.create(:path => DB_PATH)
end

def open_db
  Groonga::Database.open(DB_PATH)
end

def define_schema
  Groonga::Schema.define do |schema|
    schema.create_table("documents", :type => :hash) do |table|
      table.string("path")
      table.string("package")
      table.string("restpath")
      table.text("content")
      table.time("timestamp")
      table.text("suffix")
    end

    schema.create_table("terms",
                        :type => :patricia_trie,
                        :key_normalize => true,
                        :default_tokenizer => "TokenBigramSplitSymbolAlphaDigit") do |table|
      table.index("documents.path", :with_position => true)
      table.index("documents.package", :with_position => true)
      table.index("documents.restpath", :with_position => true)
      table.index("documents.content", :with_position => true)
      table.index("documents.suffix", :with_position => true)
    end
  end
end

def load_content(filename)
  str = File.read(filename)
  begin
    Kconv.kconv(str, Kconv::UTF8)
  rescue ArgumentError
    Util.warning_alert($stdout, "skip kconv. file size too big (or negative string size) : #{filename}.")
    str
  end
end

def add_record(table, filename)
  filename = File.expand_path(filename) # 絶対パスに変換
  path = filename
  package = File.dirname(path)
  restpath = File.basename(path)
  suffix = File.extname(path).sub('.', "")
  timestamp = File.mtime(filename) # OSへの問い合わせは変換前のファイル名で
  # p [filename, path, package, restpath, suffix, timestamp]

  record = table[path]

  unless record
    # 新規追加
    table.add(path, 
               :path => path,
               :package => package,
               :restpath => restpath,
               :content => load_content(filename),
               :timestamp => timestamp,
               :suffix => suffix)
    return :newfile
  else
    if (record.timestamp < timestamp)
      # 更新
      record.package   = package
      record.restpath = restpath
      record.content   = load_content(filename)
      record.timestamp = timestamp
      record.suffix    = suffix
      return :update
    else
      # タイムスタンプ比較により更新無し
      return nil
    end
  end
end

def add_dir(table, dir, counter)
  Find.find(dir) do |f|
    if FileTest.file?(f)
      add_record(table, f)
      counter += 1
      puts counter if counter % 100 == 0
    end
  end
  counter
end

def add_packages
  table = Groonga["documents"]
  counter = 0
  counter = add_dir(table, 'download/ruby-1.9.2-p290-1', counter)
  counter = add_dir(table, 'download/ruby-1.9.2-p290-2', counter)
end

def access_test
  table = Groonga["documents"]

  # contentメンバにアクセスするとエラーが起きる
  table.each do |record|
    path = record.path
    puts path
    content = record.content
  end

  # これでもエラー
  # record = table["Z:/Documents/rroonga-windows-test/download/ruby-1.9.2-p290-2/test/ruby/test_transcode.rb"]
  # p record.content
end

if __FILE__ == $0
  puts '--- download file ---'
  download_file

  puts '--- setup database ---'
  unless File.exist?(DB_DIR)
    # FileUtils.rm_rf DB_DIR
    init_db
    define_schema

    puts '--- add record ---'
    add_packages
  else
    open_db
  end

  puts '--- access test ---'
  access_test
end
