#Copyright (C) 2003 Gimite ���� <gimite@mx12.freecom.ne.jp>

#���ܸ�ʸ��������Ƚ���ѥ�����
require "rubygems"
require 'socket'
require 'thread'
require 'kconv'
require 'jcode'
require 'timeout'
require "webrick"
require "cgi"
require "json"
require $REUDY_DIR+'/reudy_common'


module Gimite


#�ܥå��Ѥ�Lingr���饤�����
class BotLingr2Client
  
  include(Gimite)
  
  def initialize(user)
    @user= user
    @port= @user.settings("port").to_i()
    @nick= @user.settings("nick")
    @user.client= self
    @user.onBeginConnecting()
    @speech_que = []
  end
  
  #��å�������Ҥ������������롼�ס�
  def processLoop()
    @server = WEBrick::HTTPServer.new(:Port => @port)
    @server.mount_proc("/") do |req, res|
      (key, value) =
        req.body.split(/&/).map(){ |s| s.split(/=/) }.find(){ |k, v| k == "json" }
      jputs CGI.unescape(value).toeuc()
      input = JSON.parse(CGI.unescape(value).toeuc())
      for event in input["events"]
        if event["message"]
          nick = event["message"]["nickname"]
          text = event["message"]["text"]
          jputs [nick, text].join(": ")
          @user.onOtherSpeak(nick, text, false)
        end
      end
      res["Content-Type"]= "text/plain"
      jputs "����: " + @speech_que.join("\n")
      res.body = @speech_que.join("\n").toutf8()
      @speech_que = []
    end
    trap("INT"){ @server.shutdown() }
    @server.start()
  end
  
  #�����������
  def outputInfo(s)
  end
  
  #ȯ������
  def speak(s)
    jputs "ȯ��: #{s}"
    @speech_que.push(s)
  end
  
  #�����ͥ���ư����³��Ϥ��ä���Ȥ���
  def moveChannel(channel)
    raise("Not implemented")
  end
  
  #�����ͥ���ѹ���������Ϥ��ä���Ȥ���
  def setChannel(channel)
    raise("Not implemented")
  end
  
  def status=(status)
    #@main_room.set_nickname(@nick + (status ? "@#{status}" : ""))
  end
  
  #��λ��
  def exit()
    @server.shutdown()
  end
  
  def on_init
    jputs '*** Initialized (CTRL-C to quit)'
    @user.onSelfJoin()
  end

end


end #module Gimite
