# scrcpy（OPPO 用カスタム版）

現在使っているのは **scrcpy 4.1** と `scrcpy_audible_launcher.exe` です。Windows のフォルダ名に `v3.3.1` が残っていますが、中の scrcpy は 4.1 です。

## 起動

タスクバーに登録した `scrcpy_audible_launcher.exe` から起動します。対象の OPPO は ADB シリアル `a8879f0b` に固定されています。直接 `scrcpy.exe` を起動すると、このランチャー固有の設定は使われません。

- `scrcpy_audible_launcher.cs`：ランチャーのソース
- `scrcpy_audible_launcher.exe`：現在のランチャー実行ファイル
- `scrcpy_media_bridge.py`：再生操作を補助するプログラム
- `scrcpy.exe` と同じ階層の DLL・`scrcpy-server`・`adb.exe`：scrcpy の実行に必要
- `patches/scrcpy-v4.1-native-hotkeys.patch`：scrcpy 本体の Alt+A / Alt+Q / アプリ切り替え / Ctrl+W の変更
- `.github/workflows/build-native-hotkeys.yml`：上記パッチから Windows 版をビルドする手順

古い AHK 版や一度きりの修正スクリプトは `archive/` に保存しています。**通常の起動・更新には使いません。**

## ショートカットキー

- Alt+A：OPPO本体の画面をオン・オフ切り替え
- Alt+Q：Androidのホームへ移動（scrcpyの終了はウィンドウの×を使う）

scrcpy のウィンドウ上で Ctrl を押しながら Tab で次のアプリ、Ctrl+Shift+Tab で前のアプリを選び、Ctrl を離すと切り替えます。選択中に Ctrl+W を押すと、選んでいるアプリを最近使ったアプリの一覧から閉じます。

## Alt+H で scrcpy を起動・終了する

Alt+H を押すと OPPO 用の `scrcpy_audible_launcher.exe` が起動し、もう一度押すと、そのランチャーが起動した scrcpy を通常終了します。Page など別の scrcpy は終了しません。従来のタスクバーアイコンも使えます。

最初の一回だけ、GitHub から更新した後に PowerShell で次を実行します。Alt+H の待ち受けをすぐに開始し、次回以降の Windows ログイン時にも自動起動します。配置先はこれまでどおり E: で、C: にアプリを置く必要はありません。

```powershell
& 'E:\app\scrcpy-win64-v3.3.1\scrcpy_audible_launcher.exe' --install-alt-h
```

ランチャーの実行ファイルを今後更新するときは、先に scrcpy を閉じ、次のコマンドで Alt+H の待ち受けと自動起動を解除してから `git pull --ff-only` を実行します。更新後に上の `--install-alt-h` を再実行してください。

```powershell
& 'E:\app\scrcpy-win64-v3.3.1\scrcpy_audible_launcher.exe' --remove-alt-h
```

## GitHub から取り込む

現在の Windows 配置先は `E:\app\scrcpy-win64-v3.3.1` です。**C: ドライブは不要**で、この配置のままで使えます。

修正が GitHub の現在のブランチ `review/scrcpy-local-20261002-084544` に反映されたと案内された後、PowerShell で次を実行します。

```powershell
git -C 'E:\app\scrcpy-win64-v3.3.1' pull --ff-only
```

`pull` は起動中の `.exe` を交換できないため、更新前に scrcpy とランチャーを終了してください。手元のファイルに未コミットの変更があって止まった場合は、上書きせず状況を確認してください。ソース `.cs` の更新だけでは実行ファイル `.exe` は変わりません。ビルドが必要な変更では個別に案内します。

## 接続しないとき

ランチャーを再起動する前に、次のログの末尾を確認します。

```powershell
Get-Content "$env:TEMP\scrcpy_audible_startup.log" -Tail 100
```

このファイルはランチャーが起動した scrcpy のデバッグ記録です。ログから原因が分かる前に古い修正バッチを実行しないでください。

## 整理について

`archive/` は過去版の保存場所です。実行用の `.exe`、必要な DLL、現在使うランチャー、既存のショートカットは元の位置を維持しています。日付付きバックアップと古い手順は Git の履歴からも取り戻せます。
