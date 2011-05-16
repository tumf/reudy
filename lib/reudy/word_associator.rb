#Copyright (C) 2003 Gimite ���� <gimite@mx12.freecom.ne.jp>

#���ܸ�ʸ��������Ƚ���ѥ�����
require 'kconv'
require 'jcode'


module Gimite


#ñ��Ϣ�۴�
class WordAssociator
  
  def initialize(fileName)
    @fileName= fileName
    loadFromFile()
  end
  
  def loadFromFile()
    @assocWordMap= {}
    return if !File.exists?(@fileName)
    open(@fileName) do |file|
      file.each_line() do |line|
        strs= line.chomp().split(/\t/)
        if strs.size()>=2
          @assocWordMap[strs[0]]= strs[1..-1]
        end
      end
    end
  end
  
  #1ñ�줫��Ϣ�ۤ��줿1ñ����֤�
  def associate(wordStr)
    strs= @assocWordMap[wordStr]
    if strs && strs.size()>0
      return strs[rand(strs.size())]
    else
      return nil
    end
  end
  
  #1ñ�줫��Ϣ�ۤ��줿���Ƥ�ñ����֤�
  def associateAll(wordStr)
    return @assocWordMap[wordStr]
  end
  
end


end #module Gimite
