#Copyright (C) 2003 Gimite ���� <gimite@mx12.freecom.ne.jp>

#���ܸ�ʸ��������Ƚ���ѥ�����
$KCODE= "EUC"
require 'kconv'
require 'jcode'
require $REUDY_DIR+'/tango-mgm'
require $REUDY_DIR+'/wordset'
require $REUDY_DIR+'/word_searcher'
require $REUDY_DIR+'/message_log'
require $REUDY_DIR+'/similar_searcher'
require $REUDY_DIR+'/word_associator'
require $REUDY_DIR+'/wtml_manager'
require $REUDY_DIR+'/attention_decider'
require $REUDY_DIR+'/response_estimator'
require $REUDY_DIR+'/version'
require $REUDY_DIR+'/reudy_common'


module Gimite


#�͹�̵ǽ���ǥ�
class Reudy
  
  include(Gimite)
  
  def initialize(dir, fixedSettings= {})
    @attention= nil
    
    #�С�����󥢥åץ����å���ɬ�פʤ顢�ǡ����򿷤����������Ѵ���
    ReudyVersion.new().checkDataVersion(dir)
    
    #������ɤ߹��ࡣ
    @fixedSettings= fixedSettings
    @settingPath= dir+"/setting.txt"
    loadSettings()
    @autoSave= settings("disable_auto_saving")!="true"
    
    #Ư���ԤΥ��֥�������ã���롣
    jprint_to($stderr, "��������...\n")
    @log= MessageLog.new(dir+"/log.dat")
    @log.addObserver(self)
    @log.sync= @autoSave
    jprint_to($stderr, "ñ�������...\n")
    @wordSet= WordSet.new(dir+"/words.dat")
    @wordSearcher= WordSearcher.new(@wordSet)
    @wtmlManager= WordToMessageListManager.new(@wordSet, @log, @wordSearcher)
    @extractor= WordExtractor.new(14, method(:onAddWord))
    @simSearcher= SimilarSearcher.new(dir+"/similar.gdbm", @log)
    @associator= WordAssociator.new(dir+"/assoc.txt")
    @attention= AttentionDecider.new()
    @attention.setParameter(attentionParameters())
    @resEst= ResponseEstimator.new(@log, @wordSearcher,
      method(:isUsableBaseMsg), method(:canAdoptWord))
    
    #����¾���󥹥����ѿ��ν������
    @client= nil
    @lastSpeachInput= nil
    @lastSpeach= nil
    @inputWords= []
    @newInputWords= []
    @recentUnusedCt= 100 #�Ƕ�n�Ĥ�ȯ�����оݤȤ��ʤ�
    @repeatProofCt= 50 #���nȯ���ǻȤä��١���ȯ���Ϻ����Ѥ��ʤ�
    @recentBaseMsgNs= Array.new(@repeatProofCt) #�Ƕ�Ȥä��١���ȯ���ֹ�
    @thoughtFile= open(dir+"/thought.txt", "a") #�׹Ͳ�����Ͽ����ե�����
    @thoughtFile.sync= true
    
    #�����ե����������å���
    @log.updateByOuterFile(dir+"/log.txt")
    @wordSet.updateByOuterFile(dir+"/words.txt", @wtmlManager)
    setWordAdoptBorder()
    #Kernel.open(dir+"/words.log", "w"){ |f| @wordSet.output(f) } #��
  end
  
  #�����ե����뤫�����
  def loadSettings()
    file= Kernel.open(@settingPath)
    @settings= {}
    file.each_line() do |line|
      if line.chomp()=~/^\s*(\S+)(\s.*)?$/
        @settings[$1]= $2 ? $2.strip() : ""
      end
    end
    file.close()
    @fixedSettings.each() do |key, val|
      @settings[key]= val
    end
    #�����ѿ��򹹿�
    @targetNickReg= Regexp.new(@settings["target_nick"] || "", Regexp::IGNORECASE)
      #����˥ޥå����ʤ�Nick��ȯ���ϡ��١���ȯ���Ȥ��ƻ�����ǽ
    s= @settings["forbidden_nick"]
    s= "(?!.*)" if !s || s==""
      #���ˤ�ޥå����ʤ�����ɽ���ΤĤ��
    @forbiddenNickReg= Regexp.new(s, Regexp::IGNORECASE)
      #����˥ޥå�����Nick��ȯ���ϡ��١���ȯ���Ȥ��ƻ�����ǽ
    @myNicks= settings("nicks").split(/\s*,\s*/)
    changeMode(settings("default_mode").to_i())
  end
  
  #����åȥ��饤����Ȥλ���
  attr_writer(:client)
  
  #����åȥ��֥��������Ѥ�����
  def settings(key)
    return @settings[key]
  end
  
  #�⡼�ɤ��ѹ�
  def changeMode(mode)
    return false if mode==@mode
    @mode= mode
    @attention.setParameter(attentionParameters()) if @attention
    updateStatus()
    return true
  end
  
  def updateStatus()
    @client.status= ["����", "����", nil, "����"][@mode] if @client
  end
  
  #����Ƚ����Ϳ����ѥ�᡼����
  def attentionParameters()
    case @mode
      when 0 #���ۥ⡼�ɡ�
        return { \
          :min     => 0.001, \
          :max     => 0.001, \
          :default => 0.001, \
          :called  => 0.001, \
          :self    => 0.0,   \
          :ignored => 0.0    \
        }
      when 1 #���ۥ⡼�ɡ�
        return { \
          :min     => 0.1, \
          :max     => 0.3, \
          :default => 0.1, \
          :called  => 1.1, \
          :self    => 0.005, \
          :ignored => 0.002 \
        }
      when 2 #�̾�⡼�ɡ�
        return { \
          :min     => 0.5, \
          :max     => 1.1, \
          :default => 0.5, \
          :called  => 1.1, \
          :self    => 0.3, \
          :ignored => 0.002 \
        }
      when 3 #����⡼�ɡ�
        return { \
          :min     => 0.8, \
          :max     => 1.1, \
          :default => 0.8, \
          :called  => 1.1, \
          :self    => 0.8, \
          :ignored => 0.01  \
        }
      when 4 #ɬ����������⡼�ɡ�
        return { \
          :min     => 1.1, \
          :max     => 1.1, \
          :default => 1.1, \
          :called  => 1.1, \
          :self    => 0.8, \
          :ignored => 0.003  \
        }
    end
  end
  
  #ñ�줬������¿���и����Ƥ����ִ��ʤɤ��оݤˤ��ʤ����Ȥ���
  #�ܡ��������@wordAdoptBorder��������
  def setWordAdoptBorder()
    msgCts= @wordSet.map(){ |w| w.mids.size() }.sort().reverse()
    if msgCts.size()==0
      @wordAdoptBorder= 0
    else
      @wordAdoptBorder= msgCts[msgCts.size()/50]
    end
  end
  
  #����ñ�줬�ִ��ʤɤ��оݤˤʤ뤫
  def canAdoptWord(word)
    return word.msgNs.size()<@wordAdoptBorder
  end
  
  #ȯ����١���ȯ���Ȥ��ƻ��Ѳ�ǽ����
  def isUsableBaseMsg(msgN)
    return false if msgN>=@log.size()
      #¸�ߤ��ʤ�ȯ����
    msg= @log[msgN]
    return if !msg
      #���ԡ�������줿ȯ���ʤɡ�
    nick= msg.fromNick
    return false if settings("teacher_mode")!="true" &&
          @log.size()>@recentUnusedCt && msgN>=@log.size()-@recentUnusedCt
      #ȯ�������������롣����οͥ⡼�ɤǤ�̵����
    return false if nick=="!"
      #��ʬ���Ȥ�ȯ����
    return false if !(nick=~@targetNickReg) || nick=~@forbiddenNickReg
      #����ȯ���Ԥ�ȯ���ϻȤ��ʤ���
    return false if @recentBaseMsgNs.index(msgN)
      #�Ƕ᤽�Υ١���ȯ����Ȥä���
    return true
  end
  
  #mid���ܤ�ȯ���ؤ��ֻ��ʤȻפ���ȯ���ˤˤĤ��ơ�[ȯ���ֹ�,�ֻ��餷��]���֤���
  #���������١���ȯ���Ȥ��ƻ��ѤǤ����Τ������оݡ�
  #���������Τ�̵�����[nil,0]���֤���
  def responseTo(mid, debug= false)
    if settings("teacher_mode")
      if isUsableBaseMsg(mid+1) && @log[mid].fromNick=="!input"
        return [mid+1, 20]
      else
        return [nil, 0]
      end
    else
      return @resEst.responseTo(mid, debug)
    end
  end
  
  #���ȯ�������ѤΥե��륿
  def similarSearchFilter(msgN)
    return responseTo(msgN)[0]!=nil
  end
  
  #sentence��μ�ʬ��Nick��target���֤������롣
  def replaceMyNicks(sentence, target)
    myNicksReg= Regexp.new(@myNicks.map(){ |n| Regexp.escape(n) }.join("|"))
    return sentence.gsub(myNicksReg){ target }
  end
  
  #����ʸ�Ϥ������ñ��򽦤���
  def pickUpInputWords(input)
    input= replaceMyNicks(input, " ")
    #���Ϥ˴ޤޤ��ñ������
    @newInputWords= @wordSearcher.searchWords(input).select(){ |w| canAdoptWord(w) }
    #���Ϥ�ñ�줬̵�����ϡ��������ϸ���������ѹ�
    if @newInputWords.size()==0 && rand(50)==0
      word= @wordSet.words[rand(@wordSet.words.size())]
      @newInputWords= [word] if canAdoptWord(word)
    end
    #Ϣ�ۤ����ñ����ɲ�
    assocWords= @newInputWords.map(){ |w| @associator.associate(w.str) } \
      .select(){ |s| s }.map(){ |s| Word.new(s) }
    @newInputWords+= assocWords
    #���ϸ�ι���
    if @newInputWords.size()>0
      if rand(5)!=0
        @inputWords= @newInputWords
      else
        @inputWords+= @newInputWords
      end
    end
  end
  
  #��ñ������ʸ�����פ���ȯ������Ѥ��뤫����롣
  #��ñ������פ�������ȯ���Ϻ��Ѥ���ˤ����褦�ˤ��롣
  #ñ�줬̵��ȯ���ϳμ¤˺��Ѥ��졢���Υ᥽�åɤϻȤ��ʤ���
  def shouldAdoptSaying(additionalLen)
    case additionalLen
      when 0
        return false
      when 1
        return rand()<0.125
      when 2, 3
        return rand()<0.25
      when 4...7
        return rand()<0.75
      else
        return true
    end
  end
  
  #inputWords���ñ���ޤ��ȯ���ˤĤ��ơ��֥�å��򷫤��֤���
  #�֥�å���ȯ���ֹ������˼�롣
  #ȯ���ν���ϥ����ࡣ
  def eachMsgContainingWords(inputWords, &block)
    words= inputWords.clone()
    while words.size()>0
      word= words.delete_at(rand(words.size()))
      msgNs= word.msgNs.clone()
      while msgNs.size()>0
        block.call(msgNs.delete_at(rand(msgNs.size())))
      end
    end
  end
  
  #���̤�ñ������ȯ���ȡ������ֻ���ȯ���ֹ���֤���
  #Ŭ�ڤʤ�Τ�̵����С�[nil, nil]��
  def getBaseMsgUsingKeyword(inputWords)
    maxMid= maxResMid= nil
    maxProb= 0
    i= 0
    eachMsgContainingWords(inputWords) do |mid|
      (resMid, prob)= responseTo(mid, true)
      if resMid
        if prob>maxProb
          maxMid= mid
          maxResMid= resMid
          maxProb= prob
        end
        i+=1
        break if i>=5
      end
    end
    dprint("����ñ��ȯ��", @log[maxMid].body) if maxMid
    return [maxMid, maxResMid]
  end
  
  #���ȯ���ȡ������ֻ���ȯ���ֹ���֤���
  #Ŭ�ڤʤ�Τ�̵����С�[nil, nil]��
  def getBaseMsgUsingSimilarity(sentence)
    maxMid= maxResMid= nil
    maxProb= 0
    i= 0
    @simSearcher.eachSimilarMsg(sentence) do |mid|
      (resMid, prob)= responseTo(mid, true)
      if resMid
        if prob>maxProb
          maxMid= mid
          maxResMid= resMid
          maxProb= prob
        end
        i+=1
        break if i>=5
      end
    end
    dprint("���ȯ��", @log[maxMid].body, maxProb) if maxMid
    return [maxMid, maxResMid]
  end
  
  #msgN�֤�ȯ����Ȥä��١���ȯ����ʸ����
  def getBaseMsgStr(msgN)
    str= @log[msgN].body
    #ʸ�θ�Ⱦ��[���]��ͭ��С����θ��ϥ��åȡ�
    str= $1 if str=~/^(.*)[���]/ && $1.length()>=str.length()/2
    return str
  end
  
  #base��δ���ñ���newWords���ִ�������Τ��֤���
  #toForce��false�ξ�硢û������ʸ�ϤˤʤäƤ��ޤä�����nil���֤���
  def replaceWords(base, newWords, toForce)
    #base��ñ��������ʬ�䤷��parts�ˤ��롣
    parts= [base]
    @wordSet.each() do |word|
      if @wordSearcher.hasWord(base, word) && canAdoptWord(word)
        newParts= []
        for i in 0...parts.size()
          part= parts[i]
          if i%2==0
            while part=~Regexp.new("^(.*?)"+Regexp.escape(word.str)+"(.*)$")
              newParts.push($1, word.str)
              part= $2
            end
          end
          newParts.push(part)
        end
        parts= newParts
      end
    end
    #��Ƭ����2���ܰʹߤ�ñ���ľ���ǥ��åȤ����ꤷ�ʤ��ä��ꡣ
    if parts.size()>1
      cutPos= rand((parts.size()-1)/2)*2+1
      parts= [""]+parts[cutPos..-1] if cutPos>1
    end
    wordCt= (parts.size()-1)/2
    #ñ��������ʸ�Ϥ�û�������ΤϤ����Ψ�ǵѲ���
    if wordCt>0 && !toForce
      len= sigma(0...parts.size()){ |i| i%2==0 ? parts[i].jlength() : 0 }
      return nil if !shouldAdoptSaying(len)
    end
    #ñ����ִ���
    newWords= newWords.clone()
    while newWords.size()>0
      oldWordStr= parts[rand(wordCt)*2+1]
      newWordStr= newWords.delete_at(rand(newWords.size())).str
      for i in 0...wordCt
        parts[i*2+1]= newWordStr if parts[i*2+1]==oldWordStr
      end
      break if rand()<0.5
    end
    output= parts.join("")
    #�Ĥ���̤��Ĥä����˳�����̤��䤦��
    #����ҤˤʤäƤ��ꤷ�����Τ�ʤ���
    case output
      when /^[^�֡�]*��/
        output= "��"+output
      when /^[^�ʡ�]*��/
        output= "��"+output
      when /^[^()]*\)/
        output= "("+output
    end
    return output
  end
  
  #��ͳȯ������������Ͽ���롣
  def recordThought(pattern, simMid, resMid, words, output)
    wordsStr= words.map(){ |w| w.str }.join(",")
    row= [@log.size-1, pattern, simMid, resMid, wordsStr, output]
    @thoughtFile.print(row.join("\t")+"\n")
  end
  
  #��ͳ��ȯ�����롣
  def speakFreely(fromNick, origInput, mustRespond)
    input= replaceMyNicks(origInput, " ")
    output= nil
    simMsgN, baseMsgN= getBaseMsgUsingSimilarity(input)
      #�ޤ����������Ȥäƥ١���ȯ������롣
    if @newInputWords.size()>0
      if baseMsgN
        #�ѥ�����1: ñ��ͭ������ȯ��ͭ�ꡣ
        output= replaceWords(getBaseMsgStr(baseMsgN), @inputWords, mustRespond)
        recordThought(1, simMsgN, baseMsgN, @newInputWords, output) if output
      else
        #�ѥ�����2: ñ��ͭ������ȯ��̵����
        simMsgN, baseMsgN= getBaseMsgUsingKeyword(@newInputWords)
        output= getBaseMsgStr(baseMsgN) if baseMsgN
        recordThought(2, simMsgN, baseMsgN, @newInputWords, output) if output
      end
    else
      if baseMsgN
        #�ѥ�����3: ñ��̵�������ȯ��ͭ�ꡣ
        output= getBaseMsgStr(baseMsgN)
        if !@wordSearcher.searchWords(output).empty?()
          if mustRespond
            output= replaceWords(output, @inputWords, true)
          else
            output= nil
          end
        end
        recordThought(3, simMsgN, baseMsgN, @inputWords, output) if output
      else
        #�ѥ�����4: ñ��̵�������ȯ��̵����
        if mustRespond && @inputWords.size()>0
          #�ǿ��Ǥʤ����ϸ��Ȥäƥ�����ɸ�����
          simMsgN, baseMsgN= getBaseMsgUsingKeyword(@inputWords)
          output= getBaseMsgStr(baseMsgN) if baseMsgN
          recordThought(4, simMsgN, baseMsgN, @inputWords, output) if output
        end
      end
    end
    if mustRespond && !output
      #������ȯ��
      2000.times() do
        #�ϥ󥰤�Τ��ɤ����ᡢ̵�¥롼�פˤϤ��ʤ�
        msgN= rand(@log.size())
        if isUsableBaseMsg(msgN)
          baseMsgN= msgN
          output= getBaseMsgStr(baseMsgN)
          break
        end
      end
    end
    if output
      #�Ƕ�Ȥä��١���ȯ���򹹿�
      @recentBaseMsgNs.shift()
      @recentBaseMsgNs.push(baseMsgN)
      #ȯ����μ�ʬ��Nick������Nick���Ѵ�
      output= replaceMyNicks(output, fromNick)
      #�ºݤ�ȯ����
      speak(origInput, output)
    end
  end
  
  #��ͳȯ�äȤ���ȯ�����롣
  def speak(input, output)
    @lastSpeachInput= input
    @lastSpeach= output
    studyMsg("!", output) #��ʬ��ȯ���򵭲����롣
    @client.outputInfo("��"+input+"�פ�ȿ��������") if settings("teacher_mode")=="true"
    @attention.onSelfSpeak(@wordSearcher.searchWords(output))
    @client.speak(output)
  end
  
  #�귿���ޥ�ɤ������
  #���Ϥ��귿���ޥ�ɤǤ���б�����å��������֤���
  #�����Ǥʤ����nil���֤�������������λ���ޥ�ɤ��ä���:exit���֤���
  def processCommand(input)
    if input=~/����򹹿�/
      loadSettings()
      return "����򹹿����ޤ�����"
    end
    return nil if settings("disable_commands")=="true"
      #���ޥ�ɤ��ػߤ���Ƥ�
    if input=~/�ۤ�|�ۤ�ʤ���|�ۤäƤ�|���ۥ⡼��/
      return changeMode(0) ? "���ۥ⡼�ɤ��ڤ��ؤ��롣" : ""
    elsif input=~/���ۥ⡼��/
      return changeMode(1) ? "���ۥ⡼�ɤ��ڤ��ؤ��롣" : ""
    elsif input=~/�̾�⡼��/
      return changeMode(2) ? "�̾�⡼�ɤ��ڤ��ؤ��롣" : ""
    elsif input=~/����⡼��/
      return changeMode(3) ? "����⡼�ɤ��ڤ��ؤ��롣" : ""
    elsif input=~/�٤���ɤ���|��λ���ʤ���/
      save()
      @client.exit()
      return :exit
    elsif input=~/([\x21-\x7e]+)��(���|���|ʪ)(�ޤ�|����)/
      begin
        @targetNickReg= Regexp.new($1, Regexp::IGNORECASE)
        return $1+"�Τ�Τޤͤ򳫻Ϥ��롣"
      rescue RegexpError
        return "����ɽ�����ְ�äƤ��롣"
      end
    elsif input=~/(���|���|ʪ)(�ޤ�|����).*(���|���|��λ|����|����)/
      @targetNickReg= Regexp.new("", Regexp::IGNORECASE)
      return "ʪ�ޤͤ������롣"
    elsif input=~/�Ф�������|����ä�/ && input=~/ï/ && input=~/��(.+?)��/
      wordStr= $1
      wordIdx= @wordSet.words.index(Word.new(wordStr))
      if (wordIdx)
        author= @wordSet.words[wordIdx].author
        if (author.length()>0)
          return author+"����ˡ���"+wordStr
        else
          return "�Գ��������"+wordStr
        end
      else
        return "����ñ��ϵ������Ƥ��ʤ���"
      end
    end
    return nil #�귿���ޥ�ɤǤϤʤ���
  end
  
  #�̾��ȯ����ؽ���
  def studyMsg(fromNick, input)
    return if settings("disable_studying")=="true"
    if settings("teacher_mode")=="true"
      @fromNick= fromNick
      @extractor.processLine(input) #ñ�����ФΤߡ�
    else
      @log.addMsg(fromNick, input)
    end
  end
  
  #�ؽ����Ƥ��ư��¸
  def save()
    @wordSet.save()
  end
  
  #����ȯ�����ɲä��줿��
  def onAddMsg()
    msg= @log[@log.size()-1]
    @fromNick= msg.fromNick if msg.fromNick!="!"
    if settings("teacher_mode")!="true"
      #��οͥ⡼�ɤǤϡ�ñ�����Ф��̤ˤ�롣
      @extractor.processLine(msg.body)
    end
    #@extractor�ʳ��Υ��֥������Ȥϼ��Ϥ�@log��ƻ뤷�Ƥ���Τǡ�
    #�����ǲ�������ɬ�פ�̵����
  end
  
  #�������ꥢ���줿��
  def onClearLog
  end
  
  #ñ�줬�ɲä��줿
  def onAddWord(wordStr)
    if @wordSet.addWord(wordStr, @fromNick)
      if @client
        @client.outputInfo("ñ���"+wordStr+"�פ򵭲�������")
      else
        jprint("ñ���"+wordStr+"�פ򵭲�������\n")
      end
      @wordSet.save() if @autoSave
    end
  end
  
  #��³�򳫻Ϥ���
  def onBeginConnecting()
    jprint_to($stderr, "��³����...\n")
  end
  
  #��ʬ����������
  def onSelfJoin()
    updateStatus()
  end
  
  #¾�ͤ���������
  def onOtherJoin(fromNick)
  end

  #¾�ͤ�ȯ��������
  def onOtherSpeak(fromNick, input, shouldIgnore= false)
    output= nil #ȯ����
    isCalled= there_exists?(@myNicks){ |n| input.index(n) }
    output= processCommand(input) if isCalled
    if output
      @client.speak(output) if output!=:exit && !output.empty?
    else #�귿���ޥ�ɤǤϤʤ���
      @lastSpeach= input
      studyMsg(fromNick, input)
      pickUpInputWords(input)
      prob= @attention.onOtherSpeak(fromNick, input, isCalled)
        #ȯ��Ψ����롣
      dprint("ȯ��Ψ", prob, @attention.to_s())
      if (!shouldIgnore && rand()<prob) || prob>1.0
        #��ͳȯ�á�
        speakFreely(fromNick, input, prob>1.0)
      end
    end
  end
  
  #����ȯ����info�Ǥ�ȯ���ˤ����ä���
  def onControlMsg(str)
    return if settings("disable_studying")=="true" || settings("teacher_mode")!="true"
    if str=~/^(.+)����(.+)$/
      input= $1
      output= $2
    else
      input= @lastSpeachInput
      output= str
    end
    if input
      @log.addMsg("!input", input)
      @log.addMsg("!teacher", output)
      if @client
        @client.outputInfo("ȿ����%s����%s�פ�ؽ�������" % [input, output])
      end
    end
  end
  
  #���ۤ����Ф餯³������
  def onSilent()
    prob= @attention.onSilent()
    #dprint("ȯ��Ψ", @attention.to_s())
    if rand()<prob && @lastSpeach
      #��ȯȯ����
      speakFreely(@fromNick, @lastSpeach, prob>rand()*1.1)
        #��ȯȯ���Ǥϡ�ȯ����̵���¤ꡢƱ��ȯ�����оݤˤ��ĤŤ��롣
        #���Τ�������������٤�ʤ��ʤ�Τ��ɤ����ᡢ����mustRespond��ON�ˤ��롣
    end
  end
  
end


end #module Gimite

