$KCODE= "EUC"
$REUDY_DIR= "." if !defined?($REUDY_DIR) #スクリプトがあるディレクトリ

require "message_log"
require "ostruct"
require "erb"


module Gimite


log= MessageLog.new(ARGV[0]+"/log.dat")

data= []
open(ARGV[0]+"/thought.txt") do |f|
  f.each_line() do |line|
    fields= line.chomp().split(/\t/)
    r= OpenStruct.new()
    (r.input_mid, r.pattern, r.sim_mid, r.res_mid)= fields[0...4].map(){ |s| s.to_i() }
    (r.words_str, r.output)= fields[4...6]
    r.input= log[r.input_mid].body
    r.messages= []
    for mid in r.sim_mid...r.sim_mid+6
      m= OpenStruct.new()
      m.nick= log[mid].fromNick
      m.body= log[mid].body
      m.is_sim= mid==r.sim_mid
      m.is_res= mid==r.res_mid
      r.messages.push(m)
    end
    data.push(r)
  end
end

extend(ERB::Util)

template= open("thought_view.html"){ |f| f.read() }
ERB.new(template).run(binding())


end
