--
-- TeC7 VHDL Source Code
--    Tokuyama kousen Educational Computer Ver.7
--
-- Copyright (C) 2011 - 2019 by
--                      Dept. of Computer Science and Electronic Engineering,
--                      Tokuyama College of Technology, JAPAN
--
--   上記著作権者は，Free Software Foundation によって公開されている GNU 一般公
-- 衆利用許諾契約書バージョン２に記述されている条件を満たす場合に限り，本ソース
-- コード(本ソースコードを改変したものを含む．以下同様)を使用・複製・改変・再配
-- 布することを無償で許諾する．
--
--   本ソースコードは＊全くの無保証＊で提供されるものである。上記著作権者および
-- 関連機関・個人は本ソースコードに関して，その適用可能性も含めて，いかなる保証
-- も行わない．また，本ソースコードの利用により直接的または間接的に生じたいかな
-- る損害に関しても，その責任を負わない．
--
--
-- TaC/tac_ram.vhd : TaC Main Mamory
--

--
-- 2019.02.28           : IPLを3バンク化
-- 2017.05.06           : TaC7b 対応 (60KiB)
-- 2014.01.10           : DMA対応（デュアルポート版）
-- 2012.09.26           : TAC-CPU V2 対応完了
-- 2012.01.22           : entity 名、見直し
-- 2011.09.19           : 新規作成
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
    P_CLK    : in  std_logic;
    P_RESET  : in  std_logic;
    P_IOE    : in  std_logic;                          -- I/O Enable
    P_IOW    : in  std_logic;                          -- I/O Write
    -- for CPU
    P_AIN1   : in  std_logic_vector(15 downto 0);      -- Byte Addressing
    P_DIN1   : in  std_logic_vector(15 downto 0);
    P_DOUT1  : out std_logic_vector(15 downto 0);
    P_RW1    : in  std_logic;
    P_MR1    : in  std_logic;
    P_BT     : in  std_logic;
    -- for DMA
    P_AIN2   : in  std_logic_vector(14 downto 0);      -- Word Addressing
    P_DIN2   : in  std_logic_vector(15 downto 0);
    P_DOUT2  : out std_logic_vector(15 downto 0);
    P_RW2    : in  std_logic;
    P_MR2    : in  std_logic
  );
end TAC_RAM;

