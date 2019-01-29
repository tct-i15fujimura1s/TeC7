--
-- TeC7 VHDL Source Code
--    Tokuyama kousen Educational Computer Ver.7
--
-- Copyright (C) 2011-2019 by
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
-- TaC/tac_mmu.vhd : TaC Memory Management Unit Source Code
--
-- 2019.01.22           : �V�����ǉ�
--

library IEEE;
use IEEE.std_logic_1164.ALL;
use ieee.std_logic_unsigned.all;

entity TAC_MMU is
  Port ( P_CLK      : in  std_logic;
         P_RESET    : in  std_logic;
         P_EN       : in  std_logic;
         P_IOW      : in  std_logic;
         P_MMU_MR   : in  std_logic;                     -- Memory Request(CPU)
         P_PR       : in  std_logic;                     -- Privilege mode
         P_INT      : out std_logic;                     -- Memory Vio inter
         P_MR       : out std_logic;                     -- Memory Request
         P_ADDR     : out std_logic_vector(15 downto 0); -- Physical address
         P_MMU_ADDR : in  std_logic_vector(15 downto 0); -- Virtual address
         P_DIN      : in  std_logic_vector(15 downto 0)
       );
end TAC_MMU;

architecture Behavioral of TAC_MMU is
signal i_en  : std_logic;                                -- Enable resister
signal i_b   : std_logic_vector(15 downto 0);            -- Base  register
signal i_l   : std_logic_vector(15 downto 0);            -- Limit register
signal i_act : std_logic;                                -- Activate
signal i_vio : std_logic;                                -- Violation

begin
  process(P_RESET, P_CLK)
  begin
    if (P_RESET='0') then
      i_b <= "0000000000000000";
      i_l <= "0000000000000000";
      i_en <= '0';
    elsif (P_CLK'event and P_CLK='1') then
      if (P_EN='1' and P_IOW='1') then
        if (P_MMU_ADDR(2)='0') then
          i_en <= P_DIN(0);
        elsif (P_MMU_ADDR(1)='0') then
          i_b <= P_DIN;
        else
          i_l <= P_DIN;
        end if;
      end if;
    end if;
  end process;

  i_act <= (not P_PR) and P_MMU_MR and i_en;
  i_vio <= '1' when ((P_MMU_ADDR>=i_l) and (i_act='1')) else '0';
  P_ADDR <= (P_MMU_ADDR + i_b) when (i_act='1') else P_MMU_ADDR;
  P_MR <= P_MMU_MR and (not i_vio);
  P_INT <= i_vio;
  
end Behavioral;
