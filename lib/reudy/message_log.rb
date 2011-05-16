#Copyright (C) 2003 Gimite ���� <gimite@mx12.freecom.ne.jp>

#���ܸ�ʸ��������Ƚ���ѥ�����
$KCODE= "EUC"
require 'kconv'
require 'jcode'
require $REUDY_DIR+'/reudy_common'


module Gimite


#�ġ���ȯ��
class Message

  def initialize(fromNick_, body_)
    @fromNick= fromNick_
    @body= body_
  end

  attr_accessor :fromNick
  attr_accessor :body

end


#ȯ����
class MessageLog
  
  include(Gimite)
  
  @enable_update_check= true
  class << self
    attr_accessor(:enable_update_check)
  end
  
  def initialize(innerFileName)
    @innerFileName= innerFileName
    @observers= []
    @msgPoses= [] #�ե������γƹԤ���Ƭ�ΰ��֡�
    @outerFile= nil
    @sync= true
    addHeadNoticeToInnerFile() if !File.exist?(@innerFileName)
    loadFromInnerFile()
    #ȯ�����ɲä������ơ������ե�����򳫤��äѤʤ��ˤ��롣
    @innerFile= Kernel.open(@innerFileName, File::RDWR | File::APPEND)
    @innerFile.sync= sync
  end
  
  #�ѻ��Ԥ��ɲá�
  def addObserver(*observers)
    @observers+= observers
  end
  
  #�����ե��������Ͽ���������ե���������Ƥ������ǡ�����ȿ�Ǥ��롣
  def updateByOuterFile(outerFileName)
    msg= nil
    isAdded= false
    if size()==0
      msg= @innerFileName+" ��ͭ��ޤ��󡣺������ޤ�...\n"
      isAdded= true
    elsif MessageLog.enable_update_check && File.mtime(outerFileName) > File.mtime(@innerFileName)
      msg= outerFileName+" ���ѹ����줿�褦�Ǥ���Ĵ����...\n"
    end
    if msg
      jprint_to($stderr, msg)
      syncBak= sync
      sync= false
      #�����ե�����������ǡ�������Ӥ����ɲä�ͭ����ɲä��롣
      n= 0
      eachMsgInFile(outerFileName) do |fromNick, body|
        if n>=size()
          if !isAdded
            jprint_to($stderr, outerFileName+" ���ɲä��줿�����ɤ߹�����...\n")
            isAdded= true
          end
          jprint_to($stderr, (n+1).to_s()+"����...\n") if (n+1)%100==0
          addMsg(fromNick, body, false)
        else
          jprint_to($stderr, (n+1).to_s()+"����...\n") if (n+1)%10000==0
          break if fromNick!=self[n].fromNick || body!=self[n].body
        end
        n+= 1
      end
      #���椬�Խ�����Ƥ��顢�����ǡ�����줫����ľ����
      if n<size()
        jprint_to($stderr, outerFileName \
          +" �����椬�ѹ�����Ƥ��ޤ��������ǡ�������ľ���ޤ�...\n")
        clear()
        n= 0
        eachMsgInFile(outerFileName) do |fromNick, body|
          jprint_to($stderr, (n+1).to_s()+"����...\n") if (n+1)%100==0
          addMsg(fromNick, body, false)
          n+= 1
        end
      end
      sync= syncBak
    end
    #ȯ�����ɲä������ơ������ե�����򳫤��äѤʤ��ˤ��롣
    @outerFile= open(outerFileName, "a")
    @outerFile.sync= true
  end
  
  #n���ܤ�ȯ��
  def [](n)
    if @msgPoses[n]
      @innerFile.pos= @msgPoses[n]
      line= @innerFile.gets()
      @innerFile.seek(0, IO::SEEK_END)
      if line && line.chomp()=~/(.*)\t(.*)/
        return Message.new($1, $2)
      end
    end
    return nil
  end
  
  #ȯ���ο�
  def size()
    return @msgPoses.size()
  end
  
  #ȯ�����ɲ�
  def addMsg(fromNick, body, toOuter= true)
    @innerFile.seek(0, IO::SEEK_END)
    @msgPoses.push(@innerFile.pos)
    @outerFile.print(fromNick+"\t"+body+"\n") if toOuter && @outerFile
    @innerFile.print(fromNick+"\t"+body+"\n")
    for observer in @observers
      observer.onAddMsg()
    end
  end
  
  #�����ե�����ν���Ʊ���⡼�ɡ�
  def sync
    return @sync
  end
  
  #�����ե�����ν���Ʊ���⡼�ɤ��ѹ����롣
  def sync=(s)
    @sync= s
    @innerFile.sync= s if @innerFile
  end
  
  #���ե�����򥯥���
  def close()
    @file.close()
  end
  
  private
  
  #�����ե��������Ƭ����ս񤭤�񤤤Ȥ���
  def addHeadNoticeToInnerFile()
    Kernel.open(@innerFileName, "a") do |f|
      f.print("��������������������������������������������������������������������������������������\n")
      f.print("�����������Υե�����ϥ��ǥ������ǻȤ���ǡ����Ǥ���                      ��������\n")
      f.print("�������������Խ�����ˤϡ����Υե�����ǤϤʤ���log.txt���Խ����Ƥ��������� ��������\n")
      f.print("�����������Υե�������Խ�����ȡ��ǡ���������ޤ���                          ��������\n")
      f.print("��������������������������������������������������������������������������������������\n")
    end
  end
  
  #���������ե����뤫����ɡ�
  def loadFromInnerFile()
    Kernel.open(@innerFileName, "a").close() #�ե����뤬̵����к�����
    Kernel.open(@innerFileName, "r") do |file|
      pos= 0
      while line= file.gets()
        @msgPoses.push(pos) if line.chomp()=~/(.*)\t(.*)/
        pos= file.pos
      end
    end
  end
  
  #���ե�������γ�ȯ���ˤĤ��Ʒ����֤���
  #�֥�å����Ϥ��������� (ȯ����,����)
  def eachMsgInFile(fileName, &block)
    return if !File.exist?(fileName)
    Kernel.open(fileName, "r") do |file|
      file.each_line() do |line|
        block.call($1, $2) if line.chomp()=~/(.*)\t(.*)/
      end
    end
  end
  
  #�����ǡ����򥯥ꥢ
  def clear()
    for observer in @observers
      observer.onClearLog()
    end
    @msgPoses= []
    @innerFile.close() if @innerFile
    @innerFile= open(@innerFileName, File::RDWR | File::CREAT | File::TRUNC)
    @innerFile.sync= sync
  end
  
end


end #module Gimite


