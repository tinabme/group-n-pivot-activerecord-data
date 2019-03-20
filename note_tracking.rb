class Reports::NoteTracking
	require 'csv'
  
  def initialize(time_since: 1.day.ago)
    @from_time = time_since.beginning_of_day if time_since
    @to_time = Time.now.beginning_of_day
    @report_title = 'Note Log Tracking'.freeze
    @table_headers = [['author'] << (0..23).map{|h| h.to_s + ":00"}].flatten
  end

  def to_csv
    @query_data = query_data
    CSV.generate do |csv|
      csv << @table_headers
      data_array.each do |row|
        csv << @table_headers.collect {|header| row[header]}
      end
    end
  end

  private

  def query_data
    # using find_by_sql to access mysql function for proper grouping
    Note.find_by_sql(["SELECT hour(created_at) created_at, author, count(id) as count FROM notes WHERE approved = 'true' AND created_at >= ? AND created_at < ? GROUP BY author, hour(created_at)", @from_time, @to_time])
  end

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

  # takes [{author:tina, count: 5, created_at: 11}, {author:tina, count: 2, created_at: 12}, (author:sam, count: 3, created_at: 11}]
  # returns {"tina"=>["11:00_5", "12:00_2"], "sam" => ["11:00_5"]}
  def consolidate_pivot_data
    ary = []
    @query_data.map do |row|
      ary << {"author" => row.author,"timecount" => "#{row.created_at}:00_#{row.count}"}
    end
    ary.inject(Hash.new([])) { |h, a| h[a["author"]] += [a["timecount"]]; h }
  end
  
end