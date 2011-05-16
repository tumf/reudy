#Copyright (C) 2003 Gimite ���� <gimite@mx12.freecom.ne.jp>

#���ܸ�ʸ��������Ƚ���ѥ�����
require 'kconv'
require 'jcode'
require $REUDY_DIR+'/wordset'
require $REUDY_DIR+'/message_log'
require $REUDY_DIR+'/word_searcher'


module Gimite


#��ñ�좪ȯ���ֹ�ץꥹ�Ȥ���������Ρ�
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
  
  #ñ��word��msgNs���դ��롣
  def attachMsgList(word)
    word.msgNs= []
    for i in 0...@log.size()
      word.msgNs.push(i) if @wordSearcher.hasWord(@log[i].body, word)
    end
  end
  
end


end #module Gimite
