#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>

#日本語文字コード判定用コメント
require 'kconv'
require 'jcode'
require $REUDY_DIR+'/wordset'
require $REUDY_DIR+'/message_log'
require $REUDY_DIR+'/word_searcher'


module Gimite


#「単語→発言番号」リストを管理するもの。
class WordToMessageListManager
  
  def initialize(wordSet, log, wordSearcher)
    @wordSet= wordSet
    @log= log
    @wordSearcher= wordSearcher
    @log.addObserver(self)
  end
  
  def onAddMsg()
    msgN= @log.size()-1
    for word in @wordSearcher.searchWords(@log[msgN].body)
      word.msgNs.push(msgN)
    end
  end
  
  def onClearLog()
    for word in @wordSet
      word.msgNs= []
    end
  end
  
  #単語wordにmsgNsを付ける。
  def attachMsgList(word)
    word.msgNs= []
    for i in 0...@log.size()
      word.msgNs.push(i) if @wordSearcher.hasWord(@log[i].body, word)
    end
  end
  
end


end #module Gimite
