#Copyright (C) 2003 Gimite ���� <gimite@mx12.freecom.ne.jp>

#���ܸ�ʸ��������Ƚ���ѥ�����

$KCODE= "EUC"
$OUT_KCODE= "UTF8" #����ʸ��������
$LOAD_PATH << "./lib"
$REUDY_DIR= "lib/reudy" if !defined?($REUDY_DIR) #������ץȤ�����ǥ��쥯�ȥ�
Thread.abort_on_exception= true

require 'getopts'
require $REUDY_DIR+'/bot_lingr2_client'
require $REUDY_DIR+'/reudy'


module Gimite


$stdout.sync= true
$stderr.sync= true

getopts("f")
if ARGV.size()!=1
  $stderr.print( \
    "Usage: ruby lingr_reudy.rb [-f] ident_dir\n\n" \
    +"'ident_dir' is a directory which contains setting.txt, log.txt, etc.\n")
  exit(1)
end

MessageLog.enable_update_check= !$OPT_f

begin
  #Lingr�ѥ��ǥ������
  client= BotLingr2Client.new(Reudy.new(ARGV[0]))
  client.processLoop()
rescue Interrupt
  #������ȯ����
end


end #module Gimite
