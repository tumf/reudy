#Copyright (C) 2003 Gimite ���� <gimite@mx12.freecom.ne.jp>

#ʸ��������Ȥä����Ƚ�ꡣ

#���ܸ�ʸ��������Ƚ���ѥ�����
require 'kconv'
require 'jcode'
require $REUDY_DIR+'/reudy_common'


module Gimite


#����Ƚ��
class AttentionDecider
  
  include(Gimite)
  
  def initialize()
    @lastNick= nil #�Ǹ��ȯ���ԡ�"!"�ʤ顢��ʬ��
    @prob= 1.0
    @recentSpeakers= [nil] * 10
  end
  
  #�ѥ�᡼�������ꤹ�롣
  def setParameter(probs)
    @minProb= probs[:min] #ȯ��Ψ�κ����͡�
    @maxProb= probs[:max] #ȯ��Ψ�κǹ��͡�
    @probs= probs[:default] #�ǥե���Ȥ�ȯ��Ψ��
    @calledProb= probs[:called] #̾����ƤФ줿����ȯ��Ψ�β��¡�
    @selfProb= probs[:self] #���ʤμ���ȯ����ȯ��Ψ��
    @ignoredProb= probs[:ignored] #̵�뤵�줿��μ���ȯ����ȯ��Ψ��
    @probRange= @maxProb-@minProb
  end
  
  #¾�ͤ�ȯ���������ˤ����Ƥ֡�
  #ȯ��Ψ���֤���
  def onOtherSpeak(fromNick, sentence, isCalled)
    updateRecentSpeakers(fromNick)

    #�����ȯ��Ψ����롣
    if isCalled || recentOtherSpeakers().size == 1
      prob= @calledProb
    else
      prob= @prob
    end
    
    #ȯ��Ψ�򹹿���
    if isCalled
      #�ƤФ줿�顢ȯ��Ψ��ǹ�ˡ�
      raiseProbability(1.0)
    else
      #����ʳ��Υ������Ǥϡ�ȯ��Ψ�Ͻ����˲����롣
      raiseProbability(-0.2)
    end
    
    return prob
  end
  
  #��ʬ��ȯ���������ˤ����Ƥ֡�
  def onSelfSpeak(usedWords)
    updateRecentSpeakers("!")
  end
  
  #���ۤ����Ф餯³�������ˤ����Ƥ֡�
  #ȯ��Ψ���֤���
  def onSilent()
    updateRecentSpeakers(nil)
    jputs self.to_s()
    raiseProbability(-0.2) if @lastNick=="!"
    if @lastNick == "!"
      return @ignoredProb
    elsif recentOtherSpeakers().size == 1
      return @calledProb
    else
      return @selfProb
    end
  end
  
  #���ߤξ��֤�ɽ��ʸ����
  def to_s()
    return "�ǥե����ȯ��Ψ:%.2f, �Ƕ��ȯ����: %p" % [@prob, @recentSpeakers]
  end
  
  private
  
  #ȯ��Ψ��夲�������롣
  #�夲Ψrate�ϡ�ȯ��Ψ����ư�ϰ�(@probRange)���Ф�����ǻ��ꤹ�롣
  def raiseProbability(rate)
    @prob= [[@prob+rate*@probRange, @maxProb].min(), @minProb].max()
  end
  
  def updateRecentSpeakers(nick)
    @lastNick= nick if nick
    @recentSpeakers.shift()
    @recentSpeakers.push(nick)
  end
  
  def recentOtherSpeakers()
    return (@recentSpeakers - [nil, "!"]).uniq
  end
  
end


end #module Gimite
