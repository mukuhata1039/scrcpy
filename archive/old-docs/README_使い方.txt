scrcpy v4.1 SAFE UPDATE

使い方
------
1. scrcpyを完全に閉じる
2. このZIPの4ファイルを、今使っているscrcpyフォルダ
   （scrcpy.exe / scrcpy_audible_launcher.exe がある場所）へコピー
3. UPDATE_SCRCPY_TO_4_1.bat をダブルクリック
4. SUCCESS が出たら終了

この更新方法が守るもの
----------------------
- 現在のscrcpyフォルダを、先に丸ごと兄弟フォルダへバックアップ
- 公式scrcpy v4.1のファイルだけを上書き
- 自作ファイルを削除しない
  例:
  scrcpy_audible_launcher.exe
  scrcpy_audible_launcher.cs
  scrcpy_media_bridge.py
  silent.wav
  AutoHotkey関連
  ICO
  ショートカット
  _old
  BUILD_AND_SETUP.bat
  その他の自作ファイル

更新元
------
公式:
https://github.com/Genymobile/scrcpy/releases/download/v4.1/scrcpy-win64-v4.1.zip

SHA-256:
5b12172b3264b2889f4583ee64752ce832e29bc8b1089dca81093459697165db

補足
----
v4.1はSDL3を使います。
古いSDL2.dllやavcodec-61.dll等は安全のため自動削除しません。
まず今の自作ランチャーが正常動作することを確認してください。
問題なければ後から古いDLLだけ整理できます。

元に戻す場合
------------
ROLLBACK_LAST_SCRCPY_UPDATE.bat を実行。
UPDATE時に作ったバックアップへ戻します。
