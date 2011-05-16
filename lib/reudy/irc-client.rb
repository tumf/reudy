#----------------------------------------------------------------------------
#
# IRC�N���C�A���g���C�u����
#
#      Programed by NAKAUE.T (Meister)
#      Modified by Gimite �s��
#
#  2003.05.04  Version 1.0.0   �g���Ă����l���������̂Ń\�[�X�𐮗�
#  2003.05.10  Version 1.1.0   NICK�����ǉ�
#  2003.07.24  Version 1.2.0g  ���r���[�Ƀ}���`�`�����l���Ή�(Gimite)
#  2003.09.27  Version 1.2.1   UltimateIRCd�ŔF�ؑO��PING��������ɑΏ�(Meister)
#                              (thanks for bancho)
#  2003.09.28  Version 1.2.2   �����R�[�h�ϊ��𐮗�(Meister)
#                              �O���Ƃ̂������s���R�[�h���w�肷��
#                              (IRC��JIS���g�����ƂɂȂ��Ă���)
#                              initialize�̃p�����[�^���ύX�ɂȂ����̂Œ��ӁI
#  2003.09.28  Version 2.0.0   �C���^�[�t�F�[�X����(Meister)
#                              �݊������Ⴍ�Ȃ����̂ň�C�Ƀo�[�W�������グ��
#  2003.10.01  Version 2.0.1   NICK�̃o�O�C��(Meister)
#  2004.01.01  Version 2.0.2   �C���X�^���X������Ƀ\�P�b�g��n����悤�ɂ���
#  2004.03.03  Version 2.0.3g  �ڑ����؂ꂽ���ɁAIRCC#connect�ōĐڑ��ł���悤��
#                              IRC�G���[����������IRCC#on_error��ǉ�(Gimite)
#
#
# ���̃\�t�g�E�F�A��Public Domain Software�ł��B
# ���R�ɗ��p�E���ς��č\���܂���B
# ���ς̗L���ɂ�����炸�A���R�ɍĔz�z���邱�Ƃ��o���܂��B
# ��҂͂��̃\�t�g�E�F�A�Ɋւ��āA�S�Ă̌����ƑS�Ă̋`����������܂��B
#
#----------------------------------------------------------------------------
# IRC�v���g�R���ɂ��Ă�RFC2810-2813���Q�Ƃ̂��ƁB���{��󂠂�܂��B
#----------------------------------------------------------------------------
require 'kconv'
#----------------------------------------------------------------------------
class IRCC

  def initialize(sock,userinfo,internal_kcode='s',disp=$stdout,irc_kcode='j')
    @sock=sock
    @userinfo=userinfo
    @irc_nick=@userinfo['nick']
    setchannel(@userinfo['channel'])    # ������JOIN����`�����l��
                                        # ���̃`�����l���𔲂���ƏI������(�d�l)
    @channel_key=@userinfo['channel_key']||''

    @nicklist=[]
    @joined_channel=nil

    @internal_nkf=kcode_to_nkf(internal_kcode)
    @irc_nkf=kcode_to_nkf(irc_kcode)

    @disp=disp
  end

  def sock; @sock;    end
  def userinfo; @userinfo;  end
  def nicklist; @nicklist;  end
  def mynick;   @irc_nick;  end
  def joined_channel;   @joined_channel;    end


  # �C���X�^���X������̃\�P�b�g�ڑ�
  def connect(sock)
    @sock=sock
    @myprefix= nil
  end

  def kcode_to_nkf(kcode)
    case kcode
    when /^s/i
      return "s"
    when /^e/i
      return "e"
    when /^j/i
      return "j"
    when /^u/i
      return "w"
    else
      return "j"
    end
  end
  
  def convert_encoding(buff,from_nkf,to_nkf)
    if from_nkf == "j"
      buff=buff.gsub(/\e\(J/n, "\e(I").unpack("C*").map(){ |c| (c & 0x7f) }.pack("C*")
        # cotton�̔��p�J�i��NKF�������ł���t�H�[�}�b�g�ɕϊ�
    end
    if from_nkf == to_nkf
      return buff
    else
      return NKF.nkf("-#{to_nkf}#{from_nkf.upcase}x",buff)
    end
  end

  # IRC�̕����R�[�h��������R�[�h�ɕϊ�
  def irc_to_internal(buff)
    return convert_encoding(buff,@irc_nkf,@internal_nkf)
  end

  # �����R�[�h����IRC�̕����R�[�h�ɕϊ�
  def internal_to_irc(buff)
    return convert_encoding(buff,@internal_nkf,@irc_nkf)
  end

  # �`�����l�������Z�b�g
  def setchannel(channel)
    @irc_channel=channel
  end

  # ���b�Z�[�W�𑗐M(��)
  def sendmess(mess)
    @sock.print(internal_to_irc(mess))
    @disp.puts(mess.chop) if DEBUG
  end

  # ���b�Z�[�W�̑��M(�ʏ��PRIVMSG��)
  def sendpriv(mess)
    mess='' if mess==nil
    dispmess('>'+@irc_nick+'<',mess)
    buff='PRIVMSG '+@irc_channel+' :'+mess
    sendmess(buff+"\r\n")
  end

  # ���b�Z�[�W�̑��M(NOTICE��)
  def sendnotice(mess)
    mess='' if mess==nil
    dispmess('>'+@irc_nick+'<',mess)
    buff='NOTICE '+@irc_channel+' :'+mess
    sendmess(buff+"\r\n")
  end

  # �ʂ̃`�����l���Ɉړ�
  def movechannel(channel)
    old_channel= @irc_channel
    setchannel(channel)
      #PART�̑O�ɂ�������������Ă����Ȃ���QUIT���Ă��܂�
    sendmess('PART '+old_channel+"\r\n")
    sendmess('JOIN '+@irc_channel+" "+@channel_key+"\r\n")
  end

  # �I������(���ۂɂ̓`�����l���𔲂��Ă���)
  def quit
    sendmess('PART '+@irc_channel+"\r\n")
  end

  # �T�[�o����󂯎�������b�Z�[�W������
  def on_recv(s)
    s.chomp!("\n")
    s.chomp!("\r")
    # �����ŕϊ����Ă��܂��ƁAinternal_to_irc(irc_to_internal(s)) != s �ƂȂ�悤��
    # �`�����l����/nick�ȂǂŖ�肪�N����\��������B�{���͌��̕����R�[�h�ł�
    # �`�����l����/nick�����킹�ĕێ����ׂ������A�ʓ|�Ȃ̂ŕ��u�B
    s=irc_to_internal(s)
    @disp.puts('>'+s) if DEBUG

    prefix=":unknown!unknown@unknown"
    prefix,param=s.split(' ',2) if s[0..0]==':'
    nick,prefix=prefix.split('!',2)
    nick.slice!(0)
    param=s if !param

    param,param2=param.split(/ :/,2)
    param=param.split(' ')
    param << param2 if param2

    case param[0]
    when 'PRIVMSG','NOTICE' # �ʏ�̃��b�Z�[�W(NOTICE�ւ�BOT�̔����͋֎~����Ă���)
      if param[2][1..1]!="\001"
        mess=param[-1]
        if (param[1]).downcase==(@irc_channel).downcase
          on_priv(param[0],nick,mess)
        else
          # ������`�����l���̊O����̔���
          on_external_priv(param[0],nick,param[1],mess)
        end
      end
    when '372','375'    # MOTD(Message Of The Day)
      on_motd(param[-1])
    when '353'      # �`�����l���Q�������o�[�̃��X�g
      @nicklist+=param[-1].gsub(/@/,'').split
    when 'JOIN' # �N�����`�����l���ɎQ������
      channel=param[1]
      if @myprefix==prefix
        @joined_channel=channel
        on_myjoin(channel)
      else
        @nicklist|=[nick]
        on_join(nick,channel)
      end
    when 'PART' # �N�����`�����l�����甲����
      channel=param[1]
      if @myprefix==prefix
        @nicklist=[]
        @joined_channel=nil
        on_mypart(channel)
        # �I���V�[�P���X��������QUIT
        sendmess("QUIT\r\n") if (param[1]).downcase==(@irc_channel).downcase
      else
        @nicklist.delete(nick)
        on_part(nick,channel)
      end
    when 'QUIT' # �N�����I������
      mess=param[-1]
      if @myprefix==prefix
        @nicklist=[]
        on_myquit(mess)
      else
        @nicklist.delete(nick)
        on_quit(nick,mess)
      end
    when 'KICK' # �N�����`�����l������R��ꂽ
      kicker=nick
      channel=param[1]
      nick=param[2]
      mess=param[3]||''

      if nick==@irc_nick
        if (param[1]).downcase==(@irc_channel).downcase
          @nicklist=[]
          @joined_channel=nil
        end
        on_mykick(channel,mess,kicker)
        # �R��ꂽ�̂�QUIT
        sendmess("QUIT\r\n") if (param[1]).downcase==(@irc_channel).downcase
      else
        @nicklist.delete(nick)
        on_kick(nick,channel,mess,kicker)
      end
    when 'NICK'     # �N����NICK��ύX����
      nick_new=param[1]

      @irc_nick=nick_new if nick==@irc_nick

      @nicklist.delete(nick)
      @nicklist|=[nick_new]

      on_nick(nick,nick_new)
    when 'INVITE'     # �N�������������҂���
      if param[1]==@irc_nick
        on_myinvite(nick,param[-1])
      end
    when 'PING'     # �N���C�A���g�̐����m�F
      if @myhostname
        sendmess('PONG '+@myhostname+' '+param[1]+"\r\n")
      else
        # UltimateIRCd�ł�MOTD���O��PING������
        # ���m�ȃN���C�A���g�̃z�X�g�����s���Ȃ��߁A�K����PONG��Ԃ�
        sendmess('PONG dummy '+param[1]+"\r\n")
      end
    when '376','422'    # MOTD�̏I���=���O�C���V�[�P���X�̏I���
      # ������prefix���m�F���邽��WHOIS�𔭍s
      sendmess('WHOIS '+@irc_nick+"\r\n")
    when '311'      # WHOIS�ւ̉���
      if @myprefix==nil
        # ������prefix���擾
        @myhostname=param[4]
        @myprefix=param[3]+'@'+@myhostname
        on_login()
      end
    when '433'      # nick���d������
      on_error('433')
      # �������͏d�����Ȃ�nick�ōēxNICK�𔭍s
    when '451'      # �F�؂���Ă��Ȃ�
      on_error('451')
      @disp.puts('unknown login sequence!!') if DEBUG
    end
  end

  # �ڑ��m�����̏���
  def on_connect
    @disp.puts('connect') if DEBUG
    dispmess(nil,'Login...')

    if @userinfo['pass'] && @userinfo['pass']!=""
      sendmess('PASS '+@userinfo['pass']+"\r\n")
    end
    sendmess('NICK '+@irc_nick+"\r\n")
    sendmess('USER '+@userinfo['user']+' 0 * :'+@userinfo['realname']+"\r\n")
  end


  # �������牺�̓I�[�o�[���C�h���鎖��z�肵�Ă���

  # ���b�Z�[�W��\��(�����R�[�h�͕ϊ����Ȃ�)
  def dispmess(nick,mess)
    buff=Time.now.strftime('%H:%M:%S ')
    buff=buff+nick+' ' if nick
    buff=buff+mess
    @disp.puts(buff)
    @disp.flush()
  end

  # �ڑ��E�F�؂��������A�`�����l����JOIN�ł���
  def on_login
    sendmess('JOIN '+@irc_channel+" "+@channel_key+"\r\n")
  end

  # MOTD(�T�[�o�̃��O�C�����b�Z�[�W)
  def on_motd(mess)
    dispmess(nil,mess)
  end

  # �ʏ탁�b�Z�[�W��M���̏���
  def on_priv(type,nick,mess)
    dispmess('<'+nick+'>',mess)
  end

  # ������`�����l���̊O����̒ʏ탁�b�Z�[�W��M���̏���
  def on_external_priv(type,nick,channel,mess)
  end

  # JOIN��M���̏���
  def on_join(nick,channel)
    dispmess(nick,'JOIN '+channel)
  end

  # PART��M���̏���
  def on_part(nick,channel)
    dispmess(nick,'PART '+channel)
  end

  # QUIT��M���̏���
  def on_quit(nick,mess)
    dispmess(nick,'QUIT '+mess)
  end

  # KICK��M���̏���
  def on_kick(nick,channel,mess,kicker)
    dispmess(nick,'KICK '+channel+' '+kicker+' '+mess)
  end

  # ������JOIN��M���̏���
  def on_myjoin(channel)
    on_join(@irc_nick,channel)
  end

  # ������PART��M���̏���
  def on_mypart(channel)
    on_part(@irc_nick,channel)
  end

  # ������QUIT��M���̏���
  def on_myquit(mess)
    on_quit(@irc_nick,mess)
  end

  # ������KICK��M���̏���
  def on_mykick(channel,mess,kicker)
    on_kick(@irc_nick,channel,mess,kicker)
  end

  # NICK��M���̏���
  def on_nick(nick_old,nick_new)
    dispmess(nick_old,'NICK '+nick_new)
  end

  # ������INVITE���ꂽ���̏���
  def on_myinvite(nick,channel)
    dispmess(nick,'INVITE '+channel)
  end
  
  # �G���[�̎��̏���
  def on_error(code)
    @disp.puts("Error: "+code)
    sendmess("QUIT\r\n")  # �ʓ|�Ȃ̂ŏI���ɂ��Ă���
  end
  
end
#----------------------------------------------------------------------------

