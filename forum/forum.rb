require 'sinatra'
require "sinatra/cookies"
require 'digest/sha1'
require 'digest/md5'
require "markdown"
require 'mongoid'
require 'json'
require 'aes'
require 'base64' 
Mongoid.load!("#{File.dirname(__FILE__)}/config/mongoid.yml")
Mongoid.logger = Logger.new($stdout)
Moped.logger = Logger.new($stdout)
		class User 
			include Mongoid::Document
			store_in collection: "users"
			field :name, type: String
			field :pass, type: String
			field :mail, type: String
			field :regtime, type: Time
			field :status # "user" , "admin" , "ban"
			field :more, type: String
			field :q
			field :a
			shard_key :name, :pass, :mail, :regtime, :status, :more, :q, :a
			index({ regtime: 1 }, { unique: true, name: "regtime_index" })
		end
		class Node 
			include Mongoid::Document
			store_in collection: "nodes"
			field :name, type: String
			field :texts, type: String
			shard_key :name, :texts
		end
		class Post 
			include Mongoid::Document
			store_in collection: "posts"
			field :posthash, type: String
			field :title, type: String
			field :texts, type: String
			field :user, type: String
			field :time, type: Time
			field :node, type: String
			field :type # "topic" &"reply" 
			field :status # 0 -> basic , 1 -> important , 2 -> HEXIE
			field :mother
			shard_key :hash, :title, :texts, :user, :time, :node, :type, :status, :mother
			index({ time: 1 }, { unique: true, name: "time_index" })
		end
		class Updatepostcache
			def initialize
				@posts = Post.where(type:"reply")
				@cached_list_all = Array.new
				@posts.sort(_id: -1).each do |post|
					if post != nil
						@cached_list_all << post.mother
					end
				end
				@cached_list_all = @cached_list_all.uniq
				@cached_list_node = {}
				Node.each do |n|
					@cached_list_node[n.name] = Array.new
					@posts.where(node: n.name).sort(_id: -1).each do |post|
						if post != nil
							@cached_list_node[n.name] << post.mother
						end
					end
					@cached_list_node[n.name] = @cached_list_node[n.name].uniq
				end
			end
			def update
				@posts = Post.where(type:"reply")
				@cached_list_all = Array.new
				@posts.sort(_id: -1).each do |post|
					if post != nil
						@cached_list_all << post.mother
					end
				end
				@cached_list_all = @cached_list_all.uniq
				@cached_list_node = {}
				Node.each do |n|
					@cached_list_node[n.name] = Array.new
					@posts.where(node: n.name).sort(_id: -1).each do |post|
						if post != nil
							@cached_list_node[n.name] << post.mother
						end
					end
					@cached_list_node[n.name] = @cached_list_node[n.name].uniq
				end
			end
			def getcachedlist(node="")
				if node == ""
					@return = @cached_list_all
				else
					@return = @cached_list_node[node]
				end
				return @return
			end
				

		end
$post_cache = Updatepostcache.new
config_file = "#{File.dirname(__FILE__)}/config/config.json"
set :views, settings.root + '/ui'
set :public_folder, File.dirname(__FILE__) + '/ui/assets'
conf = JSON.parse(File.new(config_file,"r").read)[0]
$conf = JSON.parse(File.new(config_file,"r").read)[0]
$navi = JSON.parse(File.new(config_file,"r").read)[1]
aes_key = conf["cookies_key"]
require './MUtils'
get "/" do
	@name = conf["sitename"]
	@title = conf["sitetitle"]
	erb :index
end
get "/!!/GetIndexData/page/:page" do
	@count = GetPostListInfo(conf["maxitemnumber"])
	@data = GetLatestPost(conf["maxitemnumber"],params[:page].to_f)
	@pg = (1..@count[2]).map {|x| p x}
	erb :topicbox
end
get "/!!/GetIndexData_js/page/:page" do
	@count = GetPostListInfo(conf["maxitemnumber"])
	@data = GetLatestPost(conf["maxitemnumber"],params[:page].to_f)
	erb :topicbox_js
