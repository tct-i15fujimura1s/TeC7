--
-- TeC7 VHDL Source Code
--    Tokuyama kousen Educational Computer Ver.7
--
-- Copyright (C) 2002-2019 by
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
-- TeC RAM
--
-- 2019.03.01 : �V���O���|�[�g���URAM�ɏ���������
--              �i���Ƃ̓f���A���|�[�g�u���b�NRAM�����������\�[�X�s���j
--

library IEEE;
use std.textio.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_textio.all;

entity TEC_RAM is
  port (
    P_CLK  : in  std_logic;
    P_ADDR : in  std_logic_vector(7 downto 0);
    P_DOUT : out std_logic_vector(7 downto 0);
    P_DIN  : in  std_logic_vector(7 downto 0);
    P_RW   : in  std_logic;
    P_MR   : in  std_logic;

    P_PNA  : in  std_logic_vector(7 downto 0);  -- �p�l���A�h���X
    P_PND  : in  std_logic_vector(7 downto 0);  -- �p�l���p�f�[�^����
    P_SEL  : in  std_logic_vector(2 downto 0);  -- ���[�^���[�X�C�b�`�̈ʒu
    P_WRITE: in  std_logic;                     -- �p�l���������ݐM��
    P_MMD  : out std_logic_vector(7 downto 0);  -- �p�l���p�f�[�^�o��

    P_MODE : in  std_logic_vector(1 downto 0)   -- 0,1:�ʏ�, 2:�f��1, 3:�f��2
-- �f��1 : �d�q�I���S�[���v���O�������͍�
-- �f��2 : �d�q�I���S�[���v���O�����ƃf�[�^�����͍�
  );
end TEC_RAM;

architecture BEHAVE of TEC_RAM is
  subtype word is std_logic_vector(7 downto 0);
  type memory is array(0 to 1023) of word;
  function read_file (fname : in string) return memory is
    file data_in : text is in fname;
    variable line_in: line;
    variable ram : memory;
    begin
      for i in 0 to 1023 loop
        readline (data_in, line_in);
		  read(line_in, ram(i));
      end loop;
      return ram;
    end function;
  signal mem : memory := read_file("tec_ram.txt");

  signal dec   : std_logic;                     -- �A�h���X�f�R�[�h����
  signal we     : std_logic;                    -- �������ݐM��
  signal addr10 : std_logic_vector(9 downto 0); -- 10�r�b�g�ɂ����A�h���X

  signal ain    : std_logic_vector(9 downto 0); -- RAM�̃A�h���X
  signal din    : std_logic_vector(7 downto 0); -- RAM�̏������݃f�[�^
  signal dout   : std_logic_vector(7 downto 0); -- RAM�̓ǂݏo���f�[�^

  begin
    -- CPU��BUS���ߎ��s�Ȃ�CPU�̃A�h���X
    addr10 <= (P_MODE & P_ADDR) when (P_MR='1') else (P_MODE & P_PNA);

    -- �A�h���X�����b�`�����(BLOCK RAM�ɂȂ�)
    ain <= addr10;
--  process(P_CLK)
--    begin
--      if (P_CLK'event and P_CLK='0') then
--        ain <= addr10;
--      end if;
--    end process;

    -- �������݃A�h���X�̃f�R�[�h
    -- MODE=0,1 �̎��� E0H�`FFH ���������ݕs��
    -- MODE=2   �̎��́A������ 80H�`BFH ���������ݕs��
    -- MODE=3   �̎��́A�X�ɉ����� 00H�`7FH ���������ݕs��
    dec<= not ain(7) or not ain(6) or not ain(5) when P_MODE="00" else
          not ain(7) or not ain(6) or not ain(5) when P_MODE="01" else
          not ain(7) or (ain(6) and not ain(5))  when P_MODE="10" else
          ain(7) and ain(6) and not ain(5);

    -- �������ݔ���
    we <= (P_MR and P_RW and dec) or
          (P_WRITE and P_SEL(2) and not P_SEL(1) and P_SEL(0) and dec);

    -- �������ݐ���i�V���O���|�[�g�ɂ���j
    din <= P_DIN when P_MR='1' else P_PND;      -- CPU��BUS���ߎ��s�Ȃ�P_DIN
    process(P_CLK)
      begin
        if (P_CLK'event and P_CLK='0') then
          if (we='1') then
            mem( conv_integer(ain) ) <= din;
          end if;
        end if;
      end process;

    -- �ǂݏo������iCPU�ǂݏo�����Ƀp�l���̕\�����ω����Ȃ��悤�Ɂj
    dout <= mem( conv_integer(ain) );
    P_DOUT <= dout;
    process(P_CLK)
      begin
        if (P_CLK'event and P_CLK='0') then
          if (P_MR='0') then
            P_MMD <= dout;                      -- CPU��BUS���߈ȊO�Ȃ�p�l��
          end if;
        end if;
      end process;
  end BEHAVE;
