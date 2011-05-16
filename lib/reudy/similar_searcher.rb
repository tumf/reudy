#Copyright (C) 2003 Gimite ���� <gimite@mx12.freecom.ne.jp>

#ʸ��������Ȥä����Ƚ�ꡣ

#���ܸ�ʸ��������Ƚ���ѥ�����
$REUDY_DIR= "." if !defined?($REUDY_DIR) #������ץȤ�����ǥ��쥯�ȥ�

require 'kconv'
require 'jcode'
require 'set'
require $REUDY_DIR+'/reudy_common'
require $REUDY_DIR+'/message_log'
require $REUDY_DIR+'/marshal_gdbm'


module Gimite


#���ȯ�������
class SimilarSearcher
  
=begin
  ʸ��@compLenʸ����1ʸ���㤤��ȯ�������ȯ���Ȥ��롣
  ���������Ҥ餬�ʤȰ����ε���Τߤ��оݡ�
  @tailMap�ϡ���ʸ��@compLenʸ���ȡ���������Ǥ�դ�1ʸ����ȴ����ʪ�פ򥭡��Ȥ���
  ȯ���ֹ��������ͤȤ��롣
  �㤨�С�10���ܤ���������ʬ����ޤ���Ǥ������פȤ���ȯ���ʤ顢
    @tailMap["�ޤ���Ǥ���"].include?(10)
    @tailMap["����Ǥ���"].include?(10)
    @tailMap["�ޤ�Ǥ���"].include?(10)
    @tailMap["�ޤ��Ǥ���"].include?(10)
    @tailMap["�ޤ��󤷤�"].include?(10)
    @tailMap["�ޤ���Ǥ�"].include?(10)
    @tailMap["�ޤ���Ǥ�"].include?(10)
  ������true�ˤʤ롣�����Ȥäơ�ʸ����Ʊ��or1ʸ���㤤��ȯ���פ�õ����
=end
  
  include(Gimite)
  
  def initialize(fileName, log)
    @log= log
    @log.addObserver(self)
    @compLen= 6#����оݤ�ʸ����Ĺ��
    makeDictionary(fileName)
  end
  
  #input����������ȯ�����Ф��ơ�ȯ���ֹ�������block��Ƥ֡�
  #ȯ���ν������̯�˥����ࡣ
  def eachSimilarMsg(input, &block)
    ws= normalizeMsg(input)
    return if ws.size()<=1
    if ws.size()>=@compLen
      wtail= ws[-@compLen..-1]#ʸ����
      randomEach(@tailMap[wtail.join("")], &block)
      for i in 0...@compLen
        #�����1ʸ��ȴ��������Ρ�
        randomEach(@tailMap[(wtail[0...i]+wtail[i+1..-1]).join("")], &block)
      end
    else
      randomEach(@tailMap[ws.join("")], &block)
    end
  end
  
  #cont�γ����ǤˤĤ��ơ�������ʽ����block��ƤӽФ���
  def randomEach(cont, &block)
    return if !cont
    cont= cont.dup()
    while cont.size()>0
      block.call(cont.delete_at(rand(cont.size())))
    end
  end
  
  #ȯ�����ɲä��줿��
  def onAddMsg()
    recordTail(@log.size()-1)
  end
  
  #�������ꥢ���줿��
  def onClearLog()
    @tailMap.clear()
  end
  
  #ʸ�������@tailMap�ˤ�������
  def makeDictionary(fileName)
    if $NO_GDBM
      jprint_to($stderr, "�ٹ�: Ruby/GDBM�����Ĥ���ޤ���Ruby/GDBM��̵���ȡ���������̤˾��񤷤ޤ���\n")
      @tailMap= {}
    else
      @tailMap= MarshalGDBM.new(fileName, 0666, GDBM::FAST)
    end
    if @tailMap.empty?()
      jprint_to($stderr, "ʸ������( "+fileName+" )�������...\n")
      for i in 0...@log.size()
        jprint_to($stderr, (i+1).to_s()+"����...\n") if (i+1)%1000==0
        recordTail(i)
      end
    end
  end
  
  #lineN�֤�ȯ����ʸ����Ͽ��
  def recordTail(lineN)
    ws= normalizeMsg(@log[lineN].body)
    return nil if ws.size()<=1
    if ws.size()>=@compLen
      wtail= ws[-@compLen..-1]#ʸ����
      addToTailMap(wtail, lineN)
      for i in 0...@compLen
        #�����1ʸ��ȴ��������Ρ�
        addToTailMap(wtail[0...i]+wtail[i+1..-1], lineN)
      end
    else
      addToTailMap(ws, lineN)
    end
  end
  
  #@tailMap���ɲá�
  def addToTailMap(wtail, lineN)
    tail= wtail.join("")
    lineNs= @tailMap[tail]
    if lineNs
      @tailMap[tail]= lineNs+[lineN]
    else
      @tailMap[tail]= [lineN]
    end
  end
  
  #ȯ������֤Ҥ餬�ʤȰ����ε���װʳ���ä�����������줹�롣
  def normalizeMsg(s)
    s= s.gsub(/[^��-�󡼡ݡ���\?!\.]+/, "")
    s= s.gsub(/��/, "?").gsub(/��/,"!").gsub(/[����+]/, "��")
    return s.split(//)
  end

end


if __FILE__==$0
  
  dir= ARGV[0]
  log= MessageLog.new(dir+"/log.dat")
  sim= SimilarSearcher.new(dir+"/similar.gdbm", log)
  sim.eachSimilarMsg(ARGV[1].toeuc()) do |mid|
    jprintf("[%d] %s\n", mid, log[mid].body)
  end
  
end


end #module Gimite


