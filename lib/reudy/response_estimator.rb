#Copyright (C) 2003 Gimite ���� <gimite@mx12.freecom.ne.jp>

#���ܸ�ʸ��������Ƚ���ѥ�����
$KCODE= "EUC"
$REUDY_DIR= "." if !defined?($REUDY_DIR) #������ץȤ�����ǥ��쥯�ȥ�

require 'kconv'
require 'jcode'
require $REUDY_DIR+'/message_log'
require $REUDY_DIR+'/wordset'
require $REUDY_DIR+'/word_searcher'
require $REUDY_DIR+'/reudy_common'


module Gimite


#�����ȯ���ؤ��ֻ�����ꤹ�롣
class ResponseEstimator
  
  include(Gimite)
  
  def initialize(log, wordSearcher, msgFilter= proc(){ |n| true }, wordFilter= proc(){ |w| true })
    @cacheLimit= 40
    @log= log
    @wordSearcher= wordSearcher
    @msgFilter= msgFilter
    @wordFilter= wordFilter
    @cache= {}
  end
  
  #mid���ܤ�ȯ���ؤ��ֻ��ʤȻפ���ȯ���ˤˤĤ��ơ�[ȯ���ֹ�,�ֻ��餷��]���֤���
  #��������@msgFilter.call(�ֻ����ֹ�)���������Τ���
  #���������Τ�̵�����[nil,0]���֤���
  #debug�����ʤ顢�ǥХå����Ϥ򤹤롣
  def responseTo(mid, debug= false)
    numTargets= 5
    if @cache[mid] && @msgFilter.call(@cache[mid][0])
      return @cache[mid] #����å���˥ҥåȡ�
    end
    
    candMids= (mid+1..mid+numTargets).select(){ |n| @msgFilter.call(n) }
    return [nil, 0] if candMids.empty?()
      #�������Ƚ��ϽŤ��Τǡ���ˡ�����nil�ˤʤ륱�����פ������
    words= @wordSearcher.searchWords(@log[mid].body).select{ |w| @wordFilter.call(w) }
    resMid= nil
    
    #����ȯ������numTargets�԰���ǡ�Ʊ��ñ���ޤ��Τ�ͭ��С�������ֻ��Ȥߤʤ���
    #̵����С�ľ���ȯ�����ֻ��Ȥ��롣
    for word in words
      for n in word.mids
        if n>mid
          if n>mid+numTargets || (resMid && n>=resMid)
            break
          elsif candMids.include?(n)
            resMid= n
            break
          end
        end
      end
    end
    prob= resMid ? numTargets : 0 #Ʊ��ñ���ޤ��������ֻ��餷�����⤤��
    resMid= candMids[0] if !resMid
    prob+= numTargets+1-(resMid-mid) #�ᤤȯ�����������ֻ��餷�����⤤��
    
    #for n in mid+1..mid+numTargets
    #  if @log[n].body=~/[<>���]/
    #    dprint("�֡�פʤɤ�¸��", @log[n].body) if debug
    #    break
    #  end
    #end
    
    #����å��夷�Ƥ�����
    @cache.clear() if @cache.size>=@cacheLimit
    @cache[mid]= [resMid, prob]
    
    return [resMid, prob]
  end
  
end


if __FILE__==$0
  
  dir= ARGV[0]
  log= MessageLog.new(dir+"/log.dat")
  wordSet= WordSet.new(dir+"/words.dat")
  wordSearcher= WordSearcher.new(wordSet)
  resEst= ResponseEstimator.new(log, wordSearcher)
  for mid in ARGV[1..-1].map(){ |s| s.to_i() }
    jprintf("[%d]%s:\n", mid, log[mid].body)
    resMid, prob= resEst.responseTo(mid, true)
    jprintf("  [%d]%s (%d)\n", resMid, log[resMid].body, prob) if resMid
  end
  
end


end #module Gimite

