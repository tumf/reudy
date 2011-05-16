#Copyright (C) 2003 Gimite ���� <gimite@mx12.freecom.ne.jp>

#���ܸ�ʸ��������Ƚ���ѥ�����
begin
  require 'gdbm'
  $NO_GDBM= false
rescue LoadError
  $NO_GDBM= true
end


module Gimite


if !$NO_GDBM


#�ͤ�ʸ����ʳ��Ǥ�OK��GDBM�ʼ�ȴ����
class MarshalGDBM
  
  def initialize(*args)
    @gdbm= GDBM.new(*args)
  end
  
  def [](key)
    str= @gdbm[key]
    return str && Marshal.load(str).freeze()
      #���֥������Ȥ���Ȥ��ѹ�����Ƥ�DB��ȿ�ǤǤ��ʤ��Τǡ�freeze()���Ƥ���
  end
  
  def []=(key, value)
    @gdbm[key]= Marshal.dump(value)
  end
  
  def keys()
    return @gdbm.keys()
  end
  
  def empty?()
    return @gdbm.empty?()
  end
  
  def clear()
    @gdbm.clear()
  end
  
  def close()
    @gdbm.close()
  end
  
end


end #if !$NO_GDBM


end #module Gimite

