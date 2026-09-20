strCommand = "cmd /c scrcpy.exe --max-size=700 --window-x=0 --window-y=340 --turn-screen-off --window-borderless --power-off-on-close"

' 渡された引数をすべて追加
For Each Arg In WScript.Arguments
    strCommand = strCommand & " """ & Replace(Arg, """", """""""""") & """"
Next

' コンソール非表示で実行
CreateObject("Wscript.Shell").Run strCommand, 0, False
