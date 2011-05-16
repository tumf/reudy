#Copyright (C) 2003 Gimite ���� <gimite@mx12.freecom.ne.jp>

#���ܸ�ʸ��������Ƚ���ѥ�����
require 'kconv'
require 'jcode'
require $REUDY_DIR+'/wordset'

module Gimite


#ʸ�椫����Τ�ñ���õ��
class WordSearcher
  
  include(Gimite)
  
  def initialize(wordSet)
    @wordSet= wordSet
  end
  
  #ʸ�Ϥ�����ñ���ޤ�Ǥ��뤫
  def hasWord(sentence, word)
    return false if !sentence.index(word.str)
    return false if !(sentence=~Regexp.new("(.|^)"+Regexp.escape(word.str)+"(.|$)"))
    preChar= $1
    folChar= $2
    wordAr= word.str.split(//)
    #������������ʸ�����������ڤ�褦��ñ����Բ�
    return false if (preChar+wordAr[0])=~/[��-�󡼡�][��-�󡼡�]/
    return false if (preChar+wordAr[0])=~/[a-zA-Z][a-zA-Z]/
    return false if (wordAr[-1]+folChar)=~/[��-�󡼡�][��-�󡼡�]/
    return false if (wordAr[-1]+folChar)=~/[a-zA-Z][a-zA-Z]/
    return true
  end
  
  #ʸ�椫����Τ�ñ���õ��
  def searchWords(sentence)
    words= []
    @wordSet.each() do |word|
      if hasWord(sentence, word)
        sentence= sentence.gsub(Regexp.new(Regexp.escape(word.str)), " ")
        words.push(word)
      end
    end
    return words
  end
  
end


end #module Gimite
