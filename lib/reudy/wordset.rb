#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>

#日本語文字コード判定用コメント
require "kconv"
require "jcode"
require "fileutils"
require $REUDY_DIR+'/reudy_common'


module Gimite


#単語。
class Word
  
  #注：このクラスのインスタンスはMarshalで保存されるので、
  #    気軽にインスタンス変数名を変えない事。

  def initialize(s, a= "", m= [])
    @str= s #単語の文字列。
    @author= a #単語を教えた人。
    @mids= m #この単語を含む発言の番号。
  end
  
  def ==(other)
    return @str==other.str
  end
  
  def eql?(other)
    return @str==other.str
  end
  
  def hash()
    return @str.hash()
  end
  
  def <=>(other)
    return @str<=>other.str
  end
  
  def inspect()
    return "<Word: \""+str+"\">"
  end

  attr_accessor :str
  attr_accessor :author
  attr_accessor :mids
  
  #古い名前。互換性のため。
  alias msgNs mids
  alias msgNs= mids=
  
end


# 単語集
class WordSet
  
  include(Gimite)
  include(Enumerable)
  
  def initialize(innerFileName)
    @innerFileName= innerFileName
    @outerFileName= nil
    if File.exist?(@innerFileName)
      @innerFileTime= File.mtime(@innerFileName)
      Kernel.open(@innerFileName, "r") do |file|
        @words= Marshal.load(file)
      end
    else
      @innerFileTime= nil
      @words= []
    end
    @addedWords= []
  end
  
  #外部ファイルを登録し、外部ファイルの内容を内部データに反映する。
  def updateByOuterFile(outerFileName, wtmlManager)
    @outerFileName= outerFileName
    return if !File.exists?(@outerFileName)
    return if @innerFileTime && @innerFileTime>=File.mtime(@outerFileName)
    jprint_to($stderr, @outerFileName+" が変更されたようです。単語を読み込み中...\n")
    addedWords= @addedWords
    @addedWords= []
    isOldFormat= false
    n= 0
    Kernel.open(@outerFileName, "r") do |file|
      file.each_line() do |line|
        #外部ファイル中の単語を追加する。
        #内部データに有って外部ファイルに無い単語については、現バージョンでは何もしていないので注意。
        #data[1], data[2]はVer.3.04以前のデータを引き継ぐために使われる。
        str= line.chomp()
        next if str==""
        jprint_to($stderr, (n+1).to_s()+"語目...\n") if (n+1)%100==0
        word= addWord(str)
        if word
          jprint_to($stderr, "単語「"+word.str+"」を追加中...\n")
          wtmlManager.attachMsgList(word)
        end
        n+= 1
      end
    end
    #initializeとupdateByOuterFileの間に追加された単語を外部ファイルに保存。
    @addedWords= addedWords
    save()
  end
  
  #単語を追加
  def addWord(str, author= "")
    word= Word.new(str, author)
    i= 0
    while i<@words.size()
      break if str.index(@words[i].str)
      i+= 1
    end
    if @words[i] && @words[i].str==str
      return nil
    else
      @words[i, 0]= [word]
      @addedWords.push(word)
      return word
    end
  end
  
  #ファイルに保存
  def save()
    if @outerFileName
      Kernel.open(@outerFileName, "a") do |file|
        for word in @addedWords
          file.print(word.str+"\n")
        end
      end
      @addedWords= []
    end
    Kernel.open(@innerFileName, "w") do |file|
      Marshal.dump(@words, file)
    end
  end
  
  #単語イテレータ
  def each()
    @words.each() do |word|
      yield(word)
    end
  end
  
  #中身をテキスト形式で出力。
  def output(io)
    for word in @words
      io.print(word.str, "\t", word.author, "\t", word.mids.join(","), "\n")
    end
  end
  
  attr_reader :words
  
  private
  
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
