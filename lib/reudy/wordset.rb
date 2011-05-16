#Copyright (C) 2003 Gimite ���� <gimite@mx12.freecom.ne.jp>

#���ܸ�ʸ��������Ƚ���ѥ�����
require "kconv"
require "jcode"
require "fileutils"
require $REUDY_DIR+'/reudy_common'


module Gimite


#ñ�졣
class Word
  
  #�����Υ��饹�Υ��󥹥��󥹤�Marshal����¸�����Τǡ�
  #    ���ڤ˥��󥹥����ѿ�̾���Ѥ��ʤ�����

  def initialize(s, a= "", m= [])
    @str= s #ñ���ʸ����
    @author= a #ñ��򶵤����͡�
    @mids= m #����ñ���ޤ�ȯ�����ֹ档
  end
  
  def ==(other)
    return @str==other.str
  end
  
  def eql?(other)
    return @str==other.str
  end
  
  def hash()
    return @str.hash()
  end
  
  def <=>(other)
    return @str<=>other.str
  end
  
  def inspect()
    return "<Word: \""+str+"\">"
  end

  attr_accessor :str
  attr_accessor :author
  attr_accessor :mids
  
  #�Ť�̾�����ߴ����Τ��ᡣ
  alias msgNs mids
  alias msgNs= mids=
  
end


# ñ�콸
class WordSet
  
  include(Gimite)
  include(Enumerable)
  
  def initialize(innerFileName)
    @innerFileName= innerFileName
    @outerFileName= nil
    if File.exist?(@innerFileName)
      @innerFileTime= File.mtime(@innerFileName)
      Kernel.open(@innerFileName, "r") do |file|
        @words= Marshal.load(file)
      end
    else
      @innerFileTime= nil
      @words= []
    end
    @addedWords= []
  end
  
  #�����ե��������Ͽ���������ե���������Ƥ������ǡ�����ȿ�Ǥ��롣
  def updateByOuterFile(outerFileName, wtmlManager)
    @outerFileName= outerFileName
    return if !File.exists?(@outerFileName)
    return if @innerFileTime && @innerFileTime>=File.mtime(@outerFileName)
    jprint_to($stderr, @outerFileName+" ���ѹ����줿�褦�Ǥ���ñ����ɤ߹�����...\n")
    addedWords= @addedWords
    @addedWords= []
    isOldFormat= false
    n= 0
    Kernel.open(@outerFileName, "r") do |file|
      file.each_line() do |line|
        #�����ե��������ñ����ɲä��롣
        #�����ǡ�����ͭ�äƳ����ե������̵��ñ��ˤĤ��Ƥϡ����С������Ǥϲ��⤷�Ƥ��ʤ��Τ���ա�
        #data[1], data[2]��Ver.3.04�����Υǡ���������Ѥ�����˻Ȥ��롣
        str= line.chomp()
        next if str==""
        jprint_to($stderr, (n+1).to_s()+"����...\n") if (n+1)%100==0
        word= addWord(str)
        if word
          jprint_to($stderr, "ñ���"+word.str+"�פ��ɲ���...\n")
          wtmlManager.attachMsgList(word)
        end
        n+= 1
      end
    end
    #initialize��updateByOuterFile�δ֤��ɲä��줿ñ������ե��������¸��
    @addedWords= addedWords
    save()
  end
  
  #ñ����ɲ�
  def addWord(str, author= "")
    word= Word.new(str, author)
    i= 0
    while i<@words.size()
      break if str.index(@words[i].str)
      i+= 1
    end
    if @words[i] && @words[i].str==str
      return nil
    else
      @words[i, 0]= [word]
      @addedWords.push(word)
      return word
    end
  end
  
  #�ե��������¸
  def save()
    if @outerFileName
      Kernel.open(@outerFileName, "a") do |file|
        for word in @addedWords
          file.print(word.str+"\n")
        end
      end
      @addedWords= []
    end
    Kernel.open(@innerFileName, "w") do |file|
      Marshal.dump(@words, file)
    end
  end
  
  #ñ�쥤�ƥ졼��
  def each()
    @words.each() do |word|
      yield(word)
    end
  end
  
  #��Ȥ�ƥ����ȷ����ǽ��ϡ�
  def output(io)
    for word in @words
      io.print(word.str, "\t", word.author, "\t", word.mids.join(","), "\n")
    end
  end
  
  attr_reader :words
  
  private
  
  #��¸�Υե�����Ȥ��֤�ʤ��ե�����̾���롣
  def makeNewFileName(base)
    return base if !File.exist?(base)
    i= 2
    while true
      name= base+i.to_s()
      return name if !File.exist?(name)
      i+= 1
    end
  end
  
end


end #module Gimite
