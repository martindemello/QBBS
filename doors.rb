require "pty"
require "messagestrings.rb"
D_LIMIT = 1
D_IDLE = 5


def door_do (path,d_type)
  send_init = false
  time = Time.now
  tick = time.min.to_i
  idle = 0
  timeout = 0
  started = false



  begin
    PTY.spawn(path) do |read, w, p|


      w.putc(13.chr) if d_type == "DOS" #we want to put a ENTER in so dosemu won't pause at intro
      exit = false
      while !exit

        while !exit 

          ios = select([read, @socket],nil,nil,0.001) #and !exit


          r, * = ios
          if r != nil then
            if r.include?(read)
              begin
                char = read.getc
                if d_type == "RSTS" and char.chr == ":" and !send_init then
                  puts "char: #{char}"
                  account = "#{RSTS_BASE},#{@users[@c_user].rsts_acc}"
                  sleep(2)
                  w.puts(account)
                  sleep (2)
                  w.puts(@users[@c_user].rsts_pw)
                  send_init = true
                end
                started = true
                idle = 0
              rescue 
                sleep (5)
                puts "boom"
                @who.user(@c_user).where = "Main Menu"
                return
              end
              @socket.write CR.chr if char == LF
              @socket.write(char.chr)
            end

            if r.include?(@socket)
              idle = 0
              char = @socket.getc
              # return if char == nil
              if d_type == DOS then
                w.putc(char.chr) if (char != 3) and (char != 27) #we want to block ctrl-c and esc
              else
                w.putc(char.chr) if (char !=3)
              end
            end
          end
        end
      end
    end 
  rescue 
    # puts "boom2: #{$!}"

    return
  end


end

def writedoorfile(outfile)

  happy = system("rm #{outfile}")
  if happy then
    puts "-Deleted old door file..."
  else
    puts "-Failure to delete old door file"
  end

  begin
    doorfile = File.new(outfile, File::CREAT|File::APPEND|File::RDWR, 0666)
    doorfile.write("#{SYSTEMNAME}\r\n")
    sysop_out = SYSOPNAME.split
    doorfile.write("#{sysop_out[0]}\r\n")
    if sysop_out.length > 1 then 
      doorfile.write("#{sysop_out[1]}\r\n") 
    else
      doorfile.write("\r\n")
    end
    doorfile.write("COM0\r\n")  # always com0, as we are using telnet 
    doorfile.write("0 BAUD,N,8,1\r\n") # See above
    doorfile.write("0\r\n")  #Nobody seems to know what this does
    user_out = @users[@c_user].name.split
    doorfile.puts("#{user_out[0]}\r\n")
    if user_out.length > 1 then
      doorfile.write("#{user_out[1]}\r\n")
    else
      doorfile.write("\r\n")
    end
    doorfile.write("#{@users[@c_user].location}\r\n")
    if @users[@c_user].ansi then 
      doorfile.write("1\r\n")
    else
      doorfile.write("0\r\n")
    end
    doorfile.write("#{@users[@c_user].level}\r\n")  
    doorfile.write("255\r\n")
    doorfile.close
  rescue
    add_log_entry(8,Time.now,"No path for door file %R#{outfile}")
    print "%RCould not write door info file... Please tell sysop."
  end 
end

def showdoor(number)
  if d_total > 0 then 
    door = fetch_door(number)
    print "%R#%W#{number} %G #{door.name}"
    print "%CPath:      %G#{door.path}"
    print "%CType:      %G#{door.d_type}"
    print "%CDrop Path: %G#{door.d_path}"
    print "%CDrop Type: %G#{door.droptype}"
    print "%CLevel:     %G#{door.level}"
    print
  else 
    print "%RNo Doors"
  end
end

def doormaint
  readmenu(
    :initval => 1,
    :range => 1..(d_total),
    :prompt => '"%W#{sdir}Door [%p] (1-#{d_total}): "'
  ) {|sel, dpointer, moved|
    if !sel.integer?
      parameters = Parse.parse(sel)
      sel.gsub!(/[-\d]/,"")
    end

    showdoor(dpointer) if moved

    case sel
    when "/"; showdoor(dpointer)
    when "Q"; dpointer = true
    when "W"; displaywho
    when "PU";page
    when "A"; adddoor
    when "P"; changedoorpath(dpointer)
    when "L"; changedoorlevel(dpointer)
    when "DP"; changedoordroppath(dpointer)
    when "DT"; changedoortype(dpointer)
    when "N"; changedoorname(dpointer)
    when "K"; deletedoor(dpointer)
    when "G"; leave
    when "?"; gfileout ("doormnu")
    end # of case
    p_return = [dpointer,d_total]
  }
end

def adddoor

  name = get_max_length("Enter new Door name: ",40,"Door name")
  name.strip! if name != ""
  path = get_max_length("Enter new door path (script file): ",40,"Door path") 
  path.strip! if path != ""

  if yes("Are you sure (Y,n)? ", false, false,true)
    add_door(name,path)
  else
    print "%RAborted."
  end
  print
end

