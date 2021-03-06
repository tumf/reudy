#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>

#日本語文字コード判定用コメント
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


#人工無能ロイディ
class Reudy
  
  include(Gimite)
  
  def initialize(dir, fixedSettings= {})
    @attention= nil
    
    #バージョンアップチェック。必要なら、データを新しい形式に変換。
    ReudyVersion.new().checkDataVersion(dir)
    
    #設定を読み込む。
    @fixedSettings= fixedSettings
    @settingPath= dir+"/setting.txt"
    loadSettings()
    @autoSave= settings("disable_auto_saving")!="true"
    
    #働き者のオブジェクト達を作る。
    jprint_to($stderr, "ログロード中...\n")
    @log= MessageLog.new(dir+"/log.dat")
    @log.addObserver(self)
    @log.sync= @autoSave
    jprint_to($stderr, "単語ロード中...\n")
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
    
    #その他インスタンス変数の初期化。
    @client= nil
    @lastSpeachInput= nil
    @lastSpeach= nil
    @inputWords= []
    @newInputWords= []
    @recentUnusedCt= 100 #最近n個の発言は対象としない
    @repeatProofCt= 50 #過去n発言で使ったベース発言は再利用しない
    @recentBaseMsgNs= Array.new(@repeatProofCt) #最近使ったベース発言番号
    @thoughtFile= open(dir+"/thought.txt", "a") #思考過程を記録するファイル
    @thoughtFile.sync= true
    
    #外部ファイルをチェック。
    @log.updateByOuterFile(dir+"/log.txt")
    @wordSet.updateByOuterFile(dir+"/words.txt", @wtmlManager)
    setWordAdoptBorder()
    #Kernel.open(dir+"/words.log", "w"){ |f| @wordSet.output(f) } #仮
  end
  
  #設定をファイルからロード
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
    #メンバ変数を更新
    @targetNickReg= Regexp.new(@settings["target_nick"] || "", Regexp::IGNORECASE)
      #これにマッチしないNickの発言は、ベース発言として使用不能
    s= @settings["forbidden_nick"]
    s= "(?!.*)" if !s || s==""
      #何にもマッチしない正規表現のつもり
    @forbiddenNickReg= Regexp.new(s, Regexp::IGNORECASE)
      #これにマッチするNickの発言は、ベース発言として使用不能
    @myNicks= settings("nicks").split(/\s*,\s*/)
    changeMode(settings("default_mode").to_i())
  end
  
  #チャットクライアントの指定
  attr_writer(:client)
  
  #チャットオブジェクト用の設定
  def settings(key)
    return @settings[key]
  end
  
  #モードを変更
  def changeMode(mode)
    return false if mode==@mode
    @mode= mode
    @attention.setParameter(attentionParameters()) if @attention
    updateStatus()
    return true
  end
  
  def updateStatus()
    @client.status= ["沈黙", "寡黙", nil, "饒舌"][@mode] if @client
  end
  
  #注目判定器に与えるパラメータ。
  def attentionParameters()
    case @mode
      when 0 #沈黙モード。
        return { \
          :min     => 0.001, \
          :max     => 0.001, \
          :default => 0.001, \
          :called  => 0.001, \
          :self    => 0.0,   \
          :ignored => 0.0    \
        }
      when 1 #寡黙モード。
        return { \
          :min     => 0.1, \
          :max     => 0.3, \
          :default => 0.1, \
          :called  => 1.1, \
          :self    => 0.005, \
          :ignored => 0.002 \
        }
      when 2 #通常モード。
        return { \
          :min     => 0.5, \
          :max     => 1.1, \
          :default => 0.5, \
          :called  => 1.1, \
          :self    => 0.3, \
          :ignored => 0.002 \
        }
      when 3 #饒舌モード。
        return { \
          :min     => 0.8, \
          :max     => 1.1, \
          :default => 0.8, \
          :called  => 1.1, \
          :self    => 0.8, \
          :ignored => 0.01  \
        }
      when 4 #必ず応答するモード。
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
  
  #単語がこれより多く出現してたら置換などの対象にしない、という
  #ボーダを求めて@wordAdoptBorderに代入。
  def setWordAdoptBorder()
    msgCts= @wordSet.map(){ |w| w.mids.size() }.sort().reverse()
    if msgCts.size()==0
      @wordAdoptBorder= 0
    else
      @wordAdoptBorder= msgCts[msgCts.size()/50]
    end
  end
  
  #その単語が置換などの対象になるか
  def canAdoptWord(word)
    return word.msgNs.size()<@wordAdoptBorder
  end
  
  #発言をベース発言として使用可能か。
  def isUsableBaseMsg(msgN)
    return false if msgN>=@log.size()
      #存在しない発言。
    msg= @log[msgN]
    return if !msg
      #空行。削除された発言など。
    nick= msg.fromNick
    return false if settings("teacher_mode")!="true" &&
          @log.size()>@recentUnusedCt && msgN>=@log.size()-@recentUnusedCt
      #発言が新しすぎる。（中の人モードでは無効）
    return false if nick=="!"
      #自分自身の発言。
    return false if !(nick=~@targetNickReg) || nick=~@forbiddenNickReg
      #この発言者の発言は使えない。
    return false if @recentBaseMsgNs.index(msgN)
      #最近そのベース発言を使った。
    return true
  end
  
  #mid番目の発言への返事（と思われる発言）について、[発言番号,返事らしさ]を返す。
  #ただし、ベース発言として使用できるものだけが対象。
  #該当するものが無ければ[nil,0]を返す。
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
  
  #類似発言検索用のフィルタ
  def similarSearchFilter(msgN)
    return responseTo(msgN)[0]!=nil
  end
  
  #sentence中の自分のNickをtargetに置き換える。
  def replaceMyNicks(sentence, target)
    myNicksReg= Regexp.new(@myNicks.map(){ |n| Regexp.escape(n) }.join("|"))
    return sentence.gsub(myNicksReg){ target }
  end
  
  #入力文章から既知単語を拾う。
  def pickUpInputWords(input)
    input= replaceMyNicks(input, " ")
    #入力に含まれる単語を列挙
    @newInputWords= @wordSearcher.searchWords(input).select(){ |w| canAdoptWord(w) }
    #入力に単語が無い場合は、時々入力語をランダムに変更
    if @newInputWords.size()==0 && rand(50)==0
      word= @wordSet.words[rand(@wordSet.words.size())]
      @newInputWords= [word] if canAdoptWord(word)
    end
    #連想される単語を追加
    assocWords= @newInputWords.map(){ |w| @associator.associate(w.str) } \
      .select(){ |s| s }.map(){ |s| Word.new(s) }
    @newInputWords+= assocWords
    #入力語の更新
    if @newInputWords.size()>0
      if rand(5)!=0
        @inputWords= @newInputWords
      else
        @inputWords+= @newInputWords
      end
    end
  end
  
  #「単語を除く文字数」から発言を採用するかを決める。
  #「単語だけ」に等しい発言は採用されにくいようにする。
  #単語が無い発言は確実に採用され、このメソッドは使われない。
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
  
  #inputWords中の単語を含む各発言について、ブロックを繰り返す。
  #ブロックは発言番号を引数に取る。
  #発言の順序はランダム。
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
  
  #共通の単語を持つ発言と、その返事の発言番号を返す。
  #適切なものが無ければ、[nil, nil]。
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
    dprint("共通単語発言", @log[maxMid].body) if maxMid
    return [maxMid, maxResMid]
  end
  
  #類似発言と、その返事の発言番号を返す。
  #適切なものが無ければ、[nil, nil]。
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
    dprint("類似発言", @log[maxMid].body, maxProb) if maxMid
    return [maxMid, maxResMid]
  end
  
  #msgN番の発言を使ったベース発言の文字列。
  def getBaseMsgStr(msgN)
    str= @log[msgN].body
    #文の後半に[＜＞]が有れば、その後ろはカット。
    str= $1 if str=~/^(.*)[＜＞]/ && $1.length()>=str.length()/2
    return str
  end
  
  #base内の既知単語をnewWordsで置換したものを返す。
  #toForceがfalseの場合、短すぎる文章になってしまった場合はnilを返す。
  def replaceWords(base, newWords, toForce)
    #baseを単語の前後で分割してpartsにする。
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
    #先頭から2番目以降の単語の直前でカットしたりしなかったり。
    if parts.size()>1
      cutPos= rand((parts.size()-1)/2)*2+1
      parts= [""]+parts[cutPos..-1] if cutPos>1
    end
    wordCt= (parts.size()-1)/2
    #単語を除いた文章が短すぎるものはある確率で却下。
    if wordCt>0 && !toForce
      len= sigma(0...parts.size()){ |i| i%2==0 ? parts[i].jlength() : 0 }
      return nil if !shouldAdoptSaying(len)
    end
    #単語を置換。
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
    #閉じ括弧が残った場合に開き括弧を補う。
    #入れ子になってたりしたら知らない。
    case output
      when /^[^「」]*」/
        output= "「"+output
      when /^[^（）]*）/
        output= "（"+output
      when /^[^()]*\)/
        output= "("+output
    end
    return output
  end
  
  #自由発言の選び方を記録する。
  def recordThought(pattern, simMid, resMid, words, output)
    wordsStr= words.map(){ |w| w.str }.join(",")
    row= [@log.size-1, pattern, simMid, resMid, wordsStr, output]
    @thoughtFile.print(row.join("\t")+"\n")
  end
  
  #自由に発言する。
  def speakFreely(fromNick, origInput, mustRespond)
    input= replaceMyNicks(origInput, " ")
    output= nil
    simMsgN, baseMsgN= getBaseMsgUsingSimilarity(input)
      #まず、類似性を使ってベース発言を求める。
    if @newInputWords.size()>0
      if baseMsgN
        #パターン1: 単語有り＆類似発言有り。
        output= replaceWords(getBaseMsgStr(baseMsgN), @inputWords, mustRespond)
        recordThought(1, simMsgN, baseMsgN, @newInputWords, output) if output
      else
        #パターン2: 単語有り＆類似発言無し。
        simMsgN, baseMsgN= getBaseMsgUsingKeyword(@newInputWords)
        output= getBaseMsgStr(baseMsgN) if baseMsgN
        recordThought(2, simMsgN, baseMsgN, @newInputWords, output) if output
      end
    else
      if baseMsgN
        #パターン3: 単語無し＆類似発言有り。
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
        #パターン4: 単語無し＆類似発言無し。
        if mustRespond && @inputWords.size()>0
          #最新でない入力語も使ってキーワード検索。
          simMsgN, baseMsgN= getBaseMsgUsingKeyword(@inputWords)
          output= getBaseMsgStr(baseMsgN) if baseMsgN
          recordThought(4, simMsgN, baseMsgN, @inputWords, output) if output
        end
      end
    end
    if mustRespond && !output
      #ランダム発言
      2000.times() do
        #ハングるのを防ぐため、無限ループにはしない
        msgN= rand(@log.size())
        if isUsableBaseMsg(msgN)
          baseMsgN= msgN
          output= getBaseMsgStr(baseMsgN)
          break
        end
      end
    end
    if output
      #最近使ったベース発言を更新
      @recentBaseMsgNs.shift()
      @recentBaseMsgNs.push(baseMsgN)
      #発言中の自分のNickを相手のNickに変換
      output= replaceMyNicks(output, fromNick)
      #実際に発言。
      speak(origInput, output)
    end
  end
  
  #自由発話として発言する。
  def speak(input, output)
    @lastSpeachInput= input
    @lastSpeach= output
    studyMsg("!", output) #自分の発言を記憶する。
    @client.outputInfo("「"+input+"」に反応した。") if settings("teacher_mode")=="true"
    @attention.onSelfSpeak(@wordSearcher.searchWords(output))
    @client.speak(output)
  end
  
  #定型コマンドを処理。
  #入力が定型コマンドであれば応答メッセージを返す。
  #そうでなければnilを返す。ただし、終了コマンドだったら:exitを返す。
  def processCommand(input)
    if input=~/設定を更新/
      loadSettings()
      return "設定を更新しました。"
    end
    return nil if settings("disable_commands")=="true"
      #コマンドが禁止されてる
    if input=~/黙れ|黙りなさい|黙ってろ|沈黙モード/
      return changeMode(0) ? "沈黙モードに切り替える。" : ""
    elsif input=~/寡黙モード/
      return changeMode(1) ? "寡黙モードに切り替える。" : ""
    elsif input=~/通常モード/
      return changeMode(2) ? "通常モードに切り替える。" : ""
    elsif input=~/饒舌モード/
      return changeMode(3) ? "饒舌モードに切り替える。" : ""
    elsif input=~/休んで良いよ|終了しなさい/
      save()
      @client.exit()
      return :exit
    elsif input=~/([\x21-\x7e]+)の(もの|モノ|物)(まね|真似)/
      begin
        @targetNickReg= Regexp.new($1, Regexp::IGNORECASE)
        return $1+"のものまねを開始する。"
      rescue RegexpError
        return "正規表現が間違っている。"
      end
    elsif input=~/(もの|モノ|物)(まね|真似).*(解除|中止|終了|やめろ|やめて)/
      @targetNickReg= Regexp.new("", Regexp::IGNORECASE)
      return "物まねを解除する。"
    elsif input=~/覚えさせた|教わった/ && input=~/誰/ && input=~/「(.+?)」/
      wordStr= $1
      wordIdx= @wordSet.words.index(Word.new(wordStr))
      if (wordIdx)
        author= @wordSet.words[wordIdx].author
        if (author.length()>0)
          return author+"さんに。＞"+wordStr
        else
          return "不確定だ。＞"+wordStr
        end
      else
        return "その単語は記憶していない。"
      end
    end
    return nil #定型コマンドではない。
  end
  
  #通常の発言を学習。
  def studyMsg(fromNick, input)
    return if settings("disable_studying")=="true"
    if settings("teacher_mode")=="true"
      @fromNick= fromNick
      @extractor.processLine(input) #単語の抽出のみ。
    else
      @log.addMsg(fromNick, input)
    end
  end
  
  #学習内容を手動保存
  def save()
    @wordSet.save()
  end
  
  #ログに発言が追加された。
  def onAddMsg()
    msg= @log[@log.size()-1]
    @fromNick= msg.fromNick if msg.fromNick!="!"
    if settings("teacher_mode")!="true"
      #中の人モードでは、単語の抽出は別にやる。
      @extractor.processLine(msg.body)
    end
    #@extractor以外のオブジェクトは自力で@logを監視しているので、
    #ここで何かする必要は無い。
  end
  
  #ログがクリアされた。
  def onClearLog
  end
  
  #単語が追加された
  def onAddWord(wordStr)
    if @wordSet.addWord(wordStr, @fromNick)
      if @client
        @client.outputInfo("単語「"+wordStr+"」を記憶した。")
      else
        jprint("単語「"+wordStr+"」を記憶した。\n")
      end
      @wordSet.save() if @autoSave
    end
  end
  
  #接続を開始した
  def onBeginConnecting()
    jprint_to($stderr, "接続開始...\n")
  end
  
  #自分が入室した
  def onSelfJoin()
    updateStatus()
  end
  
  #他人が入室した
  def onOtherJoin(fromNick)
  end

  #他人が発言した。
  def onOtherSpeak(fromNick, input, shouldIgnore= false)
    output= nil #発言。
    isCalled= there_exists?(@myNicks){ |n| input.index(n) }
    output= processCommand(input) if isCalled
    if output
      @client.speak(output) if output!=:exit && !output.empty?
    else #定型コマンドではない。
      @lastSpeach= input
      studyMsg(fromNick, input)
      pickUpInputWords(input)
      prob= @attention.onOtherSpeak(fromNick, input, isCalled)
        #発言率を求める。
      dprint("発言率", prob, @attention.to_s())
      if (!shouldIgnore && rand()<prob) || prob>1.0
        #自由発話。
        speakFreely(fromNick, input, prob>1.0)
      end
    end
  end
  
  #制御発言（infoでの発言）があった。
  def onControlMsg(str)
    return if settings("disable_studying")=="true" || settings("teacher_mode")!="true"
    if str=~/^(.+)→→(.+)$/
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
        @client.outputInfo("反応「%s→→%s」を学習した。" % [input, output])
      end
    end
  end
  
  #沈黙がしばらく続いた。
  def onSilent()
    prob= @attention.onSilent()
    #dprint("発言率", @attention.to_s())
    if rand()<prob && @lastSpeach
      #自発発言。
      speakFreely(@fromNick, @lastSpeach, prob>rand()*1.1)
        #自発発言では、発言が無い限り、同じ発言を対象にしつづける。
        #このせいで全然しゃべらなくなるのを防ぐため、時々mustRespondをONにする。
    end
  end
  
end


end #module Gimite

