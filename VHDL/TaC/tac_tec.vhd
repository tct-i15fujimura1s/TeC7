--
-- TeC7 VHDL Source Code
--    Tokuyama kousen Educational Computer Ver.7
--
-- Copyright (C) 2019 by
--                      Dept. of Computer Science and Electronic Engineering,
--                      Tokuyama College of Technology, JAPAN
--
--   ��L���쌠�҂́CFree Software Foundation �ɂ���Č��J����Ă��� GNU ��ʌ�
-- �O���p�����_�񏑃o�[�W�����Q�ɋL�q����Ă�������𖞂����ꍇ�Ɍ���C�{�\�[�X
-- �R�[�h(�{�\�[�X�R�[�h�����ς������̂��܂ށD�ȉ����l)���g�p�E�����E���ρE�Ĕz
-- �z���邱�Ƃ𖳏��ŋ�������D
--
--   �{�\�[�X�R�[�h�́��S���̖��ۏ؁��Œ񋟂������̂ł���B��L���쌠�҂����
-- �֘A�@�ցE�l�͖{�\�[�X�R�[�h�Ɋւ��āC���̓K�p�\������߂āC�����Ȃ�ۏ�
-- ���s��Ȃ��D�܂��C�{�\�[�X�R�[�h�̗��p�ɂ�蒼�ړI�܂��͊ԐړI�ɐ�����������
-- �鑹�Q�Ɋւ��Ă��C���̐ӔC�𕉂�Ȃ��D
--
--

--
-- TaC/tac_tec.vhd : TaC TeC CONSOLE
--
-- 2019.02.03           : �V�K�쐬
--
-- $Id
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

--use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;

entity TAC_TEC is
    Port ( P_CLK      : in  std_logic;
           P_RESET    : in  std_logic;
           P_EN       : in  std_logic;
           P_IOR      : in  std_logic;
           P_IOW      : in  std_logic;
           P_ADDR     : in  std_logic_vector (1 downto 0);
           P_DIN      : in  std_logic_vector (7 downto 0);
           P_DOUT     : out std_logic_vector (7 downto 0);

           P_TEC_DLED : in std_logic_vector(7 downto 0);
           P_TEC_DSW  : out std_logic_vector(7 downto 0);
           P_TEC_FNC  : out std_logic_vector(7 downto 0);
           P_TEC_CTL  : out std_logic_vector(2 downto 0);
           P_TEC_ENA  : out std_logic;
           P_TEC_RESET: in std_logic;
           P_TEC_SETA : in std_logic
         );
end TAC_TEC;

architecture Behavioral of TAC_TEC is
  signal i_dsw : std_logic_vector(7 downto 0);
  signal i_fnc : std_logic_vector(7 downto 0);
  signal i_ctl : std_logic_vector(3 downto 0);

begin
  process(P_RESET, P_CLK)
  begin
    if (P_RESET='0') then
      i_dsw <= "00000000";
      i_fnc <= "00000000";
      i_ctl <= "0000";
    elsif (P_CLK'event and P_CLK='1') then
      if (P_EN='1' and P_IOW='1') then
        if (P_ADDR="01") then
          i_dsw <= P_DIN;
        elsif (P_ADDR="10") then
          i_fnc <= P_DIN;
        elsif (P_ADDR="11") then
          i_ctl(2 downto 0) <= P_DIN(2 downto 0);
          i_ctl(3) <= P_DIN(7);
        end if;
      end if;
    end if;
  end process;

  P_TEC_DSW <= i_dsw;
  P_TEC_FNC <= i_fnc;
  P_TEC_CTL <= i_ctl(2 downto 0);
  P_TEC_ENA <= i_ctl(3);

  P_DOUT <= P_TEC_DLED when (P_ADDR="00") else
            "000000" & P_TEC_RESET & P_TEC_SETA when (P_ADDR="11") else
            "00000000";
end Behavioral;

