program webcompiler;

{$mode objfpc}

uses
  Classes, SysUtils, Web, JS, Types, webfilecache, pas2jswebcompiler, browserconsole;

procedure clearMarkers; external name 'window.clearMarkers';
procedure addMarker(Line: Integer; const TypeName, Msg: String); external name 'window.addMarker';
procedure appReady; external name 'window.appReady';

Type

  { TWebCompiler }

  TWebCompiler = Class(TComponent)
  Private
    BRun : TJSHTMLElement;
    MSource : TJSHTMLInputElement;
    MLog: TJSHTMLInputElement;
    RFrame : TJSHTMLIFrameElement;
    PResult : TJSHTMLElement;
    FCompiler : TPas2JSWebCompiler;
    FKnownFiles: TStringList;
    procedure DoLog(Sender: TObject; const Msg: String);
    procedure LoadDefaults;
    procedure OnUnitLoaded(Sender: TObject; aFileName: String; aError: string);
    function RunClick(aEvent: TJSMouseEvent): boolean;
  Protected
    Procedure LinkElements;
    Property Compiler : TPas2JSWebCompiler Read FCompiler;
  Public
    Constructor Create(aOwner : TComponent); override;
    Destructor Destroy; override;
    Procedure Execute;
  Published
    Function AddSourceFile(AFileName, AContent: String): Boolean;
    Procedure LoadSourceFile(AURL, AFileName: String);
    Function GetFileContent(AFileName: String): String;
    Function GetFileList: TJSStringDynArray;
  end;

Const
  SHTMLHead =
    '<HTML>'+LineEnding+
    '<head>'+LineEnding+
    '  <meta charset="UTF-8">'+LineEnding+
    '  <Title>Pas2JS web compiler Program output</Title>'+LineEnding+
    '  <script type="application/javascript">'+LineEnding;

  SHTMLTail =
    '   </script>'+LineEnding+
    '  <style>'+LineEnding+
    '    :root { --bg-color: #ffffff; --text-color: #000000; --header-color: #0056b3; --border-color: #eee; }'+LineEnding+
    '    @media (prefers-color-scheme: dark) { :root { --bg-color: #282a36; --text-color: #f8f8f2; --header-color: #bd93f9; --border-color: #44475a; } }'+LineEnding+
    '    body { background-color: var(--bg-color); color: var(--text-color); font-family: "Segoe UI", sans-serif; margin: 0; padding: 0; }'+LineEnding+
    '    .console-container { padding: 10px; min-height: 100vh; box-sizing: border-box; }'+LineEnding+
    '    .log-header { font-size: 0.8rem; color: var(--header-color); margin-bottom: 10px; border-bottom: 1px solid var(--border-color); padding-bottom: 5px; font-weight: bold; text-transform: uppercase; }'+LineEnding+
    '    #pasjsconsole { font-family: "Consolas", "Monaco", monospace; white-space: pre-wrap; }'+LineEnding+
    '    .pasconsole { font-family: "Consolas", "Monaco", monospace; font-size: 14px; background: transparent; color: var(--text-color); display: block; line-height: 1.4; border-bottom: 1px solid var(--border-color); }'+LineEnding+
    '  </style>'+LineEnding+
    '</head>'+LineEnding+
    '<body>'+LineEnding+
    '  <div class="console-container">'+LineEnding+
    '    <div class="log-header">Program Output</div>'+LineEnding+
    '    <div id="pasjsconsole"></div>'+LineEnding+
    '  </div>'+LineEnding+
    '<script>'+LineEnding+
    '  rtl.run();'+LineEnding+
    '</script>'+LineEnding+
    '</body>'+LineEnding+
    '</HTML>';


{ TWebCompiler }

procedure TWebCompiler.OnUnitLoaded(Sender: TObject; aFileName: String; aError: string);
begin
  if aError<>'' then
    MLog.Value:=MLog.Value+sLineBreak+'Error Loading "'+aFileName+'": '+AError
  else
    asm
      if (window.fileLoaded) window.fileLoaded(aFileName);
    end;
end;

procedure TWebCompiler.LinkElements;
begin
  BRun:=TJSHTMLElement(Document.getElementById('btn-run'));
  BRun.onClick:=@RunClick;
  MSource:=TJSHTMLInputElement(Document.getElementById('memo-program-src'));
  MLog:=TJSHTMLInputElement(Document.getElementById('memo-compiler-output'));
  RFrame:=TJSHTMLIFrameElement(Document.getElementById('runarea'));
  PResult:=TJSHTMLElement(Document.getElementById('compile-result'));
end;

constructor TWebCompiler.Create(aOwner : TComponent);
begin
  Inherited;
  FKnownFiles := TStringList.Create;
  FKnownFiles.Sorted := True;
  FKnownFiles.Duplicates := dupIgnore;
  
  FCompiler:=TPas2JSWebCompiler.Create;
  Compiler.Log.OnLog:=@DoLog;
  Compiler.WebFS.LoadBaseURL:='sources';
  browserconsole.ConsoleStyle := '';
  
  asm
    window.webCompilerApp = this;
  end;
end;

destructor TWebCompiler.Destroy;
begin
  FKnownFiles.Free;
  Inherited;
end;

