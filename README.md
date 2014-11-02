# GenderizeIoRb

Start by adding it to your Gemfile and bundle it:
```ruby
gem 'genderize_io_rb'
```

Now check a name like this:
```ruby
gir = GenderizeIoRb.new
res = gir.info_for_name("kasper")
puts "Name: #{res.name}"
puts "Gender: #{res.gender}"
```

It is also possible to look multiple names up:
```ruby
GenderizeIoRb.new do |gir|
  gir.info_for_names(["kasper", "christina"]).each do |result|
    puts "Name: #{result.name}"
    puts "Gender: #{result.gender}"
  end
end
```

You can attach a database-cache through a Baza::Db if Genderize is a bit slow:
```ruby
# SQLite3 database will automatically be created with table and everything. If an existing db is given, the table will automatically be created within it.
Baza::Db.new(:type => "sqlite3", :path => path) do |db|
  GenderizeIoRb.new(:cache_db => db) do |gir|
    # First request will be done through a HTTP request:
    first_result = gir.info_for_name("kasper")
    puts "Through HTTP?: #{first_result.from_http_request?}"
    
    # Second result will be done by a
    second_result = gir.info_for_name("kasper")
    puts "Through DB cache? #{second_result.from_cache_db?}"
  end
end
```

If you need the connections to be kept open:
```ruby
db = Baza::Db.new(:type => "sqlite3", :path => path)
gir = GenderizeIoRb.new(:cache_db => db)
```

# Contributing to genderize_io_rb
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

# Copyright

Copyright (c) 2013 Kasper Johansen. See LICENSE.txt for
further details.

