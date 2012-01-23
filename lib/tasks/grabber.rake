# encoding: utf-8
namespace :grab do

  # Directory to store the raw html files fetched from http://www.vybory.izbirkom.ru
  inp_data_dir = "./raw_input"

  # Executes block. Measures and prints the execution time in seconds
  def execute_and_measure_time
    start_tm = Time.now
    yield
    end_tm = Time.now

    print "Start time: "
    print_tm(start_tm)

    print "End time: "
    print_tm(end_tm)

    print "Total time spent: ", (end_tm - start_tm).to_f, " seconds\n"
  end

  # Prints time in the format DD/MM/YY HH:MM:SS
  def print_tm(tm)
      print tm.strftime("%d/%m/%y %H:%M:%S"), "; "
  end

  # Checks if the file fname exits. If it doesn't fetches the data from URL url and saves it to the file named fname
  # Returns the contents of the file
  def fetch_and_save(fname, url)
    begin
      # Fetching only if the file does not exist or is empty
      if( (!File.exists?(fname)) || (File.zero?(fname)) )
        print "Fetching ", fname, "\n"
        raw_html = url_normalize(url)
        File.open(fname, 'w') do |f|
          f.syswrite(raw_html)
          f.close
        end
      else
        raw_html = File.read(fname)
      end
    rescue => e
      print "('", fname, "') Was not able to get URL: \'", url, "\': ", e.message, "\n"
    end

    return raw_html
  end

  # Fetches and stores all the needed data from the commission
  # Recursively calls itself to handle sub-commissions
  def fetch_commissions(dir, url)
    if(!File.exists?(dir))
      mkdir(dir)
    end

    # Storing commission's URL in the file system
    url_fname = dir + '/url'
    if( (!File.exists?(url_fname)) || (File.zero?(url_fname)) )
      File.open(url_fname, 'w') do |f_url|
        f_url.puts(url)
        f_url.close
      end
    end

    # Storing commission's page in the file system
    raw_html = fetch_and_save(dir + '/about.html', url)
    agent = Nokogiri::HTML(raw_html, nil, 'Windows-1251')

    # Search for subcommissions to fetch the data from all of them
    commissions = {}
    agent.search("select option").each do |option|
      if option['value']
        name = option.content.gsub(/^\d+ /,'')
        commissions[name.strip] = option['value']
      end
    end
    # Looking for regional commission site
    agent.search("a").each do |href|
      if (href.content.to_str == "сайт избирательной комиссии субъекта Российской Федерации")
      # Commission name = "Regional"
      commissions['Regional'] = href['href']
      end
    end

    # Does the commission page contain a link to the election's results?
    agent.search("a").search("a").each do |href|
      if (href.content.to_str == "Результаты выборов")
        # Fetch the votes page and store in the commission's folder
        fetch_and_save(dir + '/votes.html', href['href'])
      end
    end

    # Starting Parallel fetch for subcommissions
    Parallel.each(commissions, :in_threads => 8){ |name, url| fetch_commissions(dir + '/' + name, url) }
  end

  desc "Clean up"
  task :clean_up => :environment  do
    print "*** Чистим все ***\n"
    Election.destroy_all
    Commission.destroy_all
  end

  desc "Clean raw html data directory"
  task :clean_raw_html => :environment do
    print "*** Cleaning '", inp_data_dir, "' directory\n"

    execute_and_measure_time { rm_rf(inp_data_dir) }
  end

  desc "Fetch raw HTML data from http://www.vybory.izbirkom.ru and put it on disk"
  task :fetch_raw_html => :environment do
    print "*** Fetching the data from http://www.vybory.izbirkom.ru to the directory '", inp_data_dir, "' ***\n"
    require 'net/http'
    require 'nokogiri'
    require 'open-uri'

    execute_and_measure_time {
      fetch_commissions(inp_data_dir, "http://www.vybory.izbirkom.ru/region/izbirkom?action=show&root_a=null&vrn=100100028713299&region=0&global=true&type=0&sub_region=0&prver=0&pronetvd=null")
    }
  end

  desc "Parse raw HTML data stored in the file system and put them to the database"
  task :import_to_db_from_raw => :environment do
    require 'net/http'
    require 'nokogiri'
    require 'open-uri'
    require 'pp'


    print "*** Importing the data from the directory'", inp_data_dir, "' to the database ***\n"

    execute_and_measure_time {
      # The code below is almost copy of grab:get task. Temporary solution. Not very effective in terms of execution time

      Rake::Task['grab:clean_up'].invoke
      @election = Election.create!(:name => "Выборы депутатов Государственной Думы Федерального Собрания Российской Федерации шестого созыва", :url => "http://www.vybory.izbirkom.ru/region/izbirkom?action=show&root_a=null&vrn=100100028713299&region=0&global=true&type=0&sub_region=0&prver=0&pronetvd=null")

      #Хеш имен и их индексов в таблицх голосований (меняется на каждых выборах)
      voting_names = {"poll"=>1,"received_by_commission"=>2,"voted_early"=>3,"voted_in"=>4,"voted_out"=>5,"canceled_ballots"=>6,"mobile_ballots"=>7,"stationary_ballots"=>8,"invalid_ballots"=>9,"valid_ballots"=>10,"absentee_ballots_all"=>11,"absentee_ballots_given"=>12,"absentee_ballots_voted"=>13,"unused_absentee_ballots"=>14,"absentee_territorial"=>15,"lost_absentee_ballots"=>16,"ballots_not_taken"=>18,"sr"=>19,"ldpr"=>20,"pr"=>21,"kprf"=>22,"yabloko"=>23,"er"=>24,"pd"=>25}
      voting_labels = {"poll" => "Число избирательных бюллетеней, полученных участковой избирательной комиссией","received_by_commission" => "Число избирательных бюллетеней, выданных избирателям, проголосовавшим досрочно","voted_early" => "Число избирательных бюллетеней, выданных избирателям в помещении для голосования","voted_in" => "Число избирательных бюллетеней, выданных избирателям вне помещения для голосования","voted_out" => "Число погашенных избирательных бюллетеней","canceled_ballots" => "Число избирательных бюллетеней в переносных ящиках для голосования","mobile_ballots" => "Число избирательных бюллетеней в стационарных ящиках для голосования","stationary_ballots" => "Число недействительных избирательных бюллетеней","invalid_ballots" => "Число действительных избирательных бюллетеней","valid_ballots" => "Число открепительных удостоверений, полученных участковой избирательной комиссией","absentee_ballots_all" => "Число открепительных удостоверений, выданных избирателям на избирательном участке","absentee_ballots_given" => "Число избирателей, проголосовавших по открепительным удостоверениям на избирательном участке","absentee_ballots_voted" => "Число погашенных неиспользованных открепительных удостоверений","unused_absentee_ballots" => "Число открепительных удостоверений, выданных избирателям территориальной избирательной комиссией","absentee_territorial" => "Число утраченных открепительных удостоверений","lost_absentee_ballots" => "Число утраченных избирательных бюллетеней","ballots_not_taken" => "Число избирательных бюллетеней, не учтенных при получении","sr" => "Политическая партия СПРАВЕДЛИВАЯ РОССИЯ","ldpr" => "Политическая партия Либерально-демократическая партия России","pr" => "Политическая партия ПАТРИОТЫ РОССИИ","kprf" => "Политическая партия Коммунистическая партия Российской Федерации","yabloko" => "Политическая партия Российская объединенная демократическая партия ЯБЛОКО","er" => "Всероссийская политическая партия ЕДИНАЯ РОССИЯ","pd" => "Всероссийская политическая партия ПРАВОЕ ДЕЛО"}

    @voting_dictionaries = Hash.new

     voting_labels.each do |key,value|
       voting_dictionary = @election.voting_dictionaries.create(:en_name => key, :name => value, :source_identifier => voting_names[key])
       @voting_dictionaries[voting_names[key]] = voting_dictionary.id
     end

     # Getting commission's page from the file system. No fetching/saving happens. As all the data is already in filesystem's cache
     raw_html = fetch_and_save(inp_data_dir + '/about.html', "http://www.vybory.izbirkom.ru/region/izbirkom?action=show&root_a=null&vrn=100100028713299&region=0&global=true&type=0&sub_region=0&prver=0&pronetvd=null")
     agent = Nokogiri::HTML(raw_html, nil, 'Windows-1251')

     agent.search("select option").each_with_index do |option,index|
       if (option['value'])
        name = option.content.gsub(/^\d+ /,'')
        commission = Commission.create!(:name => name.strip, :url => option['value'], :election_id => @election.id)
        print "Taken: #{option.content}\n"
       end
     end

     Parallel.each(Commission.all, :in_threads => 15){|commission| get_children_from_raw_html(inp_data_dir + '/' + commission.name, commission, commission.url)}
   }
  end

  # The function below is almost copy of get_children_from_raw_html. Temporary solution. Not very effective in terms of execution time
  def get_children_from_raw_html(dir, parent_commission, url)
    begin
      # Getting commission's page from the file system. No fetching/saving happens. As all the data is already in filesystem's cache
      agent = Nokogiri::HTML(fetch_and_save(dir + '/about.html', url), nil, 'Windows-1251')

      agent.search("a").search("a").each do |href|
        if (href.content.to_str == "Результаты выборов")
          parent_commission.voting_table_url = href['href']
          parent_commission.save
        end
      end

      agent.search("select option").each do |option|
        if option['value']
          name = option.content.gsub(/^\d+ /,'')
          child = parent_commission.children.create(:name => name.strip, :url => option['value'], :is_uik => name.include?("УИК"), :election_id => @election.id)
          if name.include?("УИК")
            #ставим флаг, что комиссия содержит уики
            parent_commission.update_attributes(:uik_holder => true)
          else
            print "Taken: #{name}\n"
          end
          get_children_from_raw_html(dir + '/' + child.name, child, option['value'])
        end
      end
      agent.search("a").each do |href|
         if (href.content.to_str == "сайт избирательной комиссии субъекта Российской Федерации")
            get_children_from_raw_html(dir + '/Regional', parent_commission, href['href'])
        end
      end
      voting_table_from_raw_html(dir, parent_commission)
    rescue Exception => ex
      print "Error: #{ex}\n"
    end
  end

  def voting_table_from_raw_html(dir, commission)
    if commission.voting_table_url
      begin
        # Getting commission's votes from the file system. No fetching/saving happens. As all the data is already in filesystem's cache
        agent_inner = Nokogiri::HTML(fetch_and_save(dir + '/votes.html', commission.voting_table_url), nil, 'Windows-1251')
        voting_table = Hash.new
        rows = agent_inner.xpath('//table/tr')
        details = rows.collect do |row|
          tds = row.xpath('td')
          if (tds.first.text.to_i > 0)
            if @voting_dictionaries.has_key?(tds.first.text.to_i)
              # добавляем голоса в коммисию
              commission.votings.build(:votes => tds.last.first_element_child().text.to_i, :voting_dictionary_id => @voting_dictionaries[tds.first.text.to_i])
            end
          end
        end
        commission.votes_taken = true
        commission.save
       rescue Exception => ex
          print "Error: #{ex}\n"
       end
    end
   end

  desc "Get ungetted"
  task :get_lost => :environment do

    require 'net/http'
    require 'nokogiri'
    require 'open-uri'
    require 'pp'

    @voting_dictionaries = Hash.new
    Election.first.voting_dictionaries.each do |dict|
      @voting_dictionaries[dict[:source_identifier]] = dict[:id]
    end    
    # Parallel.each(Commission.where(:is_uik => true), :in_threads => 20){|commission| voting_table(commission) if commission.votings.empty? }    
    Commission.where(:is_uik => true).each do |commission|
      if commission.votings.empty?
        print "#{commission.name}\n"
        print "#{commission.url}\n"
        # voting_table(commission) 
      end
    end
  end

  desc "Grab all the commissions out there from 4-dec elections"
  task :get => :environment do        
    Rake::Task['grab:clean_up'].invoke
    
    beginning_time = Time.now
    
    require 'net/http'
    require 'nokogiri'
    require 'open-uri'
    require 'pp'

        
    @election = Election.create!(:name => "Выборы депутатов Государственной Думы Федерального Собрания Российской Федерации шестого созыва", :url => "http://www.vybory.izbirkom.ru/region/izbirkom?action=show&root_a=null&vrn=100100028713299&region=0&global=true&type=0&sub_region=0&prver=0&pronetvd=null")

    #Хеш имен и их индексов в таблицх голосований (меняется на каждых выборах)
    voting_names = {"poll"=>1,"received_by_commission"=>2,"voted_early"=>3,"voted_in"=>4,"voted_out"=>5,"canceled_ballots"=>6,"mobile_ballots"=>7,"stationary_ballots"=>8,"invalid_ballots"=>9,"valid_ballots"=>10,"absentee_ballots_all"=>11,"absentee_ballots_given"=>12,"absentee_ballots_voted"=>13,"unused_absentee_ballots"=>14,"absentee_territorial"=>15,"lost_absentee_ballots"=>16,"ballots_not_taken"=>18,"sr"=>19,"ldpr"=>20,"pr"=>21,"kprf"=>22,"yabloko"=>23,"er"=>24,"pd"=>25}
    voting_labels = {"poll" => "Число избирательных бюллетеней, полученных участковой избирательной комиссией","received_by_commission" => "Число избирательных бюллетеней, выданных избирателям, проголосовавшим досрочно","voted_early" => "Число избирательных бюллетеней, выданных избирателям в помещении для голосования","voted_in" => "Число избирательных бюллетеней, выданных избирателям вне помещения для голосования","voted_out" => "Число погашенных избирательных бюллетеней","canceled_ballots" => "Число избирательных бюллетеней в переносных ящиках для голосования","mobile_ballots" => "Число избирательных бюллетеней в стационарных ящиках для голосования","stationary_ballots" => "Число недействительных избирательных бюллетеней","invalid_ballots" => "Число действительных избирательных бюллетеней","valid_ballots" => "Число открепительных удостоверений, полученных участковой избирательной комиссией","absentee_ballots_all" => "Число открепительных удостоверений, выданных избирателям на избирательном участке","absentee_ballots_given" => "Число избирателей, проголосовавших по открепительным удостоверениям на избирательном участке","absentee_ballots_voted" => "Число погашенных неиспользованных открепительных удостоверений","unused_absentee_ballots" => "Число открепительных удостоверений, выданных избирателям территориальной избирательной комиссией","absentee_territorial" => "Число утраченных открепительных удостоверений","lost_absentee_ballots" => "Число утраченных избирательных бюллетеней","ballots_not_taken" => "Число избирательных бюллетеней, не учтенных при получении","sr" => "Политическая партия СПРАВЕДЛИВАЯ РОССИЯ","ldpr" => "Политическая партия Либерально-демократическая партия России","pr" => "Политическая партия ПАТРИОТЫ РОССИИ","kprf" => "Политическая партия Коммунистическая партия Российской Федерации","yabloko" => "Политическая партия Российская объединенная демократическая партия ЯБЛОКО","er" => "Всероссийская политическая партия ЕДИНАЯ РОССИЯ","pd" => "Всероссийская политическая партия ПРАВОЕ ДЕЛО"}
    
    @voting_dictionaries = Hash.new

    voting_labels.each do |key,value|
      voting_dictionary = @election.voting_dictionaries.create(:en_name => key, :name => value, :source_identifier => voting_names[key])  
      @voting_dictionaries[voting_names[key]] = voting_dictionary.id
    end
    

    agent = Nokogiri::HTML(open("http://www.vybory.izbirkom.ru/region/izbirkom?action=show&root_a=null&vrn=100100028713299&region=0&global=true&type=0&sub_region=0&prver=0&pronetvd=null"), nil, 'Windows-1251')
    agent.search("select option").each_with_index do |option,index|      
      if (option['value'])      
        commission = Commission.create!(:name => option.content,:url => option['value'], :election_id => @election.id)        
        print "Taken: #{option.content}\n"
        #get_children(commission,commission.url)        
      end
    end
    # commission = Commission.first
    # get_children(commission,commission.url)        


    Parallel.each(Commission.all, :in_threads => 15){|commission| get_children(commission,commission.url)}    
    
    # print "\n-- data taken, taken votes --\n"
            
    # Parallel.each(@election.commissions.where(:is_uik => true), :in_threads => 10){|commission| voting_table(commission)}

    # Parallel.each(Commission.all, :in_threads => /20){|commission| voting_table(commission)}    
  end  


  def url_normalize(url)
    host = url.match(".+\:\/\/([^\/]+)")[1]
    path = url.partition(host)[2] || "/"
    begin
      return Net::HTTP.get(host, path)
    rescue Timeout::Error
      print "timeout-error - sleeping 5 seconds"
      sleep 5
      url_normalize(url)
    end
  end

  def get_children(parent_commission,url)
    #идем по урл, забираем html селект или переходим на сайт субъекта
    begin
      agent = Nokogiri::HTML(url_normalize(url), nil, 'Windows-1251')
      
      agent.search("a").search("a").each do |href|
        if (href.content.to_str == "Результаты выборов")
          parent_commission.voting_table_url = href['href']    
          parent_commission.save          
        end
      end

      agent.search("select option").each do |option|
        if option['value']
          name = option.content.gsub(/^\d+ /,'')
          child = parent_commission.children.create(:name => name, :url => option['value'], :is_uik => name.include?("УИК"), :election_id => @election.id)
                              
          if name.include?("УИК")
            #ставим флаг, что коммиссия содержит уики
            parent_commission.update_attributes(:uik_holder => true)                                     
          else
            print "Taken: #{name}\n"
          end                    
          get_children(child,option['value'])
        end
      end
      agent.search("a").each do |href|
         if (href.content.to_str == "сайт избирательной комиссии субъекта Российской Федерации")
            get_children(parent_commission,href['href'])
        end
      end      
      voting_table(parent_commission)
    rescue Exception => ex
      print "Error: #{ex}\n"
    end             
    
  end
  
  def voting_table(commission)    
    if commission.voting_table_url
      begin            
        agent_inner = Nokogiri::HTML(url_normalize(commission.voting_table_url), nil, 'Windows-1251')          
        voting_table = Hash.new
        rows = agent_inner.xpath('//table/tr')
        details = rows.collect do |row|                            
          tds = row.xpath('td')
          if (tds.first.text.to_i > 0)   
            if @voting_dictionaries.has_key?(tds.first.text.to_i) 
              # добавляем голоса в коммисию
              
              commission.votings.build(:votes => tds.last.first_element_child().text.to_i, :voting_dictionary_id => @voting_dictionaries[tds.first.text.to_i])                             
              
            end 
          end              
        end        
        commission.votes_taken = true            
        commission.save                    
              
       rescue Exception => ex
          print "Error: #{ex}\n"
       end  
    end
  end

end
