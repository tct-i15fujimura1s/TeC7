--
-- TeC7 VHDL Source Code
--    Tokuyama kousen Educational Computer Ver.7
--
-- Copyright (C) 2011 - 2019 by
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
-- TaC/tac_spi.vhd : TaC SPI
--
-- 2019.02.16 : �O��̕ύX�ӏ��� P_CD ���Z���V�r���e�B���X�g�ɒǉ��Y�����
-- 2019.02.09 : �}�C�N��SD�J�[�h�̑}�������m�ł���悤�ɂ���
-- 2016.01.10 : �\�����Ȃ���������������o�O���C��(�G�b�W�g���K�[�̏����ǉ�)
-- 2016.01.08 : ior_blk_addr �폜(warning �΍�)
-- 2014.02.24 : DMA�@�\�쐬(�암����)
-- 2012.01.22 : entity ���A������
-- 2011.12.20 : �V�K�쐬
--
-- $Id
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_ARITH.ALL;
use IEEE.std_logic_UNSIGNED.ALL;

entity TAC_SPI is
  Port ( P_CLK    : in  std_logic;
         P_RESET    : in  std_logic;
         P_EN      : in  std_logic;
         P_IOR    : in  std_logic;
         P_IOW    : in  std_logic;
         P_INT    : out std_logic;
         P_ADDR    : in  std_logic_vector( 1 downto 0);
         P_DIN    : in  std_logic_vector(15 downto 0);  -- from CPU
         P_DOUT    : out std_logic_vector(15 downto 0);  -- to CPU
       
         -- DMA�֘A
         P_ADDR_DMA  : out std_logic_vector(14 downto 0);
         P_DIN_DMA  : in  std_logic_vector(15 downto 0);
         P_DOUT_DMA  : out std_logic_vector(15 downto 0);
         P_RW_DMA    : out std_logic;
         P_MR_DMA    : out std_logic;
       
         -- uSD�[�q
         P_SCLK    : out std_logic;
         P_DI      : in  std_logic;
         P_DO      : out std_logic;
         P_CS      : out std_logic;
         P_ACC     : out std_logic;
         P_CD      : in  std_logic
      );
end TAC_SPI;

architecture Behavioral of TAC_SPI is
  
  -- �萔
  constant CMD0    : std_logic_vector(47 downto 0) := X"400000000095";
  constant CMD1    : std_logic_vector(47 downto 0) := X"410000000001";
  --constant CMD9    : std_logic_vector(47 downto 0) := X"490000000001";
  constant CMD16    : std_logic_vector(47 downto 0) := X"500000020001";
  constant CMD17    : std_logic_vector( 7 downto 0) := X"51";
  constant CMD24    : std_logic_vector( 7 downto 0) := X"58";
  constant START_BYTE  : std_logic_vector( 7 downto 0) := X"FE";
  constant CRC    : std_logic_vector( 7 downto 0) := X"01";
  
  -- �z����
  signal i_init_cs  : std_logic;
  signal i_init_sclk  : std_logic;
  signal i_init_do  : std_logic;
  signal i_init_led  : std_logic;
  
  signal i_read_cs  : std_logic;
  signal i_read_sclk  : std_logic;
  signal i_read_do  : std_logic;
  signal i_read_led  : std_logic;
  
  signal i_write_cs  : std_logic;
  signal i_write_sclk  : std_logic;
  signal i_write_do  : std_logic;
  signal i_write_led  : std_logic;
  
  signal i_read_mr  : std_logic;  -- memory req(DMA�p)
  signal i_write_mr  : std_logic;  -- memory req(DMA�p)
  
  
  -- �f�R�[�h����
  signal IOW_SPI_Ctl  : std_logic;  -- �R���g���[���̏�������
  signal IOR_SPI_Sta  : std_logic;  -- �X�e�[�^�X�̓ǂݍ���
  signal IOW_Mem_Addr : std_logic;  -- �������A�h���X�̏�������
  signal IOR_Mem_Addr : std_logic;  --       �V      �̓ǂݍ���
  signal IOW_Blk_Addr : std_logic;  -- �u���b�N�A�h���X�̏�������
--signal IOR_Blk_Addr : std_logic;  --        �V       �̓ǂݍ���
                    -- (���16bit������16bit���́AP_ADDR(0)�ŋ��)
  
  -- ���W�X�^
  signal Memory_Addr : std_logic_vector(15 downto 0);   -- �������A�h���X
  signal Block_Addr  : std_logic_vector(31 downto 0);   -- �u���b�N�A�h���X
  signal Data_Addr   : std_logic_vector(31 downto 0);   -- �f�[�^�A�h���X
  signal Int_Ena     : std_logic;                       -- ���荞�݋���
  signal Processing  : std_logic := '0';                -- ������(uSD�ƒʐM��)
  signal ProcessingD : std_logic := '0';                -- 1�N���b�N�x��̐M��
  signal Error       : std_logic := '0';                -- �G���[����������
  signal Idle        : std_logic := '0';
  signal Interrupt   : std_logic := '0';                -- ������
  
  -- Init
  signal Init_Req     : std_logic;                     -- ���������N�G�X�g
  signal Initializing : std_logic;                     -- ��������FF
  signal Init_State   : std_logic_vector( 3 downto 0); -- �X�e�[�g
  signal Init_Counter : std_logic_vector( 7 downto 0); -- �ėp�J�E���^
  signal Init_Clk_Cnt : std_logic_vector( 7 downto 0); -- 400kHz�����p�J�E���^
  signal Init_Byte_Buffer : std_logic_vector( 7 downto 0); -- �o�C�g�o�b�t�@
  signal Init_Error       : std_logic;                     -- �G���[����FF
  
  -- Read
  signal Read_Req     : std_logic;                     -- �ǂݍ��݃��N�G�X�g
  signal Reading      : std_logic;                     -- �ǂݍ��ݒ�FF
  signal Read_State   : std_logic_vector( 2 downto 0); -- �X�e�[�g
  signal Read_Counter : std_logic_vector( 7 downto 0); -- �ėp�J�E���^
  signal Read_Clk_Cnt : std_logic_vector( 7 downto 0); -- 25MkHz�����p�J�E���^
  signal Read_Byte_Buffer : std_logic_vector( 7 downto 0); -- �o�C�g�o�b�t�@
  signal Read_Error       : std_logic;            -- �G���[����FF
  
  signal Read_Counter256 : std_logic_vector( 7 downto 0); -- �f�[�^��M�J�E���^
  signal Read_Word_Buffer : std_logic_vector(15 downto 0);  -- ���[�h�o�b�t�@
  
  -- Write
  signal Write_Req     : std_logic;            -- �������݃��N�G�X�g
  signal Writing       : std_logic;            -- �������ݒ�FF
  signal Write_State   : std_logic_vector( 3 downto 0);  -- �X�e�[�g
  signal Write_Counter : std_logic_vector( 7 downto 0);  -- �ėp�J�E���^
  signal Write_Clk_Cnt : std_logic_vector( 7 downto 0);  -- 25MHz�����p�J�E���^
  signal Write_Byte_Buffer : std_logic_vector( 7 downto 0);  -- �o�C�g�o�b�t�@
  signal Write_Error       : std_logic;            -- �G���[����FF
  
  signal Write_Counter256 : std_logic_vector( 7 downto 0); -- �f�[�^���M�J�E���^
  signal Write_Word_Buffer  : std_logic_vector(15 downto 0);  -- ���[�h�o�b�t�@
  
  -- DMA
  signal Read_Addr_DMA  : std_logic_vector(14 downto 0);
  signal Write_Addr_DMA  : std_logic_vector(14 downto 0);
  
begin
  
  -- �A�h���X�f�R�[�_
  IOW_SPI_Ctl <=                                                         -- 10h
    '1' when (P_IOW='1' and P_EN='1' and P_ADDR(1 downto 0)="00") else '0';
  IOR_SPI_Sta <=                                                         -- 10h
    '1' when (P_IOR='1' and P_EN='1' and P_ADDR(1 downto 0)="00") else '0';
  IOW_Mem_Addr <=                                                        -- 12h
    '1' when (P_IOW='1' and P_EN='1' and P_ADDR(1 downto 0)="01") else '0';
  IOR_Mem_Addr <=                                                        -- 12h
    '1' when (P_IOR='1' and P_EN='1' and P_ADDR(1 downto 0)="01") else '0';
  IOW_Blk_Addr <=                                                   -- 14h��16h
    '1' when (P_IOW='1' and P_EN='1' and P_ADDR(1)='1') else '0';
--IOR_Blk_Addr <=                                                   -- 14h��16h
--  '1' when (P_IOR='1' and P_EN='1' and P_ADDR(1)='1') else '0';

  -- ������
  Processing <= Initializing or Reading or Writing;

  -- �G���[
  Error <= Init_Error or Read_Error or Write_Error;

  -- �A�C�h��
  Idle <= (not Processing) and (not Error);

  -- ������(�G�b�W�g���K�[�A�P�p���X�o��)
--P_INT <= (Idle or Error) and Int_Ena;
  P_INT <= Interrupt and Int_Ena;
  process (P_CLK, P_RESET)
  begin
    if (P_RESET = '0') then
      ProcessingD <= '0';
      Interrupt   <= '0';
    elsif (P_CLK' event and P_CLK = '1') then
      ProcessingD <= Processing;
      if (ProcessingD='1' and Processing='0') then   -- ��������
        Interrupt <= '1';                            -- �����ݔ���
      else
        Interrupt <= '0';                            -- ���񊄍��݂̏���
      end if;
    end if;
   end process;
  
  -- �������A�h���X
  process (P_CLK, P_RESET)
  begin
    if (P_RESET = '0') then
      Memory_Addr <= (others => '0');
    elsif (P_CLK' event and P_CLK = '1') then
      if (IOW_Mem_Addr = '1') then
        Memory_Addr <= P_DIN;
      end if;
    end if;
  end process;
  
  -- �u���b�N�A�h���X(�f�[�^�A�h���X)
  -- ���F�f�[�^�A�h���X�̓u���b�N�A�h���X��9bit���V�t�g
  process (P_CLK, P_RESET)
  begin
    if (P_RESET = '0') then
      Block_Addr <= (others => '0');
      Data_Addr  <= (others => '0');
    elsif (P_CLK' event and P_CLK = '1') then
      if (IOW_Blk_Addr = '1') then
        -- �u���b�N�A�h���X���16bit(I/O 14h)
        if (P_ADDR(0) = '0') then
          Block_Addr(31 downto 16) <= P_DIN;
          Data_Addr(31 downto 25) <= P_DIN(6 downto 0);
        -- �u���b�N�A�h���X����16bit(I/O 16h)
        else
          Block_Addr(15 downto 0) <= P_DIN;
          Data_Addr(24 downto 9) <= P_DIN;
        end if;
      end if;
    end if;
  end process;
  
  -- �f�[�^�o�X
  -- 
  -- �y�X�e�[�^�X�d�l�z
  -- 
  --   0000 0000 IE00 0000
  -- 
  --   I(Idle)�c�������A�ǂݍ��݁A�������݂̂����������Ɏ��s�\�ł���
  --    I <= (not Processing) and (not Error)
  --   E(Error)�c�������ɃG���[����������
  --     E <= Error
  --
  --   IE = 00  ->  ������
  --   IE = 01  ->  �G���[����������(���������K�v)
  --   IE = 10  ->  �ɂ���
  --   IE = 11  ->  ���肦�Ȃ�
  --
  process(IOR_SPI_Sta,IOR_Mem_Addr,Idle,
          Error,Memory_Addr,Block_Addr,P_ADDR,P_CD)
  begin
    if (IOR_SPI_Sta = '1') then
      P_DOUT <= "00000000" & Idle & Error & "00000" & P_CD; -- �X�e�[�^�X���o��
    elsif (IOR_Mem_Addr = '1') then
      P_DOUT <= Memory_Addr;                            -- �������A�h���X���o��
    elsif (P_ADDR(0) = '0') then
      P_DOUT <= Block_Addr(31 downto 16);    -- �u���b�N�A�h���X���16bit���o��
    else
      P_DOUT <= Block_Addr(15 downto 0);     -- �u���b�N�A�h���X����16bit���o��
    end if;
  end process;
  
  -- �R���g���[��
  process (P_CLK, P_RESET)
  begin
    if (P_RESET = '0') then
      Int_Ena   <= '0';
      Init_Req  <= '0';
      Read_Req  <= '0';
      Write_Req <= '0';
    elsif (P_CLK'event and P_CLK = '1') then
      -- �����ݐݒ�A�����J�n�����b�`
      if (IOW_SPI_Ctl = '1') then
        Int_Ena   <= P_DIN(7);
        Init_Req  <= P_DIN(2);
        Read_Req  <= P_DIN(1);
        Write_Req <= P_DIN(0);
      -- �����J�n���N�G�X�g�͎��̃^�C�~���O�Ŏ�艺����
      else
        if (Initializing = '0') then
          Init_Req <= '0';
        end if;
        if (Reading = '0') then
          Read_Req <= '0';
        end if;
        if (Writing = '0') then
          Write_Req <= '0';
        end if;
      end if;
    end if;
  end process;
  
  -- Init
  process (P_CLK, P_RESET)
  begin
    if (P_RESET = '0') then
      Init_Clk_Cnt     <= "00000000";
      Init_Counter     <= "00000000";
      Init_State       <= "0000";
      Initializing     <= '0';
      Init_Byte_Buffer <= "11111111";
      i_init_cs        <= '1';
      i_init_sclk      <= '1';
      i_init_do        <= '1';
      i_init_led       <= '0';
    elsif (P_CLK' event and P_CLK = '1') then
      if (Initializing = '1') then
        if (Init_Clk_Cnt = 61) then -- ����if���̒���400kHz��(�l�K�e�B�u�G�b�W)
          Init_Clk_Cnt <= Init_Clk_Cnt + 1;
          i_init_sclk <= '0';       -- uSD�̃N���b�N�𗧂�������
          
          case Init_State is
          -- 80��̃_�~�[�N���b�N
          when "0000" =>
            
          -- CMD0�̑��M
          when "0001" =>
            i_init_cs <= '0';
            i_init_do <= CMD0(conv_integer(Init_Counter));
          -- R1���X�|���X(0x01)�҂�
          when "0010" =>
            
          -- 8��̃_�~�[�N���b�N
          when "0011" =>
            i_init_cs <= '1';
          -- CMD1�̑��M
          when "0100" =>
            i_init_cs <= '0';
            i_init_do <= CMD1(conv_integer(Init_Counter));
          -- R1���X�|���X(0x00)�̎�M
          when "0101" =>
            i_init_do <= '1';
          -- 8��̃_�~�[�N���b�N
          when "0110" =>
            i_init_cs <= '1';
            
          -- ��������u���b�N���̕ύX
          -- CMD16�̑��M
          when "0111" =>
            i_init_cs <= '0';
            i_init_do <= CMD16(conv_integer(Init_Counter));
          -- R1���X�|���X(0x00)�̎�M  
          when "1000" =>
            i_init_do <= '1';
          when others =>
          end case;
          
        elsif (Init_Clk_Cnt = 123) then -- 400kHz��(�|�W�e�B�u�G�b�W)
          Init_Clk_Cnt <= "00000000";
          i_init_sclk <= '1';           -- uSD�̃N���b�N�𗧂��グ��
          
          case Init_State is
          -- 80��̃_�~�[�N���b�N
          when "0000" =>
            if (Init_Counter = 0) then
              Init_Counter <= conv_std_logic_vector(47, 8);
              Init_State <= "0001";
            else
              Init_Counter <= Init_Counter - 1;
            end if;
          -- CMD0�̑��M
          when "0001" =>
            if (Init_Counter = 0) then
              Init_Counter <= conv_std_logic_vector(7, 8);
              Init_State <= "0010";
            else
              Init_Counter <= Init_Counter - 1;
            end if;
          -- R1���X�|���X(0x01)�̎�M  
          when "0010" =>
            Init_Byte_Buffer(7 downto 0) <= Init_Byte_Buffer(6 downto 0) & P_DI;
            if (Init_Counter = 0) then
              if (Init_Byte_Buffer(6 downto 0) & P_DI = X"01") then
                Init_Counter <= conv_std_logic_vector(7, 8);
                Init_State <= "0011";
              elsif (Init_Byte_Buffer(6 downto 0) & P_DI = X"FF") then
                Init_Counter <= conv_std_logic_vector(7, 8);
              else
                Init_Error   <= '1';
                Initializing <= '0';
                i_init_cs   <= '1';
                i_init_sclk   <= '1';
                i_init_do   <= '1';
                i_init_led   <= '0';
              end if;
            else
              Init_Counter <= Init_Counter - 1;
            end if;
          -- 8��̃_�~�[�N���b�N
          when "0011" =>
            if (Init_Counter = 0) then
              Init_Counter <= conv_std_logic_vector(47, 8);
              Init_State <= "0100";
            else
              Init_Counter <= Init_Counter - 1;
            end if;
          -- CMD1�̑��M
          when "0100" =>
            if (Init_Counter = 0) then
              Init_Counter <= conv_std_logic_vector(7, 8);
              Init_State <= "0101";
            else
              Init_Counter <= Init_Counter - 1;
            end if;
          -- R1���X�|���X(0x00)�̎�M
          when "0101" =>
            Init_Byte_Buffer(7 downto 0) <= Init_Byte_Buffer(6 downto 0) & P_DI;
            if (Init_Counter = 0) then
              if (Init_Byte_Buffer(6 downto 0) & P_DI = X"00") then
                Init_Counter <= conv_std_logic_vector(7, 8);
                Init_State <= "0110";
              elsif (Init_Byte_Buffer(6 downto 0) & P_DI = X"FF") then
                Init_Counter <= conv_std_logic_vector(7, 8);
              elsif (Init_Byte_Buffer(6 downto 0) & P_DI = X"01") then
                Init_Counter <= conv_std_logic_vector(7, 8);
                Init_State <= "0011";
              else
                Init_Error   <= '1';
                Initializing <= '0';
                i_init_cs   <= '1';
                i_init_sclk   <= '1';
                i_init_do   <= '1';
                i_init_led   <= '0';
              end if;
            else
              Init_Counter <= Init_Counter - 1;
            end if;
          -- 8��̃_�~�[�N���b�N
          when "0110" =>
            if (Init_Counter = 0) then
              Init_Counter <= conv_std_logic_vector(47, 8);
              Init_State <= "0111";
            else
              Init_Counter <= Init_Counter - 1;
            end if;
          -- ��������u���b�N���̕ύX
          -- CMD16�̑��M
          when "0111" =>
            if (Init_Counter = 0) then
              Init_Counter <= conv_std_logic_vector(7, 8);
              Init_State <= "1000";
            else
              Init_Counter <= Init_Counter - 1;
            end if;
          -- R1���X�|���X(0x00)�҂�
          when "1000" =>
            Init_Byte_Buffer(7 downto 0) <= Init_Byte_Buffer(6 downto 0) & P_DI;
            if (Init_Counter = 0) then
              if (Init_Byte_Buffer(6 downto 0) & P_DI = X"00") then
                Initializing <= '0';
                i_init_cs   <= '1';
                i_init_sclk   <= '1';
                i_init_do   <= '1';
                i_init_led   <= '0';
              elsif (Init_Byte_Buffer(6 downto 0) & P_DI = X"FF") then
                Init_Counter <= conv_std_logic_vector(7, 8);
              else
                Init_Error   <= '1';
                Initializing <= '0';
                i_init_cs   <= '1';
                i_init_sclk   <= '1';
                i_init_do   <= '1';
                i_init_led   <= '0';
              end if;
            else
              Init_Counter <= Init_Counter - 1;
            end if;
          when others =>
          end case;
          
        else 
          Init_Clk_Cnt <= Init_Clk_Cnt + 1;
        end if;
      elsif (Init_Req = '1') then        -- ���������N�G�X�g����������
        Initializing   <= '1';           -- ��������FF���Z�b�g
        Init_Clk_Cnt   <= "00000000";
        Init_Counter   <= conv_std_logic_vector(79, 8);  -- 80��̃_�~�[�N���b�N
        Init_State     <= "0000";
        Init_Byte_Buffer <= "11111111";
        i_init_cs     <= '1';
        i_init_sclk     <= '1';
        i_init_do     <= '1';
        i_init_led     <= '1';
      end if;
      
      if (Init_Req = '1') then
        Init_Error <= '0';
      end if;
      
    end if;
  end process;
  
  -- Read
  process (P_CLK, P_RESET)
  begin
    if (P_RESET = '0') then
      Read_Clk_Cnt   <= "00000000";
      Read_Counter   <= "00000000";
      Read_Counter256   <= "00000000";
      Read_State     <= "000";
      Reading       <= '0';
      Read_Byte_Buffer <= "11111111";
      Read_Word_Buffer <= "1111111111111111";
      Read_Addr_DMA   <= "000000000000000";
      i_read_cs     <= '1';
      i_read_sclk     <= '1';
      i_read_do     <= '1';
      i_read_led     <= '0';
      i_read_mr     <= '0';
    elsif (P_CLK' event and P_CLK = '1') then
      if (Reading = '1') then
        if (Read_Clk_Cnt = 0) then   -- ����if���̒���25MHz��(�l�K�e�B�u�G�b�W)
          Read_Clk_Cnt <= Read_Clk_Cnt + 1;
          i_read_sclk <= '0';        -- uSD�̃N���b�N�𗧂�������
          
          case Read_State is
          -- CMD17�̑��M
          -- CMD17
          when "000" =>
            i_read_cs <= '0';
            i_read_do <= CMD17(conv_integer(Read_Counter));
          -- ����(�o�C�g�A�h���X)
          when "001" =>
            i_read_do <= Data_Addr(conv_integer(Read_Counter));
          -- CRC
          when "010" =>
            i_read_do <= CRC(conv_integer(Read_Counter));
          -- R1���X�|���X(0x00)�̎�M
          when "011" =>
            
          -- �X�^�[�g�o�C�g(0xFE)�̎�M
          when "100" =>
            
          -- �f�[�^�u���b�N�̎�M
          when "101" =>
            
          -- 24��̃_�~�[�N���b�N
          when "110" =>
            i_read_cs <= '1';
          when others =>
          end case;
          
        elsif (Read_Clk_Cnt = 1) then -- ����if���̒���25MHz��(�|�W�e�B�u�G�b�W)
          Read_Clk_Cnt <= "00000000";
          i_read_sclk <= '1';         -- uSD�̃N���b�N�𗧂��グ��
          
          case Read_State is
          -- CMD17�̑��M
          -- CMD17
          when "000" =>
            if (Read_Counter = 0) then
              Read_Counter <= conv_std_logic_vector(31, 8);
              Read_State <= "001";
            else
              Read_Counter <= Read_Counter - 1;
            end if;
          -- ����(�o�C�g�A�h���X)
          when "001" =>
            if (Read_Counter = 0) then
              Read_Counter <= conv_std_logic_vector(7, 8);
              Read_State <= "010";
            else
              Read_Counter <= Read_Counter - 1;
            end if;
          -- CRC
          when "010" =>
            if (Read_Counter = 0) then
              Read_Counter <= conv_std_logic_vector(7, 8);
              Read_State <= "011";
            else
              Read_Counter <= Read_Counter - 1;
            end if;
          -- R1���X�|���X(0x00)�̎�M
          when "011" =>
            Read_Byte_Buffer(7 downto 0) <= Read_Byte_Buffer(6 downto 0) & P_DI;
            if (Read_Counter = 0) then
              if (Read_Byte_Buffer(6 downto 0) & P_DI = X"00") then
                Read_Counter <= conv_std_logic_vector(7, 8);
                Read_State <= "100";
              elsif (Read_Byte_Buffer(6 downto 0) & P_DI = X"FF") then
                Read_Counter <= conv_std_logic_vector(7, 8);
              else
                Read_Error  <= '1';
                Reading    <= '0';
                i_read_cs  <= '1';
                i_read_sclk  <= '1';
                i_read_do  <= '1';
                i_read_led  <= '0';
                Read_Addr_DMA <= "000000000000000";
              end if;
            else
              Read_Counter <= Read_Counter - 1;
            end if;
          -- �X�^�[�g�o�C�g(0xFE)�̎�M
          when "100" =>
            Read_Byte_Buffer(7 downto 0) <= Read_Byte_Buffer(6 downto 0) & P_DI;
            if (Read_Counter = 0) then
              if (Read_Byte_Buffer(6 downto 0) & P_DI = X"FE") then
                Read_Counter <= conv_std_logic_vector(15, 8);
                Read_Counter256 <= conv_std_logic_vector(255, 8);
                Read_State <= "101";
              elsif (Read_Byte_Buffer(6 downto 0) & P_DI = X"FF") then
                Read_Counter <= conv_std_logic_vector(7, 8);
              else
                -- �J�[�h�͈͊O�̉\��
                Read_Error  <= '1';
                Reading    <= '0';
                i_read_cs  <= '1';
                i_read_sclk  <= '1';
                i_read_do  <= '1';
                i_read_led  <= '0';
                Read_Addr_DMA <= "000000000000000";
              end if;
            else
              Read_Counter <= Read_Counter - 1;
            end if;
          -- �f�[�^�u���b�N�̎�M
          when "101" =>
            Read_Word_Buffer(15 downto 0) <= Read_Word_Buffer(14 downto 0)&P_DI;
            -- 2�o�C�g(1���[�h)��M������(���[�h��M����)
            if (Read_Counter = 0) then
              Read_Counter <= conv_std_logic_vector(15, 8);
              -- DMA�J�n
              P_DOUT_DMA <= Read_Word_Buffer(14 downto 0) & P_DI;
              if (not (Read_Counter256 = 255)) then
                Read_Addr_DMA <= Read_Addr_DMA + 1;
              end if;
              P_RW_DMA <= '1';
              i_read_mr <= '1';
              -- 512�o�C�g(256���[�h)��M������(�u���b�N��M����)
              if (Read_Counter256 = 0) then
                Read_Counter <= conv_std_logic_vector(24, 8);
                Read_State <= "110";
              else
                Read_Counter256 <= Read_Counter256 - 1;
              end if;
            else
              Read_Counter <= Read_Counter - 1;
            end if;
          -- 24��̃_�~�[�N���b�N
          when "110" =>
            if (Read_Counter = 0) then
              Reading    <= '0';
              i_read_cs  <= '1';
              i_read_sclk  <= '1';
              i_read_do  <= '1';
              i_read_led  <= '0';
              Read_Addr_DMA <= "000000000000000";
            else
              Read_Counter <= Read_Counter - 1;
            end if;
          when others =>
          end case;
        
        else 
          Read_Clk_Cnt <= Read_Clk_Cnt + 1;
        end if;
        
        -- DMA(Buffer -> TaC RAM)
        if (i_read_mr = '1') then
          P_RW_DMA <= '0';
          i_read_mr <= '0';
        end if;
        
      elsif (Read_Req = '1') then        -- �ǂݍ��݃��N�G�X�g����������
        Reading       <= '1';      -- �ǂݍ��ݒ�FF���Z�b�g
        Read_Clk_Cnt   <= "00000000";
        Read_Counter   <= conv_std_logic_vector(7, 8);
        Read_State     <= "000";
        Read_Byte_Buffer <= "11111111";
        Read_Word_Buffer <= "1111111111111111";
        i_read_cs     <= '1';
        i_read_sclk     <= '1';
        i_read_do     <= '1';
        i_read_led     <= '1';
        Read_Addr_DMA   <= Memory_Addr(15 downto 1);
        i_read_mr     <= '0';
      end if;
      
      if (Init_Req = '1') then
        Read_Error <= '0';
      end if;
      
    end if;
  end process;
  
  -- Write
  process (P_CLK, P_RESET)
  begin
    if (P_RESET = '0') then
      Write_Clk_Cnt     <= "00000000";
      Write_Counter     <= "00000000";
      Write_Counter256  <= "00000000";
      Write_State      <= "0000";
      Writing        <= '0';
      Write_Byte_Buffer <= "11111111";
      Write_Word_Buffer <= "0000000000000000";
      Write_Addr_DMA    <= "000000000000000";
      i_write_cs      <= '1';
      i_write_sclk    <= '1';
      i_write_do      <= '1';
      i_write_led      <= '0';
      i_write_mr      <= '0';
    elsif (P_CLK' event and P_CLK = '1') then
      if (Writing = '1') then
        if (Write_Clk_Cnt = 0) then -- ����if���̒���25MHz��(�l�K�e�B�u�G�b�W)
          Write_Clk_Cnt <= Write_Clk_Cnt + 1;
          i_write_sclk <= '0';      -- uSD�̃N���b�N�𗧂�������
                    
          case Write_State is
          -- CMD24�̑��M
          -- CMD24
          when "0000" =>
            i_write_cs <= '0';
            i_write_do <= CMD24(conv_integer(Write_Counter));
          -- ����(�o�C�g�A�h���X)
          when "0001" =>
            i_write_do <= Data_Addr(conv_integer(Write_Counter));
          -- CRC
          when "0010" =>
            i_write_do <= CRC(conv_integer(Write_Counter));
          -- R1���X�|���X(0x00)�̎�M
          when "0011" =>
            i_write_do <= '1';
          -- �X�^�[�g�o�C�g(0xFE)�̑��M
          when "0100" =>
            i_write_do <= START_BYTE(conv_integer(Write_Counter));
          -- �f�[�^�̑��M
          when "0101" =>
            i_write_do <= Write_Word_Buffer(conv_integer(Write_Counter));
            -- DMA�J�n
            if (Write_Counter = 0) then
              i_write_mr <= '1';
              Write_Addr_DMA <= Write_Addr_DMA + 1;
            end if;
          -- CRC(�_�~�[�N���b�N2byte)�̑��M
          when "0110" =>
            i_write_do <= '0';
          -- �f�[�^���X�|���X(0x5)�̎�M
          when "0111" =>
            i_write_do <= '1';
          -- BUSY�̊ԑ҂�
          when "1000" =>
          
          -- 8��̃_�~�[�N���b�N
          when "1001" =>
            i_write_cs <= '1';
          
          when others =>
          end case;
          
        elsif (Write_Clk_Cnt = 1) then -- 25MHz��(�|�W�e�B�u�G�b�W)
          Write_Clk_Cnt <= "00000000";
          i_write_sclk <= '1';      -- uSD�̃N���b�N�𗧂��グ��
          
          case Write_State is
          -- CMD24�̑��M
          -- CMD24
          when "0000" =>
            if (Write_Counter = 0) then
              Write_Counter <= conv_std_logic_vector(31, 8);
              Write_State <= "0001";
            else
              Write_Counter <= Write_Counter - 1;
            end if;
          -- ����(�o�C�g�A�h���X)
          when "0001" =>
            if (Write_Counter = 0) then
              Write_Counter <= conv_std_logic_vector(7, 8);
              Write_State <= "0010";
            else
              Write_Counter <= Write_Counter - 1;
            end if;
          -- CRC
          when "0010" =>
            if (Write_Counter = 0) then
              Write_Counter <= conv_std_logic_vector(7, 8);
              Write_State <= "0011";
            else
              Write_Counter <= Write_Counter - 1;
            end if;
          -- R1���X�|���X(0x00)�̎�M
          when "0011" =>
            Write_Byte_Buffer(7 downto 0) <= Write_Byte_Buffer(6 downto 0)&P_DI;
            if (Write_Counter = 0) then
              if (Write_Byte_Buffer(6 downto 0) & P_DI = X"00") then
                Write_Counter <= conv_std_logic_vector(7, 8);
                Write_State <= "0100";
              elsif (Write_Byte_Buffer(6 downto 0) & P_DI = X"FF") then
                Write_Counter <= conv_std_logic_vector(7, 8);
              else
                Write_Error   <= '1';
                Writing     <= '0';
                i_write_cs   <= '1';
                i_write_sclk <= '1';
                i_write_do   <= '1';
                i_write_led   <= '0';
                Write_Addr_DMA <= "000000000000000";
              end if;
            else
              Write_Counter <= Write_Counter - 1;
            end if;
          -- �X�^�[�g�o�C�g(0xFE)�̑��M
          when "0100" =>
            if (Write_Counter = 0) then
              Write_Counter <= conv_std_logic_vector(15, 8);
              Write_Counter256 <= conv_std_logic_vector(255, 8);
              Write_State <= "0101";
            else
              Write_Counter <= Write_Counter - 1;
            end if;
          -- �f�[�^�̑��M
          when "0101" =>
            if (Write_Counter = 0) then
              Write_Counter <= conv_std_logic_vector(15, 8);
              if (Write_Counter256 = 0) then
                Write_Counter <= conv_std_logic_vector(15, 8);
                Write_State <= "0110";
              else
                Write_Counter256 <= Write_Counter256 - 1;
              end if;
            else
              Write_Counter <= Write_Counter - 1;
            end if;
          -- CRC(�_�~�[�N���b�N2byte)�̑��M
          when "0110" =>
            if (Write_Counter = 0) then
              Write_Counter <= conv_std_logic_vector(7, 8);
              Write_State <= "0111";
            else
              Write_Counter <= Write_Counter - 1;
            end if;
          -- �f�[�^���X�|���X(0x5)�̎�M
          when "0111" =>
            Write_Byte_Buffer(7 downto 0) <= Write_Byte_Buffer(6 downto 0)&P_DI;
            if (Write_Counter = 0) then
              if (Write_Byte_Buffer(6 downto 0) & P_DI = X"FF") then
                Write_Counter <= conv_std_logic_vector(7, 8);
              elsif (Write_Byte_Buffer(3 downto 0) & P_DI = X"5") then
                Write_Counter <= conv_std_logic_vector(7, 8);
                Write_State <= "1000";
              else
                -- �J�[�h�͈͊O�̉\��
                Write_Error   <= '1';
                Writing     <= '0';
                i_write_cs   <= '1';
                i_write_sclk <= '1';
                i_write_do   <= '1';
                i_write_led   <= '0';
                Write_Addr_DMA <= "000000000000000";
              end if;
            else
              Write_Counter <= Write_Counter - 1;
            end if;
          -- busy�̊ԑ҂�
          when "1000" =>
            Write_Byte_Buffer(7 downto 0) <= Write_Byte_Buffer(6 downto 0)&P_DI;
            if (Write_Counter = 0) then
              if (Write_Byte_Buffer(6 downto 0) & P_DI = X"00") then
                Write_Counter <= conv_std_logic_vector(7, 8);
              else
                Write_Counter <= conv_std_logic_vector(7, 8);
                Write_State <= "1001";
              end if;
            else
              Write_Counter <= Write_Counter - 1;
            end if;
          -- 8��̃_�~�[�N���b�N
          when "1001" =>
            if (Write_Counter = 0) then
              Writing     <= '0';
              i_write_cs   <= '1';
              i_write_sclk <= '1';
              i_write_do   <= '1';
              i_write_led   <= '0';
              Write_Addr_DMA <= "000000000000000";
            else 
              Write_Counter <= Write_Counter - 1;
            end if;
          when others =>
          end case;
          
        else 
          Write_Clk_Cnt <= Write_Clk_Cnt + 1;
        end if;
        
        -- DMA(TaC RAM -> Buffer)
        if (i_write_mr = '1') then
          i_write_mr <= '0';
          Write_Word_Buffer <= P_DIN_DMA;
        end if;
        
      elsif (Write_Req = '1') then      -- �������݃��N�G�X�g����������
        Writing        <= '1';      -- �������ݒ�FF���Z�b�g
        Write_Clk_Cnt    <= "00000000";
        Write_Counter    <= conv_std_logic_vector(7, 8);
        Write_State     <= "0000";
        Write_Byte_Buffer <= "11111111";
        Write_Word_Buffer <= "0000000000000000";
        i_write_cs       <= '1';
        i_write_sclk    <= '1';
        i_write_do      <= '1';
        i_write_led      <= '1';
        
        -- ���̃N���b�N�ŁA�ŏ��ɏ������ރ��[�h���o�b�t�@�Ɏ�荞��ł���
        Write_Addr_DMA <= Memory_Addr(15 downto 1);
        i_write_mr <= '1';
      end if;
      
      if (Init_Req = '1') then
        Write_Error <= '0';
      end if;
      
    end if;
  end process;
  
  -- �e�v���Z�X�̔z����uSD�[�q�֏W��
  P_CS   <= i_init_cs and i_read_cs and i_write_cs;
  P_DO   <= i_init_do and i_read_do and i_write_do;
  P_SCLK <= i_init_sclk and i_read_sclk and i_write_sclk;
  P_ACC  <= not (i_init_led or i_read_led or i_write_led);
  
  -- �e�v���Z�X�̔z����DMA�p�[�q�֏W��
  P_ADDR_DMA <= Read_Addr_DMA or Write_Addr_DMA;
  P_MR_DMA <= i_read_mr or i_write_mr;
  
end Behavioral;