function TWebCompiler.RunClick(aEvent: TJSMouseEvent): boolean;

  Procedure ShowResult(success : boolean);
  Var
    E : TJSHTMLElement;
  begin
    While PResult.firstElementChild<>Nil do
      PResult.removeChild(PResult.firstElementChild);

    E:=TJSHTMLElement(document.createElement('div'));
    if Success then
      begin
      E['class']:='alert alert-success alert-dismissible fade show m-0';
      E.innerHTML:='<strong>Success!</strong> Program compiled and running.';
      asm
        if (window.showRunTab) window.showRunTab();
      end;
      end
    else
      begin
      E['class']:='alert alert-danger alert-dismissible fade show m-0';
      E.innerHTML:='<strong>Failure</strong> Compilation failed. Check logs.';
      asm
        if (window.showCompilerTab) window.showCompilerTab();
      end;
      end;
    PResult.appendChild(E);
  end;

Var
  args : TStrings;
  Res : Boolean;
  Src : String;

begin
  Result:=False; 
  
  // Compile
  MLog.Value:='';
  ClearMarkers; 
  
  Compiler.WebFS.SetFileContent('main.pp',MSource.value);
  args:=TStringList.Create;
  try
    Args.Add('-Tbrowser');
    Args.Add('-Jc');
    Args.Add('-Jirtl.js');
    Args.Add('main.pp');
    
    try
      Compiler.Run('','',Args,True);
    except
      on E: Exception do
        MLog.Value:=MLog.Value+sLineBreak+'Exception during compile: '+E.Message;
    end;
    MLog.Value:=MLog.Value+sLineBreak+'Exit Code: '+IntToStr(Compiler.ExitCode);
    Res:=Compiler.ExitCode=0;
    ShowResult(Res);
    
    if Res then
    begin
      // Run
      Src:=Compiler.WebFS.GetFileContent('main.js');
      if Src='' then
        begin
        Window.Alert('No source available');
        exit;
        end;
      Src:=SHTMLHead+Src+LineEnding+SHTMLTail;
      RFrame['srcdoc']:=Src;
    end;
  finally
   Args.Free;
  end;
end;

procedure TWebCompiler.DoLog(Sender: TObject; const Msg: String);
var
  P1, P2, P3, Line: Integer;
  S, TypeName: String;
begin
  MLog.Value:=MLog.Value+sLineBreak+Msg;
  
  if Pos('main.pp(', Msg) = 1 then
  begin
    P1 := Pos('(', Msg);
    P2 := Pos(',', Msg);
    P3 := Pos(')', Msg);
    if (P1 > 0) and (P2 > P1) and (P3 > P2) then
    begin
      S := Copy(Msg, P1 + 1, P2 - P1 - 1);
      Line := StrToIntDef(S, 0);
      
      S := Copy(Msg, P3 + 2, Length(Msg));
      if Pos('Error:', S) = 1 then TypeName := 'error'
      else if Pos('Fatal:', S) = 1 then TypeName := 'error'
      else if Pos('Warning:', S) = 1 then TypeName := 'warning'
      else if Pos('Hint:', S) = 1 then TypeName := 'hint'
      else if Pos('Note:', S) = 1 then TypeName := 'hint'
      else TypeName := '';
      
      if (Line > 0) and (TypeName <> '') then
        addMarker(Line, TypeName, Msg);
    end;
  end;
end;

procedure TWebCompiler.LoadDefaults;

  function DoText(Res: JSValue): JSValue;
  begin
    Result := TJSResponse(Res).text();
  end;

  function DoLoad(Val: JSValue): JSValue;
  var
    Arr: TStringDynArray;
    I: Integer;
  begin
    Arr := TStringDynArray(TJSJSON.parse(String(Val)));
    
    for I := 0 to Length(Arr)-1 do
      FKnownFiles.Add(Arr[I]);
      
    Compiler.WebFS.LoadFiles(Arr, @OnUnitLoaded);
    Result := nil;
    
    appReady;
  end;

begin
  window.fetch('files.json')._then(@DoText)._then(@DoLoad);
end;

procedure TWebCompiler.Execute;
begin
  LinkElements;
  LoadDefaults;
end;

function TWebCompiler.AddSourceFile(AFileName, AContent: String): Boolean;
begin
  Result := FCompiler.WebFS.SetFileContent(AFileName, AContent);
  if Result then
  begin
    if FKnownFiles.IndexOf(AFileName) < 0 then
      FKnownFiles.Add(AFileName);
  end;
end;

procedure TWebCompiler.LoadSourceFile(AURL, AFileName: String);

  function DoText(Res: JSValue): JSValue;
  begin
    Result := TJSResponse(Res).text();
  end;

  function DoLoad(Val: JSValue): JSValue;
  begin
    AddSourceFile(AFileName, String(Val));
    Result := nil;
  end;

  function DoError(Err: JSValue): JSValue;
  begin
    MLog.Value := MLog.Value + sLineBreak + 'Error loading ' + AURL + ': ' + String(Err);
    Result := nil;
  end;

begin
  window.fetch(AURL)._then(@DoText)._then(@DoLoad).catch(@DoError);
end;

function TWebCompiler.GetFileContent(AFileName: String): String;
begin
  try
    Result := FCompiler.WebFS.GetFileContent(AFileName);
  except
    Result := '';
  end;
end;

function TWebCompiler.GetFileList: TJSStringDynArray;
var
  I: Integer;
begin
  SetLength(Result, FKnownFiles.Count);
  for I := 0 to FKnownFiles.Count - 1 do
    Result[I] := FKnownFiles[I];
end;

begin
  With TWebCompiler.Create(Nil) do
    Execute;
end.
