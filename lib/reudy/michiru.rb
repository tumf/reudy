#Copyright (C) 2003 Gimite ���� <gimite@mx12.freecom.ne.jp>

#���ܸ�ʸ��������Ƚ���ѥ�����
$KCODE= "EUC"
require 'kconv'
require 'jcode'
require $REUDY_DIR+'/tango-mgm'
require $REUDY_DIR+'/wordset'
require $REUDY_DIR+'/word_searcher'
require $REUDY_DIR+'/word_associator'
require $REUDY_DIR+'/message_log'
require $REUDY_DIR+'/similar_searcher5'
require $REUDY_DIR+'/reudy_common'


module Gimite


#�͹�̵ǽ�ߥ���
class Michiru
  
  include(Gimite)
  
  def initialize(dir, fixedSettings= {})
    @recentWordsCt= 40 #�Ƕ�Ȥä�ñ��򲿸ĵ������뤫
    @fixedSettings= fixedSettings
    @settingPath= dir+"/setting.txt"
    loadSettings()
    jprint("ñ�������...\n")
    @wordSet= WordSet.new(dir+"/words.txt")
    @log= MessageLog.new(dir+"/log.txt", @autoSave)
    jprint("��������ѥǡ���������...\n")
    @simSearcher= SimilarSearcher.new(dir+"/similar.gdbm", @log)
    @wordSearcher= WordSearcher.new(@wordSet)
    @extractor= WordExtractor.new(14, method(:onAddWord))
    @associator= WordAssociator.new(dir+"/assoc.txt")
    @recentWordStrs= [] #�Ƕ�Ȥä�ñ��
    @similarNicksMap= {} #Nick�����οͤκǶ��ȯ�������ȯ����ȯ���ԤΥꥹ��
  end
  
  #�����ե����뤫�����
  def loadSettings()
    file= Kernel.open(@settingPath)
    @settings= Hash.new()
    file.each_line() do |line|
      ss= line.chop().split(/\t/, 2)
      @settings[ss[0]]= ss[1]
    end
    file.close()
    @fixedSettings.each() do |key, val|
      @settings[key]= val
    end
    @myNicks= settings("nicks").split(",")
    @autoSave= settings("disable_auto_saving")!="true"
  end
  
  #����åȥ��饤����Ȥλ���
  attr_writer(:client)
  
  #����åȥ��֥��������Ѥ�����
  def settings(key)
    return @settings[key]
  end
  
  #Nick������Nick���Ѥ���
  def replaceNick(sentence, fromNick)
    nickReg= @myNicks.map(){ |x| Regexp.escape(x) }.join("|")
    return sentence.gsub(Regexp.new(nickReg), fromNick)
  end
  
  #�ֺǶ�Ȥ�줿ñ��פ��ɲ�
  def addRecentWordStr(wordStr)
    @recentWordStrs.push(wordStr)
    @recentWordStrs.shift() if @recentWordStrs.size()>@recentWordsCt
  end
  
  #���ϸ줫���Ϣ�ۤ�ȯ���ˤ���
  def associate()
    inputWordStr= @inputWords[rand(@inputWords.size())].str
    assocWordStrs= @associator.associateAll(inputWordStr)
    return nil if !assocWordStrs
    outputWordStr= nil
    for wordStr in assocWordStrs
      if !@recentWordStrs.include?(wordStr)
        outputWordStr= wordStr
        break
      end
    end
    if outputWordStr
      addRecentWordStr(inputWordStr)
      addRecentWordStr(outputWordStr)
      return inputWordStr+"��"+outputWordStr+"�Ǥ���"
    else
      return nil
    end
  end
  
  #����οͤ���οͤ�������
  def innerPeople(nick)
    nicks= @similarNicksMap[nick]
    if !nicks || nicks.size()==0
      return nick+"����οͤϤ��ޤ���"
    else
      nicks0= nicks.uniq().sort().reverse()
      str= ""
      for nick0 in nicks0
        ct= nicks.select(){ |x| x==nick0 }.size()
        str+= format("%s(%d%%) ", nick0, ct*100/nicks.size())
      end
      return nick+"����οͤ� "+str+"�Ǥ���"
    end
  end
  
  #�ؽ�����
  def study(input)
    @extractor.processLine(input)
    @log.addMsg(@fromNick, input)
  end
  
  #���ȯ�������ѥե��륿
  def similarFilter(lineN)
    return true
  end
  
  #���ȯ���ǡ��������Ѥ���
  def storeSimilarData(fromNick, input)
    data= @simSearcher.searchSimilarMsg(input, method(:similarFilter))
    return if !data
    lineN= data[0]
    nicks= @similarNicksMap[fromNick]
    nicks= [] if !nicks
    nicks.push(@log[lineN].fromNick)
    dprint("���ȯ��", @log[lineN].fromNick, @log[lineN].body)
    nicks.shift() if nicks.size()>10
    @similarNicksMap[fromNick]= nicks
  end
  
  #ñ�줬�ɲä��줿
  def onAddWord(wordStr)
    if @wordSet.addWord(wordStr, @fromNick)
#      @client.outputInfo("ñ���"+wordStr+"�פ򵭲�������")
      @wordSet.save() if @autoSave
    end
  end
  
  #��³�򳫻Ϥ���
  def onBeginConnecting()
    jprint("��³����...\n")
  end
  
  #��ʬ����������
  def onSelfJoin()
  end
  
  #¾�ͤ���������
  def onOtherJoin(fromNick)
  end

  #¾�ͤ�ȯ������
  def onOtherSpeak(fromNick, input)
    @fromNick= fromNick
    output= nil #ȯ��
    isCalled= false
    @myNicks.each() do |nick|
      isCalled= true if (input.index(nick))
    end
    storeSimilarData(fromNick, input)
    study(input) if settings("disable_studying")!="true"
    @inputWords= @wordSearcher.searchWords(input)
    @inputWords.delete_if(){ |word| @myNicks.include?(word.str) }
    if input=~/([-a-zA-Z0-9_]+)����ο�/
      output= innerPeople($1)
    elsif input=~/��.*�Ǥ���(��|��)?\s*/
      output= "�ؤ���"
    elsif (isCalled || rand()<0.1) && @inputWords.size()>0
      #����ñ�줫��Ϣ�ۤ���
      output= associate()
    end
    if isCalled && !output
      #���䤬ʬ����ʤ��ä����ϡ����Τޤ޿֤��֤�
      output= replaceNick(input, fromNick)
    end
    if output
      @client.speak(output)
    end
  end
  
end


end #module Gimite

