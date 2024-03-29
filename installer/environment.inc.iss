[Code]

// Returns the value(s) of the environment variable "VarName", which is tokenized
// by ";" into an array of strings. This makes it easy query PATH-like variables
// in addition to normal variables. If "AllUsers" is true, the common variables
// are searched, else the user-specific ones.
function GetEnvStrings(VarName:string;AllUsers:Boolean):TArrayOfString;
var
    Path:string;
    i:Longint;
    p:Integer;
begin
    Path:='';

    // See http://www.jrsoftware.org/isfaq.php#env
    if AllUsers then begin
        // We ignore errors here. The resulting array of strings will be empty.
        RegQueryStringValue(HKEY_LOCAL_MACHINE,'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',VarName,Path);
    end else begin
        // We ignore errors here. The resulting array of strings will be empty.
        RegQueryStringValue(HKEY_CURRENT_USER,'Environment',VarName,Path);
    end;

    // Fallback for built-in variables which are not stored in the Registry.
    if Length(Path)=0 then begin
        Path:=ExpandConstant('{%'+VarName+'}');
    end;

    // Make sure we have at least one semicolon.
    Path:=Path+';';

    // Split the directories in PATH into an array of strings.
    i:=0;
    SetArrayLength(Result,0);

    p:=Pos(';',Path);
    while p>0 do begin
        SetArrayLength(Result,i+1);
        if p>1 then begin
            Result[i]:=Copy(Path,1,p-1);
            i:=i+1;
        end;
        Path:=Copy(Path,p+1,Length(Path));
        p:=Pos(';',Path);
    end;
end;

// Sets the contents of the specified environment variable for the current process.
function SetEnvironmentVariable(lpName,lpValue:String):Boolean;
#ifdef UNICODE
external 'SetEnvironmentVariableW@Kernel32.dll stdcall delayload';
#else
external 'SetEnvironmentVariableA@Kernel32.dll stdcall delayload';
#endif

// Sets the environment variable "VarName" to the concatenation of "DirStrings"
// using ";" as the delimiter. If "Expandable" is true, the "DirStrings" will be
// written as expandable strings, i.e. they may in turn contain environment variable
// names that are expanded at evaluation time. If "AllUsers" is true, a common
// variable is set, else a user-specific one. If "DeleteIfEmpty" is true and
// "DirStrings" is empty, "VarName" is deleted instead of set if it exists.
function SetEnvStrings(VarName:string;DirStrings:TArrayOfString;Expandable,AllUsers,DeleteIfEmpty:Boolean):Boolean;
var
    Path,KeyName,SysRoot:string;
    i:Longint;
begin
    // Merge all non-empty directory strings into a PATH variable.
    Path:='';
    for i:=0 to GetArrayLength(DirStrings)-1 do begin
        if Length(DirStrings[i])>0 then begin
            if Length(Path)>0 then begin
                Path:=Path+';'+DirStrings[i];
            end else begin
                Path:=DirStrings[i];
            end;
        end;
    end;

    // See http://www.jrsoftware.org/isfaq.php#env
    if AllUsers then begin
        KeyName:='SYSTEM\CurrentControlSet\Control\Session Manager\Environment';
        if DeleteIfEmpty and (Length(Path)=0) then begin
            Result:=(not RegValueExists(HKEY_LOCAL_MACHINE,KeyName,VarName)) or
                         RegDeleteValue(HKEY_LOCAL_MACHINE,KeyName,VarName);
        end else begin
            if Expandable then begin
                Result:=RegWriteExpandStringValue(HKEY_LOCAL_MACHINE,KeyName,VarName,Path);
            end else begin
                Result:=RegWriteStringValue(HKEY_LOCAL_MACHINE,KeyName,VarName,Path);
            end;
        end;
    end else begin
        KeyName:='Environment';
        if DeleteIfEmpty and (Length(Path)=0) then begin
            Result:=(not RegValueExists(HKEY_CURRENT_USER,KeyName,VarName)) or
                         RegDeleteValue(HKEY_CURRENT_USER,KeyName,VarName);
        end else begin
            if Expandable then begin
                Result:=RegWriteExpandStringValue(HKEY_CURRENT_USER,KeyName,VarName,Path);
            end else begin
                Result:=RegWriteStringValue(HKEY_CURRENT_USER,KeyName,VarName,Path);
            end;
        end;
    end;

    // Avoid setting a `PATH` with unexpanded `%SystemRoot%` in it!
    if (VarName='PATH') and (Pos('%',Path)>0) then begin
        SysRoot:=GetEnv('SystemRoot');
        StringChangeEx(Path,'%SYSTEMROOT%',SysRoot,True);
        StringChangeEx(Path,'%SystemRoot%',SysRoot,True);
    end;

    // Also update the environment of the current process.
    SetEnvironmentVariable(VarName,Path);
end;

// Sets the contents of the specified environment variable for the current process.
function SetEnvironmentVariable2(lpName:String;lpValue:LongInt):Boolean;
#ifdef UNICODE
external 'SetEnvironmentVariableW@Kernel32.dll stdcall delayload';
#else
external 'SetEnvironmentVariableA@Kernel32.dll stdcall delayload';
#endif

function SanitizeGitEnvironmentVariables:Boolean;
begin
    Result:=True;
    if not SetEnvironmentVariable2('GIT_INDEX_FILE',0) then Result:=False;
    if not SetEnvironmentVariable2('GIT_INDEX_VERSION',0) then Result:=False;
    if not SetEnvironmentVariable2('GIT_OBJECT_DIRECTORY',0) then Result:=False;
    if not SetEnvironmentVariable2('GIT_ALTERNATE_OBJECT_DIRECTORIES',0) then Result:=False;
    if not SetEnvironmentVariable2('GIT_DIR',0) then Result:=False;
    if not SetEnvironmentVariable2('GIT_WORK_TREE',0) then Result:=False;
    if not SetEnvironmentVariable2('GIT_NAMESPACE',0) then Result:=False;
    if not SetEnvironmentVariable2('GIT_CEILING_DIRECTORIES',0) then Result:=False;
    if not SetEnvironmentVariable2('GIT_DISCOVERY_ACROSS_FILESYSTEM',0) then Result:=False;
    if not SetEnvironmentVariable2('GIT_COMMON_DIR',0) then Result:=False;
    if not SetEnvironmentVariable2('GIT_DEFAULT_HASH',0) then Result:=False;
    if not SetEnvironmentVariable2('GIT_CONFIG',0) then Result:=False;
    if not SetEnvironmentVariable2('GIT_CONFIG_GLOBAL',0) then Result:=False;
    if not SetEnvironmentVariable2('GIT_CONFIG_SYSTEM',0) then Result:=False;
    if not SetEnvironmentVariable2('GIT_CONFIG_NOSYSTEM',0) then Result:=False;
end;
