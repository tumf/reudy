#Copyright (C) 2003 Gimite ���� <gimite@mx12.freecom.ne.jp>

#���ܸ�ʸ��������Ƚ���ѥ�����
require 'socket'
require 'thread'
require 'kconv'
require 'jcode'
require 'timeout'
require 'lingr/botkit'
require $REUDY_DIR+'/reudy_common'


module Gimite


#�ܥå��Ѥ�Lingr���饤�����
class BotLingrClient < Lingr::BotBase
  
  include(Gimite)
  
  SILENT_SECOND= 20.0 #���ۤ�³������Ƚ�Ǥ����ÿ���
  
  def initialize(user)
    @user= user
    @api_key= @user.settings("api_key")
    @email= @user.settings("email")
    @email= nil if @email && @email.empty?
    @password= @user.settings("password")
    @password= nil if @password && @password.empty?
    @main_room_id= @user.settings("main_room_id")
    @info_room_id= @user.settings("info_room_id")
    @rooms= [@main_room_id, @info_room_id].uniq().map(){ |i| {:id => i} }
    @nick= @user.settings("nick")
    @user.client= self
    @user.onBeginConnecting()
    @client= Lingr::LingrClient.new(@api_key, @email, @password)
    @client.bot= self
  end
  
  #��å�������Ҥ������������롼�ס�
  def processLoop()
    
    while true
      begin
        @client.open() do
          
          for r in @rooms
            @client.enter_room(r[:id], @nick, r[:password])
          end
          @main_room= @client.find_room(@main_room_id)
          @info_room= @client.find_room(@info_room_id)
          @receiveQue= Queue.new() #������ä��̾�ȯ���Υ��塼��
          @controlQue= Queue.new() #������ä�����ȯ���Υ��塼��
          receiveThread= Thread.new(){ receiveProcess() }
          
          @client.enter_event_loop()
          
          @receiveQue.push(nil)
          receiveThread.join() if receiveThread
          for r in @rooms
            @client.exit_room(r[:id])
          end
          
        end
        return
      rescue Lingr::DisconnectedError
        jputs("���Ǥ���ޤ�����")
        sleep(60)
        jputs("����³��...")
      end
    end
    
  end
  
  #�����������
  def outputInfo(s)
    sleep(@user.settings("wait_before_info").to_f()) if @user.settings("wait_before_info")
    @info_room.say(s)
  end
  
  #ȯ������
  def speak(s)
    @main_room.say(s)
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
    @main_room.set_nickname(@nick + (status ? "@#{status}" : ""))
  end
  
  #��λ��
  def exit()
    @client.exit_event_loop()
  end
  
  def on_init
    jputs '*** Initialized (CTRL-C to quit)'
    greeting= @user.settings("joining_message")
    speak(greeting) if greeting
    @user.onSelfJoin()
  end

  def on_text(room, mes)
    jputs "#{room.name} > #{mes.nickname}: #{mes.text}"
    if room==@main_room
      for line in mes.text.chomp().split(/\r\n|[\r\n]/)
        @receiveQue.push([mes.nickname, line])
      end
    end
  end

  def on_bot_text(room, mes)
    jputs "#{room.name} > (#{mes.nickname}): #{mes.text}"
  end

  def on_enter(room, mes)
    jputs "#{room.name} > *** #{mes.nickname} has joined the conversation"
    @user.onOtherJoin(mes.nickname) if room==@main_room
  end

  def on_leave(room, mes)
    jputs "#{room.name} > *** #{mes.nickname} has left the conversation"
  end

  def on_nickname_change(room, mes)
    jputs "#{room.name} > *** #{mes.nickname} is now known as #{mes.new_nickname}"
  end

  private
  
  #�������ƥ��塼�ˤ��ޤäƤ���ȯ����������롣
  def receiveProcess()
    while args= popMessage()
      if args==:silent
        @user.onSilent()
      else
        while args
          if @user.settings("wait_before_speak")
            sleep(@user.settings("wait_before_speak").to_f()*(0.5+rand()))
          end
          if @receiveQue.empty?()
            @user.onOtherSpeak(*(args+[false]))
            break
          end
          while !@receiveQue.empty?() && args
            #�����������¾�οͤ�ȯ�������ä���硢����ȯ���϶���̵�뤹�롣
            @user.onOtherSpeak(*(args+[true]))
            args= popMessage()
            return if !args
          end
        end
      end
    end
  end
  
  #�������ƥ��塼�ˤ��ޤäƤ���ȯ������Ф���
  #����ȯ���������ͥ�褷�ƽ������롣
  def popMessage()
    while true
      mess= nil
      begin
        Timeout.timeout(SILENT_SECOND) do
          mess= @receiveQue.pop()
        end
      rescue TimeoutError
        mess= :silent
      end
      while !@controlQue.empty?
        @user.onControlMsg(@controlQue.pop())
      end
      return mess if mess!=:nop
    end
  end
  
end


end #module Gimite
