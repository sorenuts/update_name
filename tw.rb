require 'twitter'

CONSUMER_KEY = ENV['CON_KEY']
CONSUMER_SECRET = ENV['CON_SEC']
OAUTH_TOKEN = ENV['ACCS_TOKEN']
OAUTH_TOKEN_SECRET = ENV['ACCS_SEC']

AI_OAUTH_TOKEN = ENV['AI_ACCS_TOKEN']
AI_OAUTH_TOKEN_SECRET = ENV['AI_ACCS_SEC']
#文字数制限#
WORDLIMIT = 20
#キーワード#
UPDATE_NAME = "update_name"

def init()
    rest = Twitter::REST::Client.new do |config|
        config.consumer_key = CONSUMER_KEY
        config.consumer_secret = CONSUMER_SECRET
        config.access_token = OAUTH_TOKEN
        config.access_token_secret = OAUTH_TOKEN_SECRET
    end

    stream = Twitter::Streaming::Client.new do |config|
        config.consumer_key = CONSUMER_KEY
        config.consumer_secret = CONSUMER_SECRET
        config.access_token = OAUTH_TOKEN
        config.access_token_secret = OAUTH_TOKEN_SECRET
    end

    return rest, stream
end

def aigatshainit()
    rest = Twitter::REST::Client.new do |config|
        config.consumer_key = CONSUMER_KEY
        config.consumer_secret = CONSUMER_SECRET
        config.access_token = AI_OAUTH_TOKEN
        config.access_token_secret = AI_OAUTH_TOKEN_SECRET
    end
    
    stream = Twitter::Streaming::Client.new do |config|
        config.consumer_key = CONSUMER_KEY
        config.consumer_secret = CONSUMER_SECRET
        config.access_token = AI_OAUTH_TOKEN
        config.access_token_secret = AI_OAUTH_TOKEN_SECRET
    end
    
    return rest, stream
end

def length_errorcheck(str, rest)
	if str.length > WORDLIMIT
		return true
	end
	return false
end

def toolong_error(str, rest)
    rest.update("#{str}は長すぎワロタ")
end


def update_name(str, id, fromid, rest)
	begin
		rest.update_profile(options = {name:str})
        	rest.favorite(id)
		rest.update("わっちは#{str}じゃ！以後よろしゅうな！")
	rescue Twitter::Error::TooManyRequests => error
		limitExceeded(error)
		retry
	end
	update_history(fromid, str)
end

def update_history(fromid, str)
	File.open("history.txt", "a") do |file|
        file.puts("#{fromid}:#{str}")
	end
end


=begin
ブラックワードリストの初期化
=end
def blackwordlist_init()
	if File.exist?("blackwordlist.txt")
		blackwordlist = []
		File.open("blackwordlist.txt", "r") do |file|
			file.each do |fileline|
				blackwordlist << fileline.chomp
			end
		end
	else
		file = File.open("blackwordlist.txt", "w")
		file.close
	end
	return blackwordlist
end

