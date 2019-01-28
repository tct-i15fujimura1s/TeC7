--
-- TeC7 VHDL Source Code
--    Tokuyama kousen Educational Computer Ver.7
--
-- Copyright (C) 2011 - 2014 by
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
-- TaC/tac_ram.vhd : TaC Main Mamory
--

--
-- 2014.01.10           : DMA�Ή��i�f���A���|�[�g�Łj
-- 2012.09.26           : TAC-CPU V2 �Ή�����
-- 2012.01.22           : entity ���A������
-- 2011.09.19           : �V�K�쐬
--
-- $Id
--

library IEEE;
use std.textio.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_textio.all;

entity TAC_RAM is
  port (
    P_CLK   : in  std_logic;
    -- for CPU
    P_AIN1   : in  std_logic_vector(15 downto 0);
    P_DIN1   : in  std_logic_vector(15 downto 0);
    P_DOUT1  : out std_logic_vector(15 downto 0);
    P_RW1    : in  std_logic;
    P_MR1    : in  std_logic;
    P_BT     : in  std_logic;
    -- for DMA
    P_AIN2   : in  std_logic_vector(14 downto 0);
    P_DIN2   : in  std_logic_vector(15 downto 0);
    P_DOUT2  : out std_logic_vector(15 downto 0);
    P_RW2    : in  std_logic;
    P_MR2    : in  std_logic
  );
end TAC_RAM;

architecture BEHAVE of TAC_RAM is
  subtype Word is std_logic_vector(15 downto 0);
  subtype Byte is std_logic_vector(7 downto 0);
  type Mem32kB is array(0 to 32767) of Byte;           -- 32kB
  type Mem16kB is array(0 to 16383) of Byte;           -- 16kB
  type Mem8kB  is array(0 to  8191) of Byte;           --  8kB
  type Mem4kB  is array(0 to  4095) of Byte;           --  4kB
  type Mem2kw  is array(0 to  2047) of Word;           --  2kw(4kB)
  function read_file (fname : in string) return Mem2kw is
    file data_in : text is in fname;
    variable line_in: line;
    variable ram : Mem2kw;
    begin
      for i in 0 to 2047 loop
        readline (data_in, line_in);
        read(line_in, ram(i));
      end loop;
      return ram;
    end function;

  -- Bank0(0000H-7FFFH)
  shared variable memB0H : Mem16kB;                            -- even address
  shared variable memB0L : Mem16kB;                            -- odd  address
  signal memB0     : std_logic_vector(15 downto 0);
  signal memB0_dma : std_logic_vector(15 downto 0);

  -- Bank1(8000H-BFFFH)
  shared variable memB1H : Mem8kB;                             -- even address
  shared variable memB1L : Mem8kB;                             -- odd  address
  signal memB1     : std_logic_vector(15 downto 0);
  signal memB1_dma : std_logic_vector(15 downto 0);
  
  -- Bank2(C000H-DFFFH)
  shared variable memB2H : Mem4kB;                             -- even address
  shared variable memB2L : Mem4kB;                             -- odd  address
  signal memB2     : std_logic_vector(15 downto 0);
  signal memB2_dma : std_logic_vector(15 downto 0);
  
  -- BankIPL(F800H-FFFFH)
  signal memBIHL   : Mem2kw := read_file("tac_ram.txt");
  signal memBI     : std_logic_vector(15 downto 0);

  signal csB0   : std_logic;                          -- CS Bank0
  signal csB1   : std_logic;                          -- CS Bank1
  signal csB2   : std_logic;                          -- CS Bank2
  signal csBI   : std_logic;                          -- CS BankIPL

  signal weB0   : std_logic;                          -- WE Bank0
  signal weB1   : std_logic;                          -- WE Bank1
  signal weB2   : std_logic;                          -- WE Bank2
  signal weBI   : std_logic;                          -- WE BankIPL
    
  signal high   : std_logic;
  signal low    : std_logic;

  -- DMA
  signal csB0_dma   : std_logic;                      -- CS Bank0
  signal csB1_dma   : std_logic;                      -- CS Bank1
  signal csB2_dma   : std_logic;                      -- CS Bank2
  signal weB0_dma   : std_logic;                      -- WE Bank0
  signal weB1_dma   : std_logic;                      -- WE Bank1
  signal weB2_dma   : std_logic;                      -- WE Bank2
  
  begin
    -- bank select
    csB0 <= (not P_AIN1(15));                         -- 0000H - 7FFFH
    csB1 <=  P_AIN1(15) and (not P_AIN1(14));         -- 8000H - BFFFH
    csB2 <=  P_AIN1(15) and P_AIN1(14)
               and (not P_AIN1(13));                  -- C000H - DFFFH
    csBI <= P_AIN1(15) and P_AIN1(14) and
             P_AIN1(13) and P_AIN1(12) ;              -- F000H - FFFFH

    -- read control
    P_DOUT1 <= memB0 when (csB0='1')
          else memB1 when (csB1='1')
          else memB2 when (csB2='1')
          else memBI when (csBI='1')
          else "0000000000000000";
 
    -- write control
    weB0 <= csB0 and P_MR1 and P_RW1;
    weB1 <= csB1 and P_MR1 and P_RW1;
    weB2 <= csB2 and P_MR1 and P_RW1;
    weBI <= csBI and P_MR1 and P_RW1 and              -- RAM (FFE0H - FFFFH)
            (P_AIN1(11) and P_AIN1(10) and P_AIN1(9) and
             P_AIN1(8) and P_AIN1(7) and P_AIN1(6) and P_AIN1(5));

    -- byte control
    high <= not (P_AIN1(0) and P_BT);
    low  <= not ((not P_AIN1(0)) and P_BT);

    -- Bank0H(CPU)
    process(P_CLK)
      begin
        if (P_CLK'event and P_CLK='0') then
          if (weB0='1' and high='1') then
            memB0H(conv_integer(P_AIN1(14 downto 1))) := P_DIN1(15 downto 8);
          end if;
          memB0(15 downto 8) <= memB0H(conv_integer(P_AIN1(14 downto 1)));
        end if;
      end process;

    -- Bank0L(CPU)
    process(P_CLK)
      begin
        if (P_CLK'event and P_CLK='0') then
          if (weB0='1' and low='1') then
            memB0L(conv_integer(P_AIN1(14 downto 1))) := P_DIN1(7 downto 0);
          end if;
          memB0(7 downto 0) <= memB0L(conv_integer(P_AIN1(14 downto 1)));
        end if;
      end process;

    -- Bank1H(CPU)
    process(P_CLK)
      begin
        if (P_CLK'event and P_CLK='0') then
          if (weB1='1' and high='1') then
            memB1H(conv_integer(P_AIN1(13 downto 1))) := P_DIN1(15 downto 8);
          end if;
          memB1(15 downto 8) <= memB1H(conv_integer(P_AIN1(13 downto 1)));
        end if;
      end process;

    -- Bank1L(CPU)
    process(P_CLK)
      begin
        if (P_CLK'event and P_CLK='0') then
          if (weB1='1' and low='1') then
            memB1L(conv_integer(P_AIN1(13 downto 1))) := P_DIN1(7 downto 0);
          end if;
          memB1(7 downto 0) <= memB1L(conv_integer(P_AIN1(13 downto 1)));
        end if;
      end process;

    -- Bank2H(CPU)
    process(P_CLK)
      begin
        if (P_CLK'event and P_CLK='0') then
          if (weB2='1' and high='1') then
            memB2H(conv_integer(P_AIN1(12 downto 1))) := P_DIN1(15 downto 8);
          end if;
          memB2(15 downto 8) <= memB2H(conv_integer(P_AIN1(12 downto 1)));
        end if;
      end process;

    -- Bank2L(CPU)
    process(P_CLK)
      begin
        if (P_CLK'event and P_CLK='0') then
          if (weB2='1' and low='1') then
            memB2L(conv_integer(P_AIN1(12 downto 1))) := P_DIN1(7 downto 0);
          end if;
          memB2( 7 downto 0) <= memB2L(conv_integer(P_AIN1(12 downto 1)));
        end if;
      end process;

    -- BankI(CPU)
    process(P_CLK)
      begin
        if (P_CLK'event and P_CLK='0') then
          if (weBI='1') then
            memBIHL(conv_integer(P_AIN1(11 downto 1))) <= P_DIN1;
          end if;
          memBI <= memBIHL(conv_integer(P_AIN1(11 downto 1)));
        end if;
      end process;

    -- bank select(DMA)
    csB0_dma <= (not P_AIN2(14));                      -- 0000H - 7FFFH
    csB1_dma <=  P_AIN2(14) and (not P_AIN2(13));      -- 8000H - BFFFH
    csB2_dma <=  P_AIN2(14) and P_AIN2(13)
                and (not P_AIN2(12));                  -- C000H - DFFFH

    -- write control(DMA)
    weB0_dma <= csB0_dma and P_MR2 and P_RW2;
    weB1_dma <= csB1_dma and P_MR2 and P_RW2;
    weB2_dma <= csB2_dma and P_MR2 and P_RW2;

    -- read control(DMA)
    P_DOUT2 <= memB0_dma when (csB0_dma='1')
            else memB1_dma when (csB1_dma='1')
            else memB2_dma when (csB2_dma='1')
            else "0000000000000000";

    -- Bank0H(DMA)
    process(P_CLK)
      begin
        if (P_CLK'event and P_CLK='0') then
          if (weB0_dma='1') then
            memB0H(conv_integer(P_AIN2(13 downto 0))) := P_DIN2(15 downto 8);
          end if;
        memB0_dma(15 downto 8) <= memB0H(conv_integer(P_AIN2(13 downto 0)));
        end if;
      end process;

    -- Bank0L(DMA)
    process(P_CLK)
      begin
        if (P_CLK'event and P_CLK='0') then
          if (weB0_dma='1') then
            memB0L(conv_integer(P_AIN2(13 downto 0))) := P_DIN2(7 downto 0);
          end if;
          memB0_dma(7 downto 0) <= memB0L(conv_integer(P_AIN2(13 downto 0)));
        end if;
      end process;

    -- Bank1H(DMA)
    process(P_CLK)
      begin
        if (P_CLK'event and P_CLK='0') then
          if (weB1_dma='1') then
            memB1H(conv_integer(P_AIN2(12 downto 0))) := P_DIN2(15 downto 8);
          end if;
          memB1_dma(15 downto 8) <= memB1H(conv_integer(P_AIN2(12 downto 0)));
        end if;
      end process;

    -- Bank1L(DMA)
    process(P_CLK)
      begin
        if (P_CLK'event and P_CLK='0') then
          if (weB1_dma='1') then
            memB1L(conv_integer(P_AIN2(12 downto 0))) := P_DIN2(7 downto 0);
          end if;
          memB1_dma(7 downto 0) <= memB1L(conv_integer(P_AIN2(12 downto 0)));
        end if;
      end process;

    -- Bank2H(DMA)
    process(P_CLK)
      begin
        if (P_CLK'event and P_CLK='0') then
          if (weB2_dma='1') then
            memB2H(conv_integer(P_AIN2(11 downto 0))) := P_DIN2(15 downto 8);
          end if;
          memB2_dma(15 downto 8) <= memB2H(conv_integer(P_AIN2(11 downto 0)));
        end if;
      end process;

    -- Bank2L(DMA)
    process(P_CLK)
      begin
        if (P_CLK'event and P_CLK='0') then
          if (weB2_dma='1') then
            memB2L(conv_integer(P_AIN2(11 downto 0))) := P_DIN2(7 downto 0);
          end if;
          memB2_dma( 7 downto 0) <= memB2L(conv_integer(P_AIN2(11 downto 0)));
        end if;
      end process;
end BEHAVE;
