#Copyright (C) 2003 Gimite ���� <gimite@mx12.freecom.ne.jp>

#���ܸ�ʸ��������Ƚ���ѥ�����
require "fileutils"
require $REUDY_DIR+'/reudy_common'


module Gimite


#�С�����󥢥åפˤ��ǡ����������Ѵ��ʤɤ�Ԥ���
class ReudyVersion
  
  include(Gimite)
  
  #�ǡ����ΥС�����������å���ɬ�פʤ顢�ǡ����򿷥С������η������Ѵ���
  def checkDataVersion(dir)
    #���ǥ��ΥС������
    currentVer= 305
    currentVerStr= "Ver.3.05"
    
    #�ǡ����ΥС�������Ĵ�٤롣
    dataVer= nil
    if !File.exist?(dir+"/version.dat")
      dataVer= 304
    else
      open(dir+"/version.dat"){ |f| dataVer= f.read().to_i() }
    end
    dataVerStr= {304=>"Ver.3.04.1�ʲ���", 305=>"Ver.3.05"}[dataVer]
    dataVerStr= format("̤�ΤΥС������(%d)", dataVer) if !dataVer
    
    #ɬ�פʤ�ǡ����������Ѵ���
    return if dataVer==currentVer
    if ![304].include?(dataVer)
      jprint_to($stderr, format("[���顼] %s�����ε����ǡ�����%s�����ˤ��Ѵ��Ǥ��ޤ���\n" \
        +"  �ɤ����Ƥ�Ȥ������ϡ���Ԥ����̤��Ƥ���������\n", dataVerStr, currentVerStr))
      return
    end
    jprint_to($stderr, format("%s �����Ƥ�%s�����Ǥ���%s�������Ѵ����ޤ�...\n", \
      dir, dataVerStr, currentVerStr))
    case dataVer
      when 304
        backupOldData(dir, dataVer)
        unescapeLog(dir)
        makeLogInnerFile(dir)
        makeWordInnerFile(dir)
    end
    
    #�ǡ����ΥС�������񤭴����롣
    open(dir+"/version.dat", "w"){ |f| f.print(currentVer) }
  end
  
  private
  
  #������Υǡ������̥ǥ��쥯�ȥ�˥Хå����åס�
  def backupOldData(dir, ver)
    bakDir= makeNewFileName(dir+ver.to_s()+".bak")
    jprint_to($stderr, format("%s �����Ƥ� %s �˥Хå����å���...\n", dir, bakDir))
    FileUtils.cp_r(dir, bakDir)
  end
  
  #log.txt��&lt; &gt; &amp;��< > &���᤹����Ver.3.04.1�ʲ���Ver.3.05�ʹߡ�
  def unescapeLog(dir)
    s= nil
    jprint_to($stderr, format("%s/log.txt ��� &lt; &gt; &amp; �� < > & ���ᤷ�Ƥ��ޤ�...\n", dir))
    open(dir+"/log.txt") do |f|
      s= f.read()
    end
    open(dir+"/log.txt", "w") do |f|
      f.print(s.gsub(/&lt;/, "<").gsub(/&gt;/, ">").gsub(/&amp;/, "&"))
    end
  end
  
  #log.txt�򥳥ԡ�����log.dat���롣��Ver.3.04.1�ʲ���Ver.3.05�ʹߡ�
  def makeLogInnerFile(dir)
    jprint_to($stderr, format("%s/log.dat �������...\n", dir))
    if !File.exist?(dir+"/log.dat")
      FileUtils.cp(dir+"/log.txt", dir+"/log.dat")
    end
  end
  
  #words.txt�򸵤�words.dat���롣�Ĥ��Ǥ�words.txt�򿷷����ˤ��롣
  #��Ver.3.04.1�ʲ���Ver.3.05�ʹߡ�
  def makeWordInnerFile(dir)
    jprint_to($stderr, format("%s/words.dat �������...\n", dir))
    wordSet= WordSet.new(dir+"/words.dat")
    newOuterFileText= ""
    open(dir+"/words.txt") do |file|
      i= 0
      file.each_line() do |line|
        jprint_to($stderr, (i+1).to_s()+"����...\n") if (i+1)%1000==0
        data= line.chomp().split("\t")
        if data.size()==3
          word= wordSet.addWord(data[0], data[1])
          word.mids= data[2].split(",").map(){ |s| s.to_i() } if word
          #Ver.3.01�����ι��ܡ�data[2]��ޤޤʤ��ˤˤĤ��Ƥϡ�
          #����words.txt�ѹ����ˡ�WordSet#updateByOuterFile���ɲä���롣
          #fromNick���ä����㤦���ɡ��ޤ���������
        end
        if data.size()>=1
          newOuterFileText+= data[0]+"\n"
        end
        i+= 1
      end
    end
    wordSet.save()
    #�����ե�����򿷷������Ѥ��Ƥ�����
    open(dir+"/words.txt", "w"){ |f| f.print(newOuterFileText) }
  end
  
  #��¸�Υե�����Ȥ��֤�ʤ��ե�����̾���롣
  def makeNewFileName(base)
    return base if !File.exist?(base)
    i= 2
    while true
      name= base+i.to_s()
      return name if !File.exist?(name)
      i+= 1
    end
  end
  
end


end #module Gimite