architecture BEHAVE of TAC_RAM is
  subtype Word is std_logic_vector(15 downto 0);
  subtype Byte is std_logic_vector(7 downto 0);
  type Mem16kB is array(0 to 16383) of Byte;           -- 16kB
  type Mem8kB  is array(0 to  8191) of Byte;           --  8kB
  type Mem4kB  is array(0 to  4095) of Byte;           --  4kB
  type Mem2kB  is array(0 to  2047) of Byte;           --  2kB
  type Mem1kB  is array(0 to  1024) of Byte;           --  2kB
  type Mem2kw  is array(0 to  2047) of Word;           --  2kw(4kB,IPL)
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
  
  -- Bank3(E000H-EFFFH)
  shared variable memB3H : Mem2kB;                             -- even address
  shared variable memB3L : Mem2kB;                             -- odd  address
  signal memB3     : std_logic_vector(15 downto 0);
  signal memB3_dma : std_logic_vector(15 downto 0);

  -- Bank4(F000H-FFFFH)
  shared variable memB4H : Mem1kB;                             -- even address
  shared variable memB4L : Mem1kB;                             -- odd  address
  signal memB4     : std_logic_vector(15 downto 0);
  signal memB4_dma : std_logic_vector(15 downto 0);

  -- IPL bank register
  signal iplBank   : std_logic_vector(1 downto 0);  -- 00:IPL0, 01:IPL1, 1?:RAM

  -- BankIPL0(F000H-FFFFH)
  signal memBI0HL  : Mem2kw := read_file("tac_ram0.txt");
  signal memBI0    : std_logic_vector(15 downto 0);

  -- BankIPL1(F000H-FFFFH)
  signal memBI1HL   : Mem2kw := read_file("tac_ram1.txt");
  signal memBI1     : std_logic_vector(15 downto 0);

  -- CPU
  signal csB0   : std_logic;                          -- CS Bank0
  signal csB1   : std_logic;                          -- CS Bank1
  signal csB2   : std_logic;                          -- CS Bank2
  signal csB3   : std_logic;                          -- CS Bank3
  signal csB4   : std_logic;                          -- CS Bank4

  signal weB0   : std_logic;                          -- WE Bank0
  signal weB1   : std_logic;                          -- WE Bank1
  signal weB2   : std_logic;                          -- WE Bank2
  signal weB3   : std_logic;                          -- WE Bank3
  signal weB4   : std_logic;                          -- WE Bank4
    
  signal high   : std_logic;                          -- High Byte
  signal low    : std_logic;                          -- Low  Byte

  -- DMA
  signal csB0_dma   : std_logic;                      -- CS Bank0
  signal csB1_dma   : std_logic;                      -- CS Bank1
  signal csB2_dma   : std_logic;                      -- CS Bank2
  signal csB3_dma   : std_logic;                      -- CS Bank3
  signal csB4_dma   : std_logic;                      -- CS Bank4

  signal weB0_dma   : std_logic;                      -- WE Bank0
  signal weB1_dma   : std_logic;                      -- WE Bank1
  signal weB2_dma   : std_logic;                      -- WE Bank2
  signal weB3_dma   : std_logic;                      -- WE Bank3
  signal weB4_dma   : std_logic;                      -- WE Bank4
  
  begin
    -- IPL bank register
    process(P_RESET, P_CLK)
    begin
      if (P_RESET='0') then
        iplBank <= "00";                              -- IPL0
      elsif (P_CLK'event and P_CLK='1') then
        if (P_IOE='1' and P_IOW='1') then
          iplBank <= P_DIN1(1 downto 0);
        end if;
      end if;
    end process;

    -- bank select
    csB0 <= (not P_AIN1(15));                         -- 0000H - 7FFFH
    csB1 <=  P_AIN1(15) and (not P_AIN1(14));         -- 8000H - BFFFH
    csB2 <=  P_AIN1(15) and P_AIN1(14)
               and (not P_AIN1(13));                  -- C000H - DFFFH
    csB3 <=  P_AIN1(15) and P_AIN1(14) and
              P_AIN1(13) and (not P_AIN1(12));        -- E000H - EFFFH
    csB4 <=  P_AIN1(15) and P_AIN1(14) and
              P_AIN1(13) and P_AIN1(12);              -- F000H - FFFFH

    -- read control
    P_DOUT1 <= memB0 when (csB0='1')
          else memB1 when (csB1='1')
          else memB2 when (csB2='1')
          else memB3 when (csB3='1')
          else memB4 when (csB4='1' and iplBank(1)='1')  -- RAM(4kB)
          else memBI0 when (csB4='1' and iplBank(0)='0') -- IPL ROM0(2kW)
          else memBI1 when (csB4='1' and iplBank(0)='1') -- IPL ROM1(2kW)
          else "0000000000000000";
 
    -- write control
    weB0 <= csB0 and P_MR1 and P_RW1;
    weB1 <= csB1 and P_MR1 and P_RW1;
    weB2 <= csB2 and P_MR1 and P_RW1;
    weB3 <= csB3 and P_MR1 and P_RW1;
    weB4 <= csB4 and P_MR1 and P_RW1;

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

    -- Bank3H(CPU)
    process(P_CLK)
      begin
        if (P_CLK'event and P_CLK='0') then
          if (weB3='1' and high='1') then
            memB3H(conv_integer(P_AIN1(11 downto 1))) := P_DIN1(15 downto 8);
          end if;
          memB3(15 downto 8) <= memB3H(conv_integer(P_AIN1(11 downto 1)));
        end if;
      end process;

    -- Bank3L(CPU)
    process(P_CLK)
      begin
        if (P_CLK'event and P_CLK='0') then
          if (weB3='1' and low='1') then
            memB3L(conv_integer(P_AIN1(11 downto 1))) := P_DIN1(7 downto 0);
          end if;
          memB3( 7 downto 0) <= memB3L(conv_integer(P_AIN1(11 downto 1)));
        end if;
      end process;

    -- Bank4H(CPU)
    process(P_CLK)
      begin
        if (P_CLK'event and P_CLK='0') then
          if (weB4='1' and high='1') then
            memB4H(conv_integer(P_AIN1(11 downto 1))) := P_DIN1(15 downto 8);
          end if;
          memB4(15 downto 8) <= memB4H(conv_integer(P_AIN1(11 downto 1)));
        end if;
      end process;
--    memB4(15 downto 8) <= "00000000";

    -- Bank4L(CPU)
    process(P_CLK)
      begin
        if (P_CLK'event and P_CLK='0') then
          if (weB4='1' and low='1') then
            memB4L(conv_integer(P_AIN1(11 downto 1))) := P_DIN1(7 downto 0);
          end if;
          memB4( 7 downto 0) <= memB4L(conv_integer(P_AIN1(11 downto 1)));
        end if;
      end process;
--    memB4(7 downto 0) <= "00000000";

    -- BankI0(CPU)
    process(P_CLK)
      begin
        if (P_CLK'event and P_CLK='0') then
          memBI0 <= memBI0HL(conv_integer(P_AIN1(11 downto 1)));
        end if;
      end process;

    -- BankI1(CPU)
    process(P_CLK)
      begin
        if (P_CLK'event and P_CLK='0') then
          memBI1 <= memBI1HL(conv_integer(P_AIN1(11 downto 1)));
        end if;
      end process;

    -- bank select(DMA)
    csB0_dma <= (not P_AIN2(14));                      -- 0000H - 7FFFH
    csB1_dma <=  P_AIN2(14) and (not P_AIN2(13));      -- 8000H - BFFFH
    csB2_dma <=  P_AIN2(14) and P_AIN2(13)
                  and (not P_AIN2(12));                -- C000H - DFFFH
    csB3_dma <=  P_AIN2(14) and P_AIN2(13) and
                  P_AIN2(12) and (not P_AIN2(11));     -- E000H - EFFFH
    csB4_dma <=  P_AIN2(14) and P_AIN2(13) and
                  P_AIN2(12) and P_AIN2(11);           -- F000H - FFFFH

    -- write control(DMA)
    weB0_dma <= csB0_dma and P_MR2 and P_RW2;
    weB1_dma <= csB1_dma and P_MR2 and P_RW2;
    weB2_dma <= csB2_dma and P_MR2 and P_RW2;
    weB3_dma <= csB3_dma and P_MR2 and P_RW2;
    weB4_dma <= csB4_dma and P_MR2 and P_RW2;

    -- read control(DMA)
    P_DOUT2 <= memB0_dma when (csB0_dma='1')
            else memB1_dma when (csB1_dma='1')
            else memB2_dma when (csB2_dma='1')
            else memB3_dma when (csB3_dma='1')
            else memB4_dma when (csB4_dma='1')
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

    -- Bank3H(DMA)
    process(P_CLK)
      begin
        if (P_CLK'event and P_CLK='0') then
          if (weB3_dma='1') then
            memB3H(conv_integer(P_AIN2(10 downto 0))) := P_DIN2(15 downto 8);
          end if;
          memB3_dma(15 downto 8) <= memB3H(conv_integer(P_AIN2(10 downto 0)));
        end if;
      end process;

    -- Bank3L(DMA)
    process(P_CLK)
      begin
        if (P_CLK'event and P_CLK='0') then
          if (weB3_dma='1') then
            memB3L(conv_integer(P_AIN2(10 downto 0))) := P_DIN2(7 downto 0);
          end if;
          memB3_dma( 7 downto 0) <= memB3L(conv_integer(P_AIN2(10 downto 0)));
        end if;
      end process;

    -- Bank4H(DMA)
    process(P_CLK)
      begin
        if (P_CLK'event and P_CLK='0') then
          if (weB4_dma='1') then
            memB4H(conv_integer(P_AIN2(10 downto 0))) := P_DIN2(15 downto 8);
          end if;
          memB4_dma(15 downto 8) <= memB4H(conv_integer(P_AIN2(10 downto 0)));
        end if;
      end process;
--    memB4_dma(15 downto 8) <= "00000000";

--    -- Bank3L(DMA)
    process(P_CLK)
      begin
        if (P_CLK'event and P_CLK='0') then
          if (weB4_dma='1') then
            memB4L(conv_integer(P_AIN2(10 downto 0))) := P_DIN2(7 downto 0);
          end if;
          memB4_dma( 7 downto 0) <= memB4L(conv_integer(P_AIN2(10 downto 0)));
        end if;
      end process;
--    memB4_dma(7 downto 0) <= "00000000";
end BEHAVE;