def changedoorname(dpointer)
  door = fetch_door(dpointer)
  name = get_max_length("Enter new door name: ",40,"Door name") 
  name.strip! if name != ""

  if name !='' then
    door.name = name
    update_door(door)
  else
    print "%RNot Changed."
  end
  print
end

def changedoortype(dpointer)
  door = fetch_door(dpointer)
  temp = get_max_length("Enter new door type (DOS,LINUX,RSTS): ",10,"Door type") 
  temp.strip! if temp != ""
  door.d_type = temp.upcase if temp != nil
  update_door(door)
end



def changedoorpath(dpointer)
  door = fetch_door(dpointer)
  print CHANGEDOORPATHWARNING
  path = get_max_length("Enter new door path (or script): ",40,"Door path")
  if path != "" then
    path.strip!
    door.path = path
  end
  update_door(door)
  print
end

def changedoordroppath(dpointer)
  print CHANGEDOORDROPPATHWARNING
  door = fetch_door(dpointer)
  d_path = get_max_length("Enter new door Drop File path: ",40,"Drop File path")
  if d_path !="" then
    d_path.strip!
    door.d_path = d_path 
  end
  update_door(door)
  print
end

def changedoorlevel(dpointer)

  door = fetch_door(dpointer)
  prompt = "Enter user level required to access door: "
  area.netnum = getnum(prompt, 0, 255) || 0
  update_door(door)
  print
end

def deletedoor(dpointer)
  if dpointer > 0 then
    delete_door(dpointer)
    renumber_doors
    dpointer = d_total if dpointer > d_total
  else
    print NODOORERROR
  end
end

#-------------------Doors Section-------------------

def displaydoors
  i = 0
  if d_total < 1 then
    print "No External Programs."
    return
  end
  print "%GGames Available:"
  for i in 1..(d_total)
    door = fetch_door(i)
    print "   %B#{i}...%G#{door.name}"
  end
  print
end

def find_RSTS_account

  acclist = []
  @users.each {|u| 
    if u.rsts_acc != nil then 
      if u.rsts_acc > 0 then
        acclist.push(u.rsts_acc)
      end
    end}

    puts "acclist.len #{acclist.length}"
    puts "RSTS_MAX #{RSTS_MAX}"
    return 1 if acclist.length == 0 
    return 0 if acclist.length >= RSTS_MAX

    for i in 1..RSTS_MAX
      break if acclist.index(i) == nil
    end 
    return i
end

def irc_do(channel,d_type)
  if d_type == "GD" then 
    existfileout('gdmenu',0,true)
    while true
      prompt = "\r\n%WWhat is your choice? [P, H, I, Q]: "
      getinp(prompt) {|inp|
        happy = inp.upcase
        t = happy.to_i
        case happy
        when "Q";   return
        when "P"; teleconference(channel)
        when "I"; existfileout('gd_intro',0,true)
        when "H"; existfileout('gd_score',0,true)
        when "?";  existfileout('gdmenu',0,true)
        end #of case
      }
    end
  end
end

def rundoor(number)
  puts "number: #{number}"
  door = fetch_door(number)
  puts "door.level: #{door.level}"

  if @c_user.level >= door.level then
    @who.user(@c_user.name).where = door.name
    update_who_t(@c_user.name,door.name)
    case door.droptype 
    when "RBBS"; f_name = RBBSDROPFILE
    end

    node = @who.user(@c_user.name).node
    #puts "node: #{node}"
    dropfile = "#{door.d_path}#{node}/#{f_name}"
    if door.d_type == "RSTS" then

      if @c_user.rsts_acc == 0 or @c_user.rsts_acc == nil then
        print "\r\nFinding a RSTS/E Account for you..."
        account = find_RSTS_account
        if account != 0 then
          @c_user.rsts_acc = account
          @c_user.rsts_pw = RSTS_DEFAULT_PSWD
          update_user(@c_user,get_uid(@c_user.name))
        else
          print "\r\nSorry... out of accounts.  Please tell sysop!"
          add_log_entry(8,Time.now,"{@c_user} Out of RSTS/E Accounts Error.")
        end
      end
    end
    writedoorfile (dropfile) if door.d_type == "DOS"
    if door.d_type =="GD" then
      irc_do(door.path,door.d_type)
    else
      add_log_entry(5,Time.now,"#{@c_user} Ran External program #{door.name}")
      door_do(door.path,door.d_type)
    end
  else
    print "You do not have access."
  end
  @who.user(@c_user.name).where = "Main Menu"
  update_who_t(@c_user.name,"Main Menu")
end

def doors(parameters)
  t = (parameters[0] > 0) ? parameters[0] : 0
  done = false
  if t == 0 then
    displaydoors  if !existfileout('doors',0,true)
    while true
      prompt = "\r\n%WGame #[1-#{d_total}] ? %Y<--^%W to quit: "
      getinp(prompt) {|inp|
        happy = inp.upcase
        t = happy.to_i
        case happy
        when "";   return
        when "CR"; crerror
        when "?";  displaydoors  if !existfileout('doors',0,true)
        else
          rundoor(t) if (t) > 0 and (t) <= d_total
        end #of case
      }
    end
  end
end

