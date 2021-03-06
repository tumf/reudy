#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>

#日本語文字コード判定用コメント
DEBUG= false
require 'socket'
require 'thread'
require 'kconv'
require 'jcode'
require $REUDY_DIR+'/irc-client'
require $REUDY_DIR+'/reudy_common'


module Gimite


#文字コードを$OUT_KCODEに変換して出力する、$stdoutもどき。手抜き。
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


#ボット用のIRCクライアント
class BotIRCClient < IRCC
  
  include(Gimite)
  
  SILENT_SECOND= 20.0 #沈黙が続いたと判断する秒数。
  
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
  
  #IRCのメッセージをひたすら処理するループ。
  def processLoop()
    while true
      begin
        @isJoiningInfoChannel= false
        @prevTime= Time.now() #onSilent用。
        @receiveQue= Queue.new() #受け取った通常発言のキュー。
        @controlQue= Queue.new() #受け取った制御発言のキュー。
        connect(TCPSocket.open(@user.settings("host"), @user.settings("port").to_i(),
          @user.settings("localhost")))
        on_connect() #ソケット接続時の処理。
        pingThread= Thread.new(){ pingProcess() }
        receiveThread= Thread.new(){ receiveProcess() }
        #受信ループ。
        while line= sock().gets()
          on_recv(line)
          if Time.now()-@prevTime>=SILENT_SECOND
            @prevTime= Time.now()
            @user.onSilent()
              #沈黙がしばらく続いた。
              #発言が何も無くてもpingProcess()のおかげで定期的にメッセージが飛んでくるので、
              #ここでチェックすればOK。
          end
        end
        jprint("切断されました。\n")
      rescue SystemCallError, SocketError, IOError => ex
        jprint("切断されました。"+ex.message()+"\n")
      end
      pingThread.exit() if pingThread
      @receiveQue.push(nil)
      receiveThread.join() if receiveThread
      break if @isExitting || @user.settings("auto_reconnect")!="true"
      sleep(10)
      break if !queryReconnect()
      jprint("再接続中...\n")
    end
  end
  
  #補助情報を出力
  def outputInfo(s)
    sleep(@user.settings("wait_before_info").to_f()) if @user.settings("wait_before_info")
    sendmess("NOTICE "+@infoChannel+" :"+s+"\n")
  end
  
  #発言する
  def speak(s)
    if @user.settings("speak_with_privmsg")=="true"
      sendpriv(s)
    else
      sendnotice(s)
    end
  end
  
  #チャンネルを移動。接続中はこっちを使う。
  def moveChannel(channel)
    greeting= @user.settings("leaving_message")
    speak(greeting) if greeting
    @channel= channel
    movechannel(@channel)
  end
  
  #チャンネルを変更。切断中はこっちを使う。
  def setChannel(channel)
    @channel= channel
    setchannel(@channel)
  end
  
  def status=(status)
  end
  
  #終了。
  def exit()
    @isExitting= true
    greeting= @user.settings("leaving_message")
    sendmess(greeting ? "QUIT :"+greeting+"\r\n" : "QUIT\r\n")
  end
  
  #以下、IRCCのメソッドのオーバライド
  
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
    #IRCC#on_myjoinの中ではon_joinが呼ばれてしまうので、
    #ここでsuperを呼んではいけない。
    onMyJoin(channel)
  end
  
  def on_myinvite(nick, channel)
    super(nick, channel)
    onInvite(nick, channel)
  end
  
  def on_error(code)
    onError(code)
  end
  
  #以下、派生クラスでオーバライド可能なメソッド
  
  #普通のメッセージ
  def onPriv(type, nick, mess)
    if nick!=@nick && (@user.settings("respond_to_notice")=="true" || type=="PRIVMSG")
      @prevTime= Time.now()
      @receiveQue.push([nick, mess.strip()])
    end
  end
  
  #今いるチャンネルの外からの普通のメッセージ
  def onExternalPriv(type, nick, to, mess)
    return if nick==@nick || (@user.settings("respond_to_notice")!="true" && type!="PRIVMSG")
    @prevTime= Time.now()
    if @user.settings("respond_to_external")!="true"
      #チャンネル外からの発言は制御発言、という危険な仮仕様。
      @controlQue.push(mess.strip())
      @receiveQue.push(:nop) #メッセージ処理ループのブロックを解く。
    else
      @receiveQue.push([nick, mess.strip()])
    end
  end
  
  #他人がJOINした
  def onJoin(nick, channel)
    greeting= @user.settings("private_greeting")
    sendmess("NOTICE "+nick+" :"+greeting+"\n") if greeting && greeting!=""
    @user.onOtherJoin(nick)
  end
  
  #自分がJOINした
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
  
  #招待された
  def onInvite(nick, channel)
    moveChannel(channel)
  end
  
  #再接続の前に呼び出される。
  #falseを返すと、再接続せずに終了する。
  def queryReconnect()
    return true
  end
  
  #エラー
  def onError(code)
    if code=="433"
      jprint("Error: ニックネーム "+@nick+" は、別の人に使われています。\n")
    else
      jprint("Error: エラーコード "+code+"\n")
    end
    sendmess_raw("QUIT\r\n") #一度QUITして再接続。
  end
  
  private
  
  #受信してキューにたまっている発言を処理する。
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
          #ウエイト中に他の人の発言が入った場合、前の発言は極力無視する。
          @user.onOtherSpeak(*(args+[true]))
          args= popMessage()
          return if !args
        end
      end
    end
  end
  
  #受信してキューにたまっている発言を取り出す。
  #制御発言があれば優先して処理する。
  def popMessage()
    while true
      mess= @receiveQue.pop()
      while !@controlQue.empty?
        @user.onControlMsg(@controlQue.pop())
      end
      return mess if mess!=:nop
    end
  end
  
  #定期的に意味の無いメッセージを送り、通信が切れてないか確かめる。
  #通信が切れたら、sock().gets()のブロック状態を解除させるためにsock().close()する。
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
