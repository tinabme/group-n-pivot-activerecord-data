# Group and Pivot rails activerecord data results

When it comes to grouping and pivoting data, excel is a handy tool.

But when your customer asks for a nightly report that is contains data that needs to be grouped and pivoted for proper display, you need to be able to do so programmatically.

I was recently faced with that very task.

A request was submitted to provide a nightly report of who added notes, and how many, by the hour.

The request was to display one line per author, with headers for the author and each hour, and the number of entries listed by the author in each hour.

### Partial report example

| Author | 0:00 | 1:00 | 2:00 | 3:00 | 4:00 | 5:00 | 6:00 | 7:00 | 8:00 … |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Tina |   |   |   |   | 1 | 2 | 2 |   | 4 |
| Sam |   |   | 2 | 1 |   |   | 1 |   |   |


### The data is stored in a table one entry per note:
| id | author | note | approved | created\_at |
| --- | --- | --- | --- | --- |
| 1 | Sam | a note… | 1 | datetime |
| 2 | Sam | a note… | 1 | datetime |
| 3 | Tina | a note… | 0 | datetime |
| 4 | Sam | a note… | 1 | datetime |
| 5 | Tina | a note… | 1 | datetime |

To Accomplish this task we need:
1. The expected report layout, so we start by initializing the report headers
2. A count of note entries by author, by the hour in time that they were created
3. The counted data grouped and pivoted to fit the report layout requirement

> Three steps, seems simple enough

### Initiate the time frame, title, and report header names

```ruby
  def initialize(time_since: 1.day.ago)
    @from_time = time_since.beginning_of_day if time_since
    @to_time = Time.now.beginning_of_day
    @report_title = 'Note Log Tracking'.freeze
    # table headers are author and hours 0:00 to 23:00
    @table_headers = [['author'] << (0..23).map{|h| h.to_s + ":00"}].flatten
  end
```

### Query the data 
Look at that, using mysql functions to grab the count per hour, half the work is done for me 
``` ruby
  def query_data
    # using find_by_sql to access mysql functions for proper grouping
    @sql = "SELECT hour(created_at) created_at, author, count(id) as count 
    FROM notes WHERE approved = 'true' AND created_at >= ? 
    AND created_at < ? GROUP BY author, hour(created_at)"
    Note.find_by_sql([@sql, @from_time, @to_time])
  end
```
### returns
```sh
 [{author:sam, count: 2, created_at: 2}, 
   {author:sam, count: 1, created_at: 3}, 
   {author:tina, count: 1, created_at: 4},
   {author:tina, count: 2, created_at: 5},
   {author:tina, count: 2, created_at: 6},
   {author:tina, count: 1, created_at: 6}, ...]
```

### Group and Pivot
This is where the magic happens:
Run the query results through a function that creates a hash key from the author, and munges the created_at hour and count into an array for the hash value.

``` ruby
 # returns {"tina"=>["11:00_5", "12:00_2"], "sam" => ["11:00_5"]}
  def consolidate_pivot_data
    ary = []
    @query_data.map do |row|
      ary << {"author" => row.author,"timecount" => "#{row.created_at}:00_#{row.count}"}
    end
    ary.inject(Hash.new([])) { |h, a| h[a["author"]] += [a["timecount"]]; h }
  end
```
Roll the consolidated and pivoted data back into and array or hashs, splitting a key/value pair from the combined created_at & count, to be easily dropped into the csv fields by header.
```ruby
  def data_array
    data_ary = []
    consolidate_pivot_data.each do |k,v|
      data_row = {}
      data_row["author"] = k
      v.each do |c|
        data_row["#{c.split('_').first}"] = "#{c.split('_').last}"
      end
      data_ary << data_row
    end
    data_ary
  end
```
### Push the preformated data to cvs
```ruby
  def to_csv
    CSV.generate do |csv|
      csv << @table_headers
      data_array.each do |row|
        csv << @table_headers.collect {|header| row[header]}
      end
    end
  end
```

### See it in action
Review the simple example class, to see how it all fits together.# group-n-pivot-activerecord-data
A simple example of a way to group and pivot rails activerecord data results, for a report.
