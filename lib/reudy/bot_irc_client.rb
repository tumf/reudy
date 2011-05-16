#Copyright (C) 2003 Gimite ���� <gimite@mx12.freecom.ne.jp>

#���ܸ�ʸ��������Ƚ���ѥ�����
DEBUG= false
require 'socket'
require 'thread'
require 'kconv'
require 'jcode'
require $REUDY_DIR+'/irc-client'
require $REUDY_DIR+'/reudy_common'


module Gimite


#ʸ�������ɤ�$OUT_KCODE���Ѵ����ƽ��Ϥ��롢$stdout��ɤ�����ȴ����
JSTDOUT= Object.new()
class << JSTDOUT
  
  include(Gimite)
  
  def puts(str)
    jprint_to($stdout, str+"\n")
  end
  
  def flush()
    $stdout.flush()
  end
  
end


#�ܥå��Ѥ�IRC���饤�����
class BotIRCClient < IRCC
  
  include(Gimite)
  
  SILENT_SECOND= 20.0 #���ۤ�³������Ƚ�Ǥ����ÿ���
  
  def initialize(user, logOut= JSTDOUT)
    @user= user
    @isExitting= false
    @channel= @user.settings("channel")
    @infoChannel= @user.settings("info_channel")
    @nick= @user.settings("nick")
    @user.client= self
    @user.onBeginConnecting()
    pass= @user.settings("login_password")
    option= {
      'user'=>@user.settings("name"), \
      'realname'=>@user.settings("real_name"), \
      'pass'=>pass, \
      'nick'=>@nick, \
      'channel'=>@channel, \
      'channel_key'=>@user.settings("channel_key") \
    }
    super(nil, option, $KCODE, logOut, @user.settings("encoding") || "JIS")
  end
  
  #IRC�Υ�å�������Ҥ������������롼�ס�
  def processLoop()
    while true
      begin
        @isJoiningInfoChannel= false
        @prevTime= Time.now() #onSilent�ѡ�
        @receiveQue= Queue.new() #������ä��̾�ȯ���Υ��塼��
        @controlQue= Queue.new() #������ä�����ȯ���Υ��塼��
        connect(TCPSocket.open(@user.settings("host"), @user.settings("port").to_i(),
          @user.settings("localhost")))
        on_connect() #�����å���³���ν�����
        pingThread= Thread.new(){ pingProcess() }
        receiveThread= Thread.new(){ receiveProcess() }
        #�����롼�ס�
        while line= sock().gets()
          on_recv(line)
          if Time.now()-@prevTime>=SILENT_SECOND
            @prevTime= Time.now()
            @user.onSilent()
              #���ۤ����Ф餯³������
              #ȯ��������̵���Ƥ�pingProcess()�Τ����������Ū�˥�å�����������Ǥ���Τǡ�
              #�����ǥ����å������OK��
          end
        end
        jprint("���Ǥ���ޤ�����\n")
      rescue SystemCallError, SocketError, IOError => ex
        jprint("���Ǥ���ޤ�����"+ex.message()+"\n")
      end
      pingThread.exit() if pingThread
      @receiveQue.push(nil)
      receiveThread.join() if receiveThread
      break if @isExitting || @user.settings("auto_reconnect")!="true"
      sleep(10)
      break if !queryReconnect()
      jprint("����³��...\n")
    end
  end
  
  #�����������
  def outputInfo(s)
    sleep(@user.settings("wait_before_info").to_f()) if @user.settings("wait_before_info")
    sendmess("NOTICE "+@infoChannel+" :"+s+"\n")
  end
  
  #ȯ������
  def speak(s)
    if @user.settings("speak_with_privmsg")=="true"
      sendpriv(s)
    else
      sendnotice(s)
    end
  end
  
  #�����ͥ���ư����³��Ϥ��ä���Ȥ���
  def moveChannel(channel)
    greeting= @user.settings("leaving_message")
    speak(greeting) if greeting
    @channel= channel
    movechannel(@channel)
  end
  
  #�����ͥ���ѹ���������Ϥ��ä���Ȥ���
  def setChannel(channel)
    @channel= channel
    setchannel(@channel)
  end
  
  def status=(status)
  end
  
  #��λ��
  def exit()
    @isExitting= true
    greeting= @user.settings("leaving_message")
    sendmess(greeting ? "QUIT :"+greeting+"\r\n" : "QUIT\r\n")
  end
  
  #�ʲ���IRCC�Υ᥽�åɤΥ����Х饤��
  
  def on_priv(type, nick, mess)
    super(type, nick, mess)
    onPriv(type, nick, mess)
  end
  
  def on_external_priv(type, nick, to, mess)
    super(type, nick, to, mess)
    onExternalPriv(type, nick, to, mess)
  end
  
  def on_join(nick, channel)
    super(nick, channel)
    onJoin(nick, channel)
  end
  
  def on_myjoin(channel)
    #IRCC#on_myjoin����Ǥ�on_join���ƤФ�Ƥ��ޤ��Τǡ�
    #������super��Ƥ�ǤϤ����ʤ���
    onMyJoin(channel)
  end
  
  def on_myinvite(nick, channel)
    super(nick, channel)
    onInvite(nick, channel)
  end
  
  def on_error(code)
    onError(code)
  end
  
  #�ʲ����������饹�ǥ����Х饤�ɲ�ǽ�ʥ᥽�å�
  
  #���̤Υ�å�����
  def onPriv(type, nick, mess)
    if nick!=@nick && (@user.settings("respond_to_notice")=="true" || type=="PRIVMSG")
      @prevTime= Time.now()
      @receiveQue.push([nick, mess.strip()])
    end
  end
  
  #����������ͥ�γ���������̤Υ�å�����
  def onExternalPriv(type, nick, to, mess)
    return if nick==@nick || (@user.settings("respond_to_notice")!="true" && type!="PRIVMSG")
    @prevTime= Time.now()
    if @user.settings("respond_to_external")!="true"
      #�����ͥ볰�����ȯ��������ȯ�����Ȥ������ʲ����͡�
      @controlQue.push(mess.strip())
      @receiveQue.push(:nop) #��å����������롼�פΥ֥�å���򤯡�
    else
      @receiveQue.push([nick, mess.strip()])
    end
  end
  
  #¾�ͤ�JOIN����
  def onJoin(nick, channel)
    greeting= @user.settings("private_greeting")
    sendmess("NOTICE "+nick+" :"+greeting+"\n") if greeting && greeting!=""
    @user.onOtherJoin(nick)
  end
  
  #��ʬ��JOIN����
  def onMyJoin(channel)
    if channel.strip().downcase == @channel.downcase
      greeting= @user.settings("joining_message")
      speak(greeting) if greeting
      @user.onSelfJoin()
    end
    if !@isJoiningInfoChannel
      sendmess("JOIN "+@infoChannel+"\r\n") 
      @isJoiningInfoChannel= true
    end
  end
  
  #���Ԥ��줿
  def onInvite(nick, channel)
    moveChannel(channel)
  end
  
  #����³�����˸ƤӽФ���롣
  #false���֤��ȡ�����³�����˽�λ���롣
  def queryReconnect()
    return true
  end
  
  #���顼
  def onError(code)
    if code=="433"
      jprint("Error: �˥å��͡��� "+@nick+" �ϡ��̤οͤ˻Ȥ��Ƥ��ޤ���\n")
    else
      jprint("Error: ���顼������ "+code+"\n")
    end
    sendmess_raw("QUIT\r\n") #����QUIT���ƺ���³��
  end
  
  private
  
  #�������ƥ��塼�ˤ��ޤäƤ���ȯ����������롣
  def receiveProcess()
    while args= popMessage()
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
  
  #�������ƥ��塼�ˤ��ޤäƤ���ȯ������Ф���
  #����ȯ���������ͥ�褷�ƽ������롣
  def popMessage()
    while true
      mess= @receiveQue.pop()
      while !@controlQue.empty?
        @user.onControlMsg(@controlQue.pop())
      end
      return mess if mess!=:nop
    end
  end
  
  #���Ū�˰�̣��̵����å����������ꡢ�̿����ڤ�Ƥʤ����Τ���롣
  #�̿����ڤ줿�顢sock().gets()�Υ֥�å����֤��������뤿���sock().close()���롣
  def pingProcess()
    while true
      sleep(SILENT_SECOND)
      begin
        sendmess("TOPIC "+@channel+"\r\n")
      rescue
        sock.close()
        Thread.exit()
      end
    end
  end
  
end


end #module Gimite
