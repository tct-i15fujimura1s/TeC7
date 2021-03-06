/*
 * TaC IPL Source Code
 *    Tokuyama kousen Educational Computer 16bit Ver.
 *
 * Copyright (C) 2017-2019 by
 *                      Dept. of Computer Science and Electronic Engineering,
 *                      Tokuyama College of Technology, JAPAN
 *
 *   上記著作権者は，Free Software Foundation によって公開されている GNU 一般公
 * 衆利用許諾契約書バージョン２に記述されている条件を満たす場合に限り，本ソース
 * コード(本ソースコードを改変したものを含む．以下同様)を使用・複製・改変・再配
 * 布することを無償で許諾する．
 *
 *   本ソースコードは＊全くの無保証＊で提供されるものである。上記著作権者および
 * 関連機関・個人は本ソースコードに関して，その適用可能性も含めて，いかなる保証
 * も行わない．また，本ソースコードの利用により直接的または間接的に生じたいかな
 * る損害に関しても，その責任を負わない．
 *
 *
 */

/*
 * util.h : TaC IPL 便利ルーチン
 *
 * 2019.02.27         : sjumpを追加
 * 2019.02.26         : FSMを追加
 * 2017.05.11 v.4.0.0 : 新規作成
 *
 * $Id$
 *
 */

struct FSM { int stat; char[] msg; };
public boolean msgFSM(FSM fsm, char c);

#define putFT232(c) putSIO(0x08, c)           // FT232RL への出力
#define putTeC(c) putSIO(0x0c, c)             // TeC への出力
#define putRN4020(c) putSIO(0x28, c)          // RN4020 への出力

public void putSIO(int port, char c);         // シリアルポートへの出力
public void putch(char c);                    // 1文字出力
public void putstr(char[] str);               // 文字列出力
public void puthex(int x);                    // 16進数出力

public void sjump(int bank,  int addr);       // バンクを切替えた上でジャンプ
