TABLE_LIST = ["areas","bulletins","doors","other","system","groups","users","who","who_t","log","subsys","wall"]

def current_date
  return Time.now.strftime("%Y-%m-%d")
end

def open_database

  # begin
  puts "-DB: Opening Database Connection"
  @db = PGconn.connect(DATAIP,5432,nil,nil,DATABASE,nil,nil)
  # rescue
  #  puts "-FATAL: Database Connection Failed.  Halted."
  # end
end

def single_result(res)
  result = nil
  if res.ntuples > 0 then
    result = res.getvalue(0,0)
  end
  return result
end

def result_as_array(res)
  ary=[]
  tuples = res.ntuples; tuples -=1
  for i in 0..tuples  do
    ary << []
    fields = res.nfields;fields -=1
    for j in 0..fields  do
      ary[i] << res.getvalue(i,j)
    end
  end
  return ary
end

def make_table_list

  result = []

  res = @db.exec("SELECT relname FROM pg_class \
                       WHERE relname NOT LIKE 'pg_%'\
                       AND relname NOT LIKE 'sql%' \
                       AND relkind = 'r'")



                       result = result_as_array(res)
                       return result
end

def check_tables
  t_list = make_table_list.flatten

  t_list = ["none"] if t_list.nil?

  TABLE_LIST.each {|x|
    create_table(x) if t_list.index(x).nil?
  }
end

def db_num(arr)
  result = arr
  return result[0].to_i
end

def db_true(str)

  result = false
  result = true if str == "t"
  return result
  endhash << row[0].to_i

  def hash_table(table)

    hash = []

    res = @db.exec("SELECT id FROM #{table} ORDER BY id") 
    hash = result_as_array(res).flatten
  end

  hash.each {|x| puts "hash #{x}"}

  return hash
end

def create_table(table)

  case table
  when "areas"
    create_area_table
  when "bulletins"
    create_bulletin_table
  when "doors"
    create_door_table
  when "other"
    create_other_table
  when "system"
    create_system_table
  when "groups"
    create_group_table
  when "users"
    create_user_table
  when "who"
    create_who_table
  when "who_t"
    create_who_t_table
  when "log"
    create_log_table
  when "subsys"
    create_subsystem_table
  when "wall"
    create_wall_table
  end
end

def set_up_database
  open_database
  make_table_list
  check_tables
  @db.close
end