end
get "/!!/GetNodeData/node/:node/page/:page" do
	@count = GetPostListInfo(conf["maxitemnumber"])
	@data = GetLatestPostByNode(params[:node],conf["maxitemnumber"],params[:page].to_f)
	@pg = (1..@count[2]).map {|x|}
	erb :topicbox
end
get "/!!/GetNodeData_js/node/:node/page/:page" do
	@count = GetPostListInfo(conf["maxitemnumber"])
	@data = GetLatestPostByNode(params[:node],conf["maxitemnumber"],params[:page].to_f)
	erb :topicbox_js
end
get "/!!/Posting/^:node" do
	if Node.where(name: params[:node].to_s).exists?
		@node_exists = true
		@node = param[:node].to_s
	else
		@node_exists = false
	end
	erb :topicbox
end
get "/!!/Userbox" do
	CheckCookie()
	@x = ''
	@msg = 0 # 0 => not logined
	unless cookies[:auth] == ""
		@x = cookies[:auth]
		@a = AES.decrypt(@x,aes_key)
		@info = JSON.parse(@a)
		@msg = 1 # 1 => already logined
	end
	erb :userbox
end

get "/!!/CTbox/:node" do
	@node = params[:node]
	@node_exists = false
	if Node.where(name: @node).exists?
		@node_exists = true
	end
		erb :CTbox
end
get "/!!/LRbox" do
	CheckCookie()
	@cookies = cookies[:auth]
	@my = 0
	unless @cookies == ''
		@ck = JSON.parse(AES.decrypt(@cookies , aes_key))
		@my = 1

	end
	erb :LRbox
end
get "/!!/LRbox_reg" do
	@reg = 'yes'
	erb :LRbox
end
get "/!!/Login/:name&:pass" do
	@su = Login(params[:name],params[:pass],aes_key)
	"#{@su}"
end
get "/!!/Register/:b64" do
	@b64 = JSON.parse(Base64.decode64(params[:b64]))
	@msg = CreatUser(@b64["user"],@b64["pass"],@b64["mail"])
	"#{@msg}"
end
get "/!!/CookieClean" do
	cookies[:auth] = ""
	'{ "logout" : true }'
end
get "/!!!!/CreatNode/:name/:texts" do
	@a = CreatNode(params[:name],params[:texts])
	"#{@a}"
end
get "/!!/Clean" do
	""
end
get "/!!/GetNodeList" do
	@node  = Node
	erb :nodelist
end
post '/!!/post/*' do |c|
	@data = JSON.parse(Base64.decode64(c))
	@json = PostToMongo(
		@data["title"],
		@data["data"],
		JSON.parse(AES.decrypt(cookies[:auth] , aes_key))["name"],
		@data["node"],
		"topic",
		"basic",
		"")
	PostToMongo(
		'init',
		'',
		'',
		@data["node"],
		"reply",
		"basic",
		JSON.parse(@json)["hasH"])
	"#{@json}"
end
post '/!!/viewpost/*' do |hash|
	@data = Post.where(posthash: hash)
	if @data.exists?
		@type = "topic"
	else
		@type = "notfound"
	end
	erb :viewtopic
end
get '/!!/getreplies/*' do |hash|
	@data = Array.new
	@num = Post.where(mother: hash).count
	Post.where(title:"reply",mother: hash).sort(_id: 1).limit(@num).each  do |post|
		if post != nil
			@data << post.posthash
		end
	end
	@type = "reply"
	erb :viewtopic
end
post '/!!/reply/*' do |c|
	@data = JSON.parse(Base64.decode64(c))
	@json = PostToMongo(
		'reply',
		@data["data"],
		JSON.parse(AES.decrypt(cookies[:auth] , aes_key))["name"],
		Post.where(posthash:@data["mother"])[0].node,
		"reply",
		"basic",
		@data["mother"])
	"#{@json}"
end
