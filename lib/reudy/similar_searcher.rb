#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>

#文尾だけを使った類似判定。

#日本語文字コード判定用コメント
$REUDY_DIR= "." if !defined?($REUDY_DIR) #スクリプトがあるディレクトリ

require 'kconv'
require 'jcode'
require 'set'
require $REUDY_DIR+'/reudy_common'
require $REUDY_DIR+'/message_log'
require $REUDY_DIR+'/marshal_gdbm'


module Gimite


#類似発言検索器。
class SimilarSearcher
  
=begin
  文尾@compLen文字が1文字違いの発言を類似発言とする。
  ただし、ひらがなと一部の記号のみが対象。
  @tailMapは、「文尾@compLen文字と、そこから任意の1文字を抜いた物」をキーとし、
  発言番号の配列を値とする。
  例えば、10行目が「答えが分かりませんでした。」という発言なら、
    @tailMap["ませんでした"].include?(10)
    @tailMap["せんでした"].include?(10)
    @tailMap["まんでした"].include?(10)
    @tailMap["ませでした"].include?(10)
    @tailMap["ませんした"].include?(10)
    @tailMap["ませんでた"].include?(10)
    @tailMap["ませんでし"].include?(10)
  は全てtrueになる。これを使って「文尾が同じor1文字違いの発言」を探す。
=end
  
  include(Gimite)
  
  def initialize(fileName, log)
    @log= log
    @log.addObserver(self)
    @compLen= 6#比較対象の文尾の長さ
    makeDictionary(fileName)
  end
  
  #inputに類似する各発言に対して、発言番号を引数にblockを呼ぶ。
  #発言の順序は微妙にランダム。
  def eachSimilarMsg(input, &block)
    ws= normalizeMsg(input)
    return if ws.size()<=1
    if ws.size()>=@compLen
      wtail= ws[-@compLen..-1]#文尾。
      randomEach(@tailMap[wtail.join("")], &block)
      for i in 0...@compLen
        #途中を1文字抜かしたもの。
        randomEach(@tailMap[(wtail[0...i]+wtail[i+1..-1]).join("")], &block)
      end
    else
      randomEach(@tailMap[ws.join("")], &block)
    end
  end
  
  #contの各要素について、ランダムな順序でblockを呼び出す。
  def randomEach(cont, &block)
    return if !cont
    cont= cont.dup()
    while cont.size()>0
      block.call(cont.delete_at(rand(cont.size())))
    end
  end
  
  #発言が追加された。
  def onAddMsg()
    recordTail(@log.size()-1)
  end
  
  #ログがクリアされた。
  def onClearLog()
    @tailMap.clear()
  end
  
  #文尾辞書（@tailMap）を生成。
  def makeDictionary(fileName)
    if $NO_GDBM
      jprint_to($stderr, "警告: Ruby/GDBMが見つかりません。Ruby/GDBMが無いと、メモリを大量に消費します。\n")
      @tailMap= {}
    else
      @tailMap= MarshalGDBM.new(fileName, 0666, GDBM::FAST)
    end
    if @tailMap.empty?()
      jprint_to($stderr, "文尾辞書( "+fileName+" )を作成中...\n")
      for i in 0...@log.size()
        jprint_to($stderr, (i+1).to_s()+"行目...\n") if (i+1)%1000==0
        recordTail(i)
      end
    end
  end
  
  #lineN番の発言の文尾を記録。
  def recordTail(lineN)
    ws= normalizeMsg(@log[lineN].body)
    return nil if ws.size()<=1
    if ws.size()>=@compLen
      wtail= ws[-@compLen..-1]#文尾。
      addToTailMap(wtail, lineN)
      for i in 0...@compLen
        #途中を1文字抜かしたもの。
        addToTailMap(wtail[0...i]+wtail[i+1..-1], lineN)
      end
    else
      addToTailMap(ws, lineN)
    end
  end
  
  #@tailMapに追加。
  def addToTailMap(wtail, lineN)
    tail= wtail.join("")
    lineNs= @tailMap[tail]
    if lineNs
      @tailMap[tail]= lineNs+[lineN]
    else
      @tailMap[tail]= [lineN]
    end
  end
  
  #発言から「ひらがなと一部の記号」以外を消し、記号を統一する。
  def normalizeMsg(s)
    s= s.gsub(/[^ぁ-んー−？！\?!\.]+/, "")
    s= s.gsub(/？/, "?").gsub(/！/,"!").gsub(/[ー−+]/, "ー")
    return s.split(//)
  end

end


if __FILE__==$0
  
  dir= ARGV[0]
  log= MessageLog.new(dir+"/log.dat")
  sim= SimilarSearcher.new(dir+"/similar.gdbm", log)
  sim.eachSimilarMsg(ARGV[1].toeuc()) do |mid|
    jprintf("[%d] %s\n", mid, log[mid].body)
  end
  
end


end #module Gimite