=begin
ブラックワードリストの実行
=end
def blackword_check(str, blackwordlist)
	blackwordlist.each do |line|
		puts "#{line}:check\n"
		if(str =~ /.*#{line}.*/)
			puts "#{str} is in blackwordlist.\n"	
			return true
		end
	end
	return false
end

=begin
ブラックリストの初期化
=end
def blacklist_init()
	if File.exist?("blacklist.txt")
		blacklist = []
		File.open("blacklist.txt", "r") do |file|
			file.each do |fileline|
				blacklist << fileline.chomp
			end
		end
	else
		file = File.open("blacklist.txt", "w")
		file.close
	end
	return blacklist
end

=begin
ブラックリストの実行
=end
def black_check(str, blacklist)
	blacklist.each do |line|
		if(str == line)
			return true
		end
	end
	return false
end

=begin
ブラックワードの応答
=end
def blackword_error(str, rest)
    rest.update("#{str}は嫌じゃ！断る！")
end

=begin
マッチングパターンの初期化
=end
def matchpattern_init()
	matchpattern = "/.* update_name\Z/"
	if File.exist?("match.txt")
		File.open("match.txt", "r") do |file|
			file.each do |fileline|
				matchpattern = fileline.chomp
			end
		end
	else
		file = File.open("match.txt", "w")
		file.write(matchpattern)
		file.close
	end
	return matchpattern
end

def replycut(str)
    if(str =~ /@/)
        return true
    end
    return false
end

#API制限回避#
def limitExceeded(errorObj)
	puts "Twitter limit exceed.begin cool down\n"
	sleep errorObj.rate_limit.rest_in + 10 #クールタイムの解消
	puts "cool time ended\n"
end

=begin
#ガチャ機能ここから#
=end

def gatcha_init()
    if File.exist?("gatchalist.txt")
        gatchalist = Hash.new{|h, key|h[key] = []}
        
        File.open("gatchalist.txt", "r") do |file|
            file.each do |fileline|
                tmp = fileline.chomp.split(",", 2)
                gatchalist[tmp[0]] << tmp[1]
            end
        end
    else
        file = File.open("gatchalist.txt", "w")
        file.close
    end
    
    return gatchalist
end

def setprobability()
    low = 0
    if File.exist?("probabilitylist.txt")
        probabilitylist = Hash.new{|h, key|h[key] = []}
        
        File.open("probabilitylist.txt", "r") do |file|
            file.each do |fileline|
                tmp = fileline.chomp.split(",", 2)
                probabilitylist["rarity"]   << tmp[0]
                probabilitylist["low"]      << low
                probabilitylist["high"]     << (low + tmp[1].to_i - 1)
                low = low + tmp[1].to_i
            end
        end
        low = low
    else
        file = File.open("probabilitylist.txt", "w")
        file.close
    end
 
    
    return probabilitylist, low
end

def deciderarity(probabilitylist, maxnum)
    num = rand(maxnum)
    probabilitylist["low"].zip(probabilitylist["high"], probabilitylist["rarity"]).each do |low, high, rarity|
        if(low <= num && num <= high)
            return rarity
        end
    end
    
end

def gatchapattern_init()
    matchpattern = "/ガチャ\Z/"
    if File.exist?("gatchamatch.txt")
        File.open("gatchamatch.txt", "r") do |file|
            file.each do |fileline|
                matchpattern = fileline.chomp
            end
        end
    else
        file = File.open("gatchamatch.txt", "w")
        file.write(matchpattern)
        file.close
    end
    return matchpattern
end

def gatcha_reply(id, fromid, rest, gatchalist, probabilitylist, maxnum)
	rarity = deciderarity(probabilitylist, maxnum)
	rest.update("@#{fromid}\n ガチャ結果:\n[#{rarity}]#{gatchalist[rarity].sample}", in_reply_to_status_id: id)
end

#ガチャ機能ここまで#
matchpattern = Hash.new()

restConsole,streamConsole = init() #RESTとSTREAMの初期化
airestConsole,aistreamConsole = aigatshainit() #愛ガチャのREST,STREAM初期化

gatchalist = gatcha_init()
probabilitylist,maxnum = setprobability()

*blackwordlist = blackwordlist_init() #ブラックワードリストの初期化
*blacklist = blacklist_init() #ブラックリストの初期化

matchpattern.store("update_name", matchpattern_init()) #正規表現マッチパターンの初期化
matchpattern.store("gatcha", gatchapattern_init())

puts "initialization is ok.\n"
restConsole.update("初期化成功\n#{matchpattern[UPDATE_NAME]}に一致するツイートに反応して名前が変わります。\n#{Time.now}")

puts matchpattern["update_name"]
puts matchpattern["gatcha"]

streamConsole.user do |object|
    if object.is_a?(Twitter::Tweet) #streamからツイートが取得された場合
        unless black_check(object.user.screen_name, blacklist) #ブラックリストと比較	
            if object.text =~ /#{matchpattern["update_name"]}/ #正規表現比較
                str = $& #マッチ文字列の取り出し
                puts "#{str} is matched."
                id = object.id
                fromid = object.user.screen_name
                if replycut(str)
                    next
                end
                if length_errorcheck(str, restConsole) #文字列の長さのチェック
                    toolong_error(str, restConsole) #長すぎエラー
                    next
                end
                if blackword_check(str, blackwordlist) #ブラックワードのチェック
                    blackword_error(str, restConsole) #ブラックワード返答
                    next
                end
                update_name(str, id, fromid, restConsole) #アップデートする
            end
            if object.text =~ /#{matchpattern["gatcha"]}/
                id = object.id
                fromid = object.user.screen_name
                gatcha_reply(id, fromid, airestConsole, gatchalist, probabilitylist, maxnum) #ガチャをする
            end
        end
    end
end
