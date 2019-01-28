--
-- TeC7 VHDL Source Code
--    Tokuyama kousen Educational Computer Ver.7
--
-- Copyright (C) 2011-2012 by
--                      Dept. of Computer Science and Electronic Engineering,
--                      Tokuyama College of Technology, JAPAN
--
--   ��L���쌠�҂́CFree Software Foundation �ɂ���Č��J����Ă��� GNU ��ʌ�
-- �O���p�����_�񏑃o�[�W�����Q�ɋL�q����Ă�������𖞂����ꍇ�Ɍ���C�{�\�[�X
-- �R�[�h(�{�\�[�X�R�[�h�����ς������̂��܂ށD�ȉ����l)���g�p�E�����E���ρE�Ĕz
-- �z���邱�Ƃ𖳏��ŋ�������D
--
--   �{�\�[�X�R�[�h�́��S���̖��ۏ؁��Œ񋟂������̂ł���B��L���쌠�҂����
-- �֘A�@�ցE�l�͖{�\�[�X�R�[�h�Ɋւ��āC���̓K�p�\�����܂߂āC�����Ȃ�ۏ�
-- ���s��Ȃ��D�܂��C�{�\�[�X�R�[�h�̗��p�ɂ�蒼�ړI�܂��͊ԐړI�ɐ�����������
-- �鑹�Q�Ɋւ��Ă��C���̐ӔC�𕉂�Ȃ��D
--
--

--
-- TaC/tac_drom.vhd : TaC instruction decoder ROM
--
-- 2012.01.22           : entity ���A������
-- 2011.09.26           : �V�K�쐬
--
-- $Id
--

library IEEE;
use std.textio.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_textio.all;

entity TAC_DROM is
  port (
    P_CLK   : in  std_logic;
    P_RESET : in  std_logic;
    P_AIN   : in  std_logic_vector(8 downto 0);
    P_DOUT  : out std_logic_vector(7 downto 0)
  );
end TAC_DROM;

architecture BEHAVE of TAC_DROM is
  subtype Word is std_logic_vector(7 downto 0);
  type Mem512 is array(0 to 511) of Word;

  function read_file (fname : in string) return Mem512 is
    file data_in : text is in fname;
    variable line_in: line;
    variable ram : Mem512;
    begin
      for i in 0 to 511 loop
        readline (data_in, line_in);
        read(line_in, ram(i));
      end loop;
      return ram;
    end function;
    
  signal mem  : Mem512 := read_file("tac_drom.txt");

  begin
    process(P_RESET, P_CLK)
      begin
        if (P_RESET='0') then       -- make distribute ram
          P_DOUT <= "00000000";
        elsif (P_CLK'event and P_CLK='1') then
          P_DOUT <= mem( conv_integer(P_AIN ) );
        end if;
      end process;

end BEHAVE;
