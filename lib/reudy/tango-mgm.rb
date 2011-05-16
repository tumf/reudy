#!/usr/bin/ruby
#----------------------------------------------------------------------------
#Copyright (C) 2003 mita-K, NAKAUE.T (Meister), Gimite ����
#
# mita-K��ñ������饤�֥��
#
#      Original works by mita-K
#      Extended by Gimite/Meister
#
#  2003.06.06                 ����˥��饹��(Meister)
#                             ����Ū��ʸ�������ɤ˰�¸���ʤ��褦�ˡ�
#                             ������������ʸ��������(SJIS)�˰�¸
#  2003.06.22                 Gimite�Ǥ�����(Meister)
#                             �����ν������ν�����ñ��ʸ�������ե��륿���ѹ�����
#                             ���ߤμ����Ǥ�ʸ������������Ĵ�٤뤿�ᡢ
#                             �虜�虜�������������ñ�����ʤ��Ȥ�
#                             Ʊ����Τ�¾�θ���˴ޤޤ�Ƥ���
#  2003.06.23                 Gimite�Ǥε�ǽ���ɲðܿ�(Gimite)
#                             �Ҥ餬�ʸ򤸤�θ��ۤȤ����ФǤ��ʤ��������
#                             ñ����л��ζ�§�������ɲ�
#                             ñ����л��θ����Υ��ߤν�����ɲ�
#                             ��Ҥ餬�ʤ�2ʸ���ʾ��Ϣ³��̵����ϸ�§�Ȥ����оݳ���
#                             checkWordCand()���Ϥ�prestr��poststr�����󤫤�ʸ������ѹ�
#                             ���äݤ���Τθ��Ф򶯲�
#                             EUC�Ѥ˽񤭴������Τǡ�ɬ�פ˱������ᤷ�Ƥ���������
#
#----------------------------------------------------------------------------
$KCODE='E'
#----------------------------------------------------------------------------
# ʸ�椫��ñ��(�餷��ʸ����)��õ���Ф�
class WordExtractor

  # ���󥹥ȥ饯��
  # WordExtractor(ñ�����ꥹ�Ȥ��ݻ�����Ĺ��,ñ���ɲû��Υ�����Хå�)
  def initialize(candlistlength=7,onaddword=nil)
    # ñ�����Υꥹ��
    @candList=Array.new(candlistlength,[])
    @onAddWord=onaddword
  end


  def candList; @candList;  end


  # ñ�����Υꥹ�Ȥ����������֤�
  def getCandList
    return @candList.flatten.compact.uniq
  end


  # ñ��Ȥ���Ŭ�ڤ��ɤ���Ƚ�ꤹ��
  # ���äݤ���ʤɤ�����ˤ�Ŭ�Ѥ��ʤ�
  # ��Ŭ����nil���֤�
  def wordFilter1(word)
    # ����(^_^;
    return nil if !word
    # ��ʸ������
    return nil if word=~/^.$/e
    # ʿ��̾����
    return nil if word=~/^[��-��]+$/e
    # ��Ҥ餬�ʤ�2ʸ���ʾ��Ϣ³��ޤޤʤ�
    return nil if !(word=~/[^��-��][^��-��]/e)
    # ����äݤ���Τ�ޤ�
    return nil if word=~/[^��-��][�ΤȤ�]$/e
    # ��Ƭ�ʳ��ˡ֤��ס֤ϡפ�ޤ�
    return nil if word=~/^.+��/e
    return nil if word=~/^.+��/e

    return word
  end


  # ñ��Ȥ���Ŭ�ڤ��ɤ���Ƚ�ꤹ��
  # ���äݤ��ʤɤ�����ˤ�Ŭ�Ѥ���
  # ��Ŭ����nil���֤�
  def wordFilter2(word)
    # ����(^_^;
    return nil if !word
    # ������
    return nil if word=~/^$/e
    return nil if word=~/^[�� ]/e
    return nil if word=~/[�� ]$/e
    # ���ʰ�ʸ������
    return nil if word=~/^[��-��-��]$/e
    # �Ҥ餬��2ʸ��
    return nil if word=~/^[��-�󡼡�][��-�󡼡�]$/e
    # ���͡��������
    return nil if word=~/^[-.\/+*:;,~_|&'"`()0-9]+$/e
    # �����ޤ�
    return nil if word=~/[�������������ʡˡ��ġ��ݡ�����]/e
    return nil if word=~/[���֡סء١ڡ̡ۡ�]/e
    return nil if word=~/[�������������΢͡����̧���]/e
    return nil if word=~/[()]/e
    # �������ʤ�ʸ������ϤޤäƤ���
    return nil if word=~/^[,]/e
    return nil if word=~/^[����󤡤������������]/e
    return nil if word=~/^[���ݥ�󥡥�����������å���]/e
    return nil if word=~/^[��-��][^��-��]/e
    # HTML��ʸ������
    return nil if word=~/&[#a-zA-Z0-9]+;/e

    return word
  end


  # ñ��Ȥ���Ŭ�ڤ��ɤ���Ƚ�ꤹ��
  # �����ʸ����⻲�ͤˤ���
  # ��Ŭ����nil���֤�
  def checkWordCand(word,prestr='',poststr='')
    prestr='' if prestr==nil
    poststr='' if prestr==nil
    word=word.clone

    # �ʲ���2�������ƤϤޤä����ϰ����ζ�§���Ƚ�����
    if (prestr=~/[�������������ʡˡ���]$/e || prestr=='') \
     &&(poststr=~/^[�Ϥ�]([^��-��]|$)/e) \
     &&((word+poststr[0..0])!~/(�Ǥ�|����|�ˤ�|�Τ�)$/e) \
     &&(word=~/^[��-��]+$/ || word=~/^[^��-��]/) \
     &&(word.length()>=6)
      # ���äݤ���Ρ�{��������orʸƬ}��[�Ϥ�]{�Ҥ餬�ʰʳ�}
      # �ʤ������֤Ǥϡס֤����ס֤ˤϡס֤Τ��פȤʤ��Τ������
      # Ruby 1.6�ˤ�jlength���ʤ��Τ�Ŭ����ƨ���Ƥ���
    elsif (prestr=~/[���]$/e)&&(poststr=='')
      # ʸ���Ρ֡���פ�֡����
    else
      word=wordFilter1(word)
    end
    return wordFilter2(word)
  end
  
  
  # ʸ�����ñ��Ȥ����ɲä٤�����Ƚ�ꤹ��
  # �ɲä��٤�ñ���word�Ȥϰۤʤ����ˤޤ���nil����Ŭ�ˤ��֤�
  def checkWord(word)
    # �����Υ��ߤν���
    while word=~/^(.+)(�Ȥ�|���ʤ���|�Ǥ���?|�Τ褦|������|����|�ä�)$/e \
        || word=~/^(.+)(�Ȥ���|����|������?|�ޤ�|���ʤ���|�Ǥ���?|�Τ褦)$/e \
        || word=~/^(.+)(����|�����?|�ˤ�|������?|����|�ޤ���|�Ǥ���?)$/e \
        || word=~/^([^��-��]+)[�������Ȥ�ˤ�]$/e
      word= $1
    end
    # ��§
    return nil if word=~/^[��-��-��]$/e || word=~/^[��-�󡼡�][��-�󡼡�]$/e
      #ñ�������˽�������Ƥ�Ϥ������������Υ��ߤν���Ǹ��줿��ǽ����ͭ��ΤǤ⤦1��
    return nil if word=~/�ʤ�|�ä�|�ä�|�Ƥ�|���|����|����|�Ȥ�|���|���|���|�줿|�ޤ�/e
    return nil if word=~/����|���|�Τ�|����|�ˤ�|���|�ʤ�|����|��|����|����|���/e
    return nil if word=~/����|�Τ�|����|����|����|�줬|����|����|����|����|����|����/e
    return nil if word=~/����|����|����|����|����|�Τ�|����|�ʤ�|�Ǥ�|�ʤ�|�Ǥ�|�Ȥ�/e
    return nil if word=~/�褦��|����/e
    return nil if word=~/[^��-��][�Ǥˤ�]/e
    return nil if word=~/��$/e
    return word
  end


  # ʸ���󤫤�ñ�������������
  # ��˥ޥ���Х���ʸ����(���ܸ�ʸ����)�Ѥ�����
  # ������󥰥�Х���ʸ����򿩤碌�Ƥ�����פʤϤ�
  def extractCands(s)
    result=[]

    ss=s.split(//e)

    # �ѿ�����Ϣ³���礹��
    (ss.size-2).downto(0) {|i| ss[i]+=ss.delete_at(i+1) if (ss[i]=~/[-_0-9a-zA-Z]$/e)&&(ss[i+1]=~/[-_0-9a-zA-Z]$/e)}
    # �������ʤ�Ϣ³���礹��
    (ss.size-2).downto(0) {|i| ss[i]+=ss.delete_at(i+1) if (ss[i]=~/[���ݥ�-��]$/e)&&(ss[i+1]=~/[���ݥ�-��]$/e)}

    for i in 0..(ss.size-1)
      for j in i..(ss.size-1)
        cand=checkWordCand(ss[i..j].join,ss[0...i].join,ss[j+1...ss.size()].join)
        result << cand if cand!=nil
      end
    end
#    dprint("ñ�����", result)

    return result
  end


  # ñ��ꥹ�������޴ط��ˤ����Τ�������ñ��ꥹ�Ȥ��Ŭ������
  def optimizeWordList(wordcand)
    for i in 0..(wordcand.length-2)
      next if !wordcand[i]
      for j in (i+1)..(wordcand.length-1)
        next if !wordcand[j]
        if wordcand[j].index(wordcand[i])
          wordcand[i]=nil
          break
        end
        wordcand[j]=nil if wordcand[i].index(wordcand[j])
      end
    end
    wordcand.compact!

    return wordcand
  end


  # ʸ��ǻȤ��Ƥ���ñ������
  def extractWords(line,words=[])

    # ñ����䤬ʸ����˻Ȥ��Ƥ���ñ��ˤ���
    wordcand = getCandList.reject {|word| !line.index(word)}

    # �������ä��ñ��Ʊ�Τ���޴ط������ä���û���ۤ���õ��
    ## �㤨�С֤ʤ�ȡפȤ���ñ�줬��Ͽ��������
    ## �֤ʤ�ס֤�ȡפ�Ʊ����ñ���ǧ������Ƥ��ޤ��Τ��ɤ���
    wordcand=optimizeWordList(wordcand)
    
    # ��§����
    wordcand2 = []
    for word in wordcand
      word2 = checkWord(word)
      wordcand2.push(word2) if word2
    end

    # ������ñ���������ñ��Ȥ���ǧ�ꤹ�롣
    ## ���������֤����������ä���
    words = words | wordcand2

    if @onAddWord
      words.each {|w| @onAddWord.call(w)}
    end

    return words
  end


  # ¿�Х���ʸ���ޤ��ϥ��󥰥�Х���ʸ����������ʤ�ʸ������ڤ�Ф�
  # $KCODE��Ŭ�ڤ����ꤵ��Ƥ��ʤ���Фʤ�ʤ�
  # 0,2,4���������ܤ����󥰥�Х���ʸ����ʸ����
  def splitByCharType(s)
    result=[]

    issingle=true
    word=''
    s.split(//e).each{|c|
      if issingle!=(c.size==1)
        result << word
        word=''
      end
      word+=c
      issingle=(c.size==1)
    }
    result << word if word.size>0

    return result
  end


  # ñ�����Υꥹ�Ȥ򹹿�����
  def renewCandList(line)
    newlist=[]
    wordlist=splitByCharType(line)
    for i in 0..(wordlist.size-1)
      if (i%2)==0
        wordlist[i].split(' ').each{|w| newlist << w if checkWordCand(w)!=nil}
      else
        newlist+=extractCands(wordlist[i])
      end
    end

    @candList.shift
    @candList << newlist
  end


  # ñ�����Υꥹ�Ȥ򹹿�����
  # (���󥰥�Х���ʸ����λ���ʬΥ��Ԥ�ʤ��С������)
  def renewCandList2(line)
    @candList.shift
    @candList << extractCands(line)
  end


  # ñ�������ñ�����ꥹ�ȹ�����1��ʬ��������
  def processLine(line)
    words=extractWords(line)
    renewCandList(line)
    return words
  end


  #�ǥХå�����
  def dprint(caption, obj)
    print(Kconv.tosjis(caption+": "+obj.inspect()), "\n")
  end

end
#----------------------------------------------------------------------------
=begin
# ��
wordextractor=WordExtractor.new
p word=wordextractor.processLine('���̾��������ͤǤ�')
=end

