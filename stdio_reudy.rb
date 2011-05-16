#Copyright (C) 2003 Gimite ���� <gimite@mx12.freecom.ne.jp>

#���ܸ�ʸ��������Ƚ���ѥ�����

$KCODE= "EUC"
$OUT_KCODE= "SJIS" #����ʸ��������
$REUDY_DIR= "lib/reudy" if !defined?($REUDY_DIR) #������ץȤ�����ǥ��쥯�ȥ�

require 'kconv'
require $REUDY_DIR+'/bot_irc_client'
require $REUDY_DIR+'/reudy'
require $REUDY_DIR+'/reudy_common'


module Gimite


class StdioClient
  
  include(Gimite)
  
  def initialize(user, yourNick)
    @user= user
    @user.client= self
    @yourNick= yourNick
    greeting= @user.settings("joining_message")
    jprint(greeting+"\n") if greeting
  end
  
  def loop()
    $stdin.each_line() do |line|
#      $stderr.print("> "+line)#��
      line= line.chomp().toeuc()
      if line==""
        @user.onSilent()
      elsif @yourNick
        @user.onOtherSpeak(@yourNick, line)
      elsif line=~/^(.+?) (.*)$/
        @user.onOtherSpeak($1, $2)
      else
        $stderr.print("Error\n")
      end
    end
  end
  
  #�����������
  def outputInfo(s)
    jprint("("+s+")\n")
  end
  
  #ȯ������
  def speak(s)
    jprint(s+"\n")
  end
  
  #��λ����
  def exit()
    Kernel.exit(0)
  end
  
end


$stdout.sync= true
if ARGV.size()==1 || ARGV.size()==2
  #ɸ���������ѥ��ǥ������
  client= StdioClient.new(Reudy.new(ARGV[0]), ARGV[1] && Kconv.toeuc(ARGV[1]))
  client.loop()
else
  $stderr.print( \
    "Usage: ruby stdio_reudy.rb ident_dir your_name\n\n" \
    +"'ident_dir' is a directory which contains setting.txt, log.txt, etc.\n")
end


end #module Gimite
