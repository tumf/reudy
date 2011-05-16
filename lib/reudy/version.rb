#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>

#日本語文字コード判定用コメント
require "fileutils"
require $REUDY_DIR+'/reudy_common'


module Gimite


#バージョンアップによるデータ形式の変換などを行う。
class ReudyVersion
  
  include(Gimite)
  
  #データのバージョンをチェック。必要なら、データを新バージョンの形式に変換。
  def checkDataVersion(dir)
    #ロイディのバージョン。
    currentVer= 305
    currentVerStr= "Ver.3.05"
    
    #データのバージョンを調べる。
    dataVer= nil
    if !File.exist?(dir+"/version.dat")
      dataVer= 304
    else
      open(dir+"/version.dat"){ |f| dataVer= f.read().to_i() }
    end
    dataVerStr= {304=>"Ver.3.04.1以下の", 305=>"Ver.3.05"}[dataVer]
    dataVerStr= format("未知のバージョン(%d)", dataVer) if !dataVer
    
    #必要ならデータ形式を変換。
    return if dataVer==currentVer
    if ![304].include?(dataVer)
      jprint_to($stderr, format("[エラー] %s形式の記憶データを%s形式には変換できません。\n" \
        +"  どうしてもという場合は、作者に相談してください。\n", dataVerStr, currentVerStr))
      return
    end
    jprint_to($stderr, format("%s の内容は%s形式です。%s形式に変換します...\n", \
      dir, dataVerStr, currentVerStr))
    case dataVer
      when 304
        backupOldData(dir, dataVer)
        unescapeLog(dir)
        makeLogInnerFile(dir)
        makeWordInnerFile(dir)
    end
    
    #データのバージョンを書き換える。
    open(dir+"/version.dat", "w"){ |f| f.print(currentVer) }
  end
  
  private
  
  #旧形式のデータを別ディレクトリにバックアップ。
  def backupOldData(dir, ver)
    bakDir= makeNewFileName(dir+ver.to_s()+".bak")
    jprint_to($stderr, format("%s の内容を %s にバックアップ中...\n", dir, bakDir))
    FileUtils.cp_r(dir, bakDir)
  end
  
  #log.txtの&lt; &gt; &amp;を< > &に戻す。（Ver.3.04.1以下→Ver.3.05以降）
  def unescapeLog(dir)
    s= nil
    jprint_to($stderr, format("%s/log.txt 内の &lt; &gt; &amp; を < > & に戻しています...\n", dir))
    open(dir+"/log.txt") do |f|
      s= f.read()
    end
    open(dir+"/log.txt", "w") do |f|
      f.print(s.gsub(/&lt;/, "<").gsub(/&gt;/, ">").gsub(/&amp;/, "&"))
    end
  end
  
  #log.txtをコピーしてlog.datを作る。（Ver.3.04.1以下→Ver.3.05以降）
  def makeLogInnerFile(dir)
    jprint_to($stderr, format("%s/log.dat を作成中...\n", dir))
    if !File.exist?(dir+"/log.dat")
      FileUtils.cp(dir+"/log.txt", dir+"/log.dat")
    end
  end
  
  #words.txtを元にwords.datを作る。ついでにwords.txtを新形式にする。
  #（Ver.3.04.1以下→Ver.3.05以降）
  def makeWordInnerFile(dir)
    jprint_to($stderr, format("%s/words.dat を作成中...\n", dir))
    wordSet= WordSet.new(dir+"/words.dat")
    newOuterFileText= ""
    open(dir+"/words.txt") do |file|
      i= 0
      file.each_line() do |line|
        jprint_to($stderr, (i+1).to_s()+"語目...\n") if (i+1)%1000==0
        data= line.chomp().split("\t")
        if data.size()==3
          word= wordSet.addWord(data[0], data[1])
          word.mids= data[2].split(",").map(){ |s| s.to_i() } if word
          #Ver.3.01以前の項目（data[2]を含まない）については、
          #次回words.txt変更時に、WordSet#updateByOuterFileで追加される。
          #fromNickが消えちゃうけど、まあいいか。
        end
        if data.size()>=1
          newOuterFileText+= data[0]+"\n"
        end
        i+= 1
      end
    end
    wordSet.save()
    #外部ファイルを新形式に変えておく。
    open(dir+"/words.txt", "w"){ |f| f.print(newOuterFileText) }
  end
  
  #既存のファイルとかぶらないファイル名を作る。
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
