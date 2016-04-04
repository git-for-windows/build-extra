group "Functions"

idpAddFile = {
    proto = [[
procedure idpAddFile(url, filename: String);
procedure idpAddFileSize(url, filename: String; size: Int64{note-1});
procedure idpAddFileComp(url, filename, components: String);
procedure idpAddFileSizeComp(url, filename: String; size: Int64; components: String);
]],
    title = "idpAddFile, idpAddFileSize, idpAddFileComp, idpAddFileSizeComp",
    desc  = [[Adds file to download list. User name, password and port number can be specified as part of the URL
              (this will override global user name and password, specified with @idpSetLogin function).]],
    params = {
        { "url",      "Full file URL" },
        { "filename", "File name on the local disk." },
        { "size",     "Size of file. If not specified, it will be determined when download begins." },
        { "components{note-2}", [[A space separated list of component names, telling IDP to which components the file belongs.
                                A file without a components parameter is always downloaded.]] }
    },
    notes = { "<tt>size</tt> parameter is <tt>Dword</tt> for ANSI Inno Setup",
              "@idpDownloadFiles and @idpGetFilesSize ignores this parameter"
        },
    seealso  = { "idpAddFtpDir", "idpClearFiles", "idpDownloadAfter", "idpDownloadFiles", "idpSetLogin" },
--  keywords = { "login", "password", "components" },
    keywords = { "file", "files", "components" },
    example  = [[
procedure <b>InitializeWizard</b>();
begin
  idpAddFile('http://www.example.com/file1.dll', ExpandConstant('{tmp}\file1.dll'));
  idpAddFile('http://username:password@www.example.com/file2.dll', ExpandConstant('{tmp}\file2.dll'));

  idpDownloadAfter(wpReady);
end;
]]
}

idpAddFileSize = idpAddFile
idpAddFileComp = idpAddFile
idpAddFileSizeComp = idpAddFile

idpAddMirror = {
    proto   = "procedure idpAddMirror(url, mirror: String);",
    desc    = "Adds another URL for a given primary URL. The new URL will be used as a mirror if downloading from the original URL fails. You can add as many mirrors as you like",
    params  = {
        { "url",    "Primary URL{note-1}" },
        { "mirror", "Alternate URL" }
    },
    notes   = { "Unlike <tt>ITD_AddMirror</tt> procedure in <b>InnoTools Downloader</b>, mirrors are added for URLs, not for file names" },
    seealso = { "idpAddFile" }
}

idpClearFiles = {
    proto   = "procedure idpClearFiles;",
    desc    = "Clear all files, previously added with @idpAddFile procedure",
    seealso = { "idpAddFile" }
}

idpFilesCount = {
    proto   = "function idpFilesCount: Integer;",
    desc    = "Returns number of files, previously added with @idpAddFile procedure.",
    returns = "Number of files",
    seealso = { "idpAddFile", "idpClearFiles" }
}

idpFilesDownloaded = {
    proto =   [[function idpFilesDownloaded: Boolean;]],
    desc  =   [[Returns download status. If <tt>AllowContinue</tt> option was set to <tt>1</tt>, this function can be
                used to check that all files was successfully downloaded. If at least one file wasn't downloaded, 
                this function returns <tt>False</tt>]],
    returns = [[<tt>True</tt> if all files was successfully downloaded, <tt>False</tt> otherwise]],
    example = [[
procedure <b>CurStepChanged</b>(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then 
    if idpFilesDownloaded then
    begin
      // Copy downloaded files to application directory
      Filecopy(ExpandConstant('{tmp}\file1.dll'), ExpandConstant('{app}\file1.dll'), false);
      Filecopy(ExpandConstant('{tmp}\file2.dll'), ExpandConstant('{app}\file2.dll'), false);
    end;
end;
]],
    seealso = { "idpFileDownloaded" }
}

idpFileDownloaded = {
    proto   = "function idpFileDownloaded(url: String): Boolean;",
    desc    = "Checks download status of file.",
    params = {
        { "url", "Full file URL" },
    },
    returns = "<tt>True</tt> if file was successfully downloaded, <tt>False</tt> otherwise",
    seealso = { "idpFilesDownloaded" }
}

idpDownloadFile = {
    proto = "function idpDownloadFile(url, filename: String): Boolean; ",
    desc  = "Immediately download given file, without UI indication. Returns when file downloaded.",
    params = {    
        { "url",      "Full file URL." },
        { "filename", "File name on the local disk." }
    },
    returns = "<tt>True</tt> if file was successfully downloaded, <tt>False</tt> otherwise",
    seealso = { "idpDownloadFiles" }
}

idpDownloadFiles = {
    proto   = "function idpDownloadFiles: Boolean;",
    desc    = [[Immediately download all files, previously added with @idpAddFile procedure, without UI indication. Returns when all files downloaded.
              This function always downloads all files, ignoring component selection.]],
    returns = idpFilesDownloaded.returns,
    seealso = { "idpDownloadFilesComp", "idpDownloadFile", "idpDownloadAfter" }
}

idpDownloadFilesComp = {
    proto   = "function idpDownloadFilesComp: Boolean;",
    desc    = "Immediately download all files, previously added with @idpAddFile procedure, without UI indication. Returns when all files downloaded.",
    returns = idpFilesDownloaded.returns,
    seealso = { "idpDownloadFiles", "idpDownloadFile", "idpDownloadAfter" }
}

idpDownloadAfter = {
    proto = "procedure idpDownloadAfter(pageAfterId: Integer);",
    desc  = "Inform IDP that download should be started after given page.",
    params = {
        { "pageAfterID", "Wizard page ID" }
    },
    example = idpAddFile.example,
    notes   = { 'When using <a href="http://www.graphical-installer.com/">Graphical Installer</a>, this function should be called <u>before</u> calling InitGraphicalInstaller()' },
    seealso = { "idpAddFile", "idpAddFtpDir" }
}

idpGetFileSize = {
    proto  = "function idpGetFileSize(url: String; var size: Int64{note-1}): Boolean;",
    desc   = "Gets size of file at given URL.",
    params = {
        { "url",  "File url" },
        { "size", "The variable to store the size into" }
    },
    returns = "<tt>True</tt> if operation was successfull, <tt>False</tt> otherwise",
    notes   = { "<tt>size</tt> parameter is <tt>Dword</tt> for ANSI Inno Setup" },
    seealso = { "idpGetFilesSize" },
    example = [[
var size: Int64;
...
if idpGetFileSize('http://www.example.com/file.zip', size) then
  // Do something useful with file size...
]]
}

idpGetFilesSize = {
    proto = "function idpGetFilesSize(var size: Int64{note-1}): Boolean;",
    desc  = "Get size of all files, previously added with @idpAddFile procedure.",
    params = {
        { "size", "The variable to store the size into" }
    },
    returns = idpGetFileSize.returns,
    notes   = idpGetFileSize.notes,
    seealso = { "idpGetFileSize" }
}

dofile "version.lua" --idp version functions

idpSetOption = {
    proto = "procedure idpSetOption(name, value: String);",
    desc  = "Set value of IDP option. Option name is case-insensitive.",
    params = {
        { "name",  "Option to set" },
        { "value", "Option value as string" }
    },
    options = {
        { "AllowContinue",    [[Allow user to continue installation if download fails. If set to <tt>1</tt>,
                              you can use @idpFilesDownloaded function to check download status]],                        "0{note-1}" },
        { "StopOnError",      [[If one file cannot be downloaded, do not try to download other files. When <tt>AllowContinue</tt> 
                              is set to <tt>1</tt>, this option automatically sets to <tt>0</tt> and vise versa.]],       "<b>not</b> AllowContinue" },
        { "PreserveFtpDirs",  "Preserve FTP directory structure when using @idpAddFtpDir",                                "1" },
        { "DetailedMode",     "If set to <tt>1</tt>, download details will be visible by default",                        "0" },
        { "DetailsButton",    "Controls availability of 'Details' button",                                                "1" },
        { "RetryButton",      [[Controls availability of 'Retry' button on wizard form. If set to <tt>0</tt>,
                              'Download failed' message box will have 'Retry' & 'Cancel' buttons]],                       "1" },
        { "RedrawBackground", "You may need to turn on this option when using background image for wizard pages{note-2}", "0" },
        { "SkinnedButton",    [[When using <a href="http://www.graphical-installer.com/">Graphical Installer</a>, 
                              turn on this option to get 'Details' button skinned]],                                      "1" },
        { "ErrorDialog",      [[Type of error dialog to show in case of failed download:
                                  <ul>
                                  <li><tt>None</tt>     &ndash; Do not show any error message and continue install</li>
                                  <li><tt>Simple</tt>   &ndash; Message box, telling user that download failed</li>
                                  <li><tt>FileList</tt> &ndash; Dialog box with list of files that were not downloaded</li>
                                  <li><tt>UrlList</tt>  &ndash; Dialog box with list of URLs that were not downloaded</li>
                                  </ul>
                                If setup started with <tt>/SUPPRESSMSGBOXES</tt> parameter, this option automatically 
                                sets to <tt>None</tt>.]],                                                                 "Simple" },
        { "Referer",          "Referer URL, to use in HTTP and HTTPS requests",                                           ""  },
        { "UserAgent",        "User Agent string, used in HTTP and HTTPS requests",                                       userAgent() },
        { "InvalidCert",      [[Action to perform, when HTTPS certificate is invalid. Possible values are:
                                  <ul>
                                  <li><tt>ShowDlg</tt> &ndash; Show error dialog, allowing user to view
                                                       certificate details, cancel download or ignore error</li>
                                  <li><tt>Ignore</tt>  &ndash; Ignore error and continue download</li>
                                  <li><tt>Stop</tt>    &ndash; Stop download</li>
                                  </ul>]],                                                                                "ShowDlg" },
        { "ConnectTimeout",   [[Time-out value, in milliseconds, to use for Internet connection requests.     
                              Can be set to <tt>Infinite</tt> to disable this timer]],                                    "</tt>System default{note-3}<tt>" },
        { "SendTimeout",      "Time-out value, in milliseconds, to send a request",                                       "</tt>System default<tt>" },
        { "ReceiveTimeout",   "Time-out value, in milliseconds, to receive a response to a request",                      "</tt>System default<tt>" },
        { "Username",         'User name for HTTP/HTTPS and FTP. See also @idpSetLogin',                                  "" },
        { "Password",         'Password for HTTP/HTTPS and FTP. See also @idpSetLogin',                                   "" },
        { "ProxyMode",        'See @idpSetProxyMode',                                                                     "Auto" },
        { "ProxyName",        'See @idpSetProxyName',                                                                     "" },
        { "ProxyUsername",    'See @idpSetProxyLogin',                                                                    "" },
        { "ProxyPassword",    'See @idpSetProxyLogin',                                                                    "" },
        
    },
    keywords = { "user agent", "timeout", "ShowDlg", "Ignore", "Stop"},
    notes    = { 
        "For boolean values, <tt>True/False</tt>, <tt>Yes/No</tt> and <tt>Y/N</tt> also accepted",
        "When <tt>GRAPHICAL_INSTALLER_PROJECT</tt> is defined, <tt>RedrawBackground</tt> is turned on automatically",
        "Usually, 60 sec. for connect timeout and 30 sec. for send &amp; receive timeouts"
    },
    seealso  = { "idpSetProxyMode", "idpSetProxyName", "idpSetProxyLogin" }, 
    example  = [[
idpSetOption('AllowContinue',  '1');
idpSetOption('DetailedMode',   '1');
idpSetOption('DetailsButton',  '0');
idpSetOption('RetryButton',    '0');
idpSetOption('UserAgent',      'Mozilla/5.0 (Windows NT 5.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/29.0.1547.66 Safari/537.36');
idpSetOption('InvalidCert',    'ignore');
idpSetOption('ConnectTimeout', '10000');
]]
}

idpSetProxyMode = {
    proto   = [[procedure idpSetProxyMode(mode: String);]],
    desc    = [[Sets internet connection mode. Valid values are:
                <ul>
                <li><tt>Auto</tt>                    &ndash; Retrieves the proxy or direct configuration from the registry.</li>
                <li><tt>Direct</tt> or <tt>None</tt> &ndash; Resolves all host names locally.</li>
                <li><tt>Proxy</tt>                   &ndash; Passes requests to the proxy.</li>
                </ul>
                Default is <tt>Auto</tt>.
              ]],
    params  = {
        { "mode", "Connection mode" }
    },
    notes    = { 'You can also set proxy access parameters using @idpSetOption function.' },
--  keywords = { "proxy" },
    seealso  = { "idpSetProxyName", "idpSetProxyLogin", "idpSetOption" },
    example  = [[
idpSetProxyMode('proxy');
idpSetProxyName('127.0.0.1:8118');
idpSetProxyLogin('user123', 'secretpasssword321');
]]
}

idpSetProxyName = {
    proto   = "procedure idpSetProxyName(name: String);",
    desc    = 'Sets proxy name to use. Port number can be specified as part of the name. If name is not empty, this function sets <a href="idpSetProxyMode.htm">proxy mode</a> to <tt>proxy</tt>.',
    params  = {
        { "name", "Name of the proxy server to use" }
    },
    example  = idpSetProxyMode.example,
    notes    = idpSetProxyMode.notes,
    keywords = { "proxy" },
    seealso  = { "idpSetProxyMode", "idpSetProxyLogin", "idpSetOption" }
}

idpSetProxyLogin = {
    proto   = "procedure idpSetProxyLogin(username, password: String);",
    desc    = "Sets user name and password to access the proxy. If not set and proxy server requires authentification, login dialog will appear.",
    params  = {
        { "username", "User name" },
        { "password", "Password" }
    },
    example  = idpSetProxyMode.example,
    notes    = idpSetProxyMode.notes,
--  keywords = { "proxy" },
    seealso  = { "idpSetProxyMode", "idpSetProxyName", "idpSetOption", "idpSetLogin" }
}

idpSetLogin = {
    proto   = "procedure idpSetLogin(username, password: String);",
    desc    = [[Sets user name and password for HTTP/HTTPS and FTP. User name and password can be also specified
                for each file separately, as part of the URL, overriding global settings (see @idpAddFile).]],
    params  = {
        { "username", "User name" },
        { "password", "Password" }
    },
    keywords = { "login", "user name", "password" },
    notes    = { 'You can also set user name and password using @idpSetOption function.' },
    seealso  = { "idpAddFile" }
}

idpAddFtpDir = {
    title = "idpAddFtpDir, idpAddFtpDirComp",
    proto = [[
procedure idpAddFtpDir(url, mask, destdir: String; recursive: Boolean);
procedure idpAddFtpDirComp(url, mask, destdir: String; recursive: Boolean; components: String);
]],
    desc = [[Adds all files in specified FTP directory to download list. If <tt>recursive</tt> is true, then: 
             <ul>
             <li>This function will scan all subdirectories</li>
             <li>When files downloaded, directory structure will be preserved
                 (this can be switched off by setting <a href="idpSetOption.htm"><tt>PreserveFtpDirs</tt> option</a>
                 to <tt>false</tt>)</li>
             </ul>
             ]],
    params = {
        { "url",        "URL" },
        { "mask",       "File mask wildcards or empty string to select all files" },
        { "destdir",    "Destignation directory on the local disk" },
        { "recursive",  "If true, recursively add all subdirectories" },
        { "components", [[A space separated list of component names, telling IDP to which components the directory belongs.
                        A ftp directory without a components parameter is always downloaded.]] }
    },
    keywords = { "ftp", "directory" },
    seealso  = { "idpAddFile" },
    example  = [[
//Add all files in URL, including subdirectories
idpAddFtpDir('ftp://ftpserver.com/pub/myfiles', '', ExpandConstant('{tmp}'), true);

//Add only *.dll files; do not look in subdirectories
idpAddFtpDir('ftp://ftpserver.com/pub/myfiles', '*.dll', ExpandConstant('{tmp}'), false);
]]
}

idpAddFtpDirComp = idpAddFtpDir;

group "Support functions"

StrToBool = {
    proto  = "function StrToBool(value: String): Boolean;",
    desc   = "This function converts the string into a boolean. Accepted values are <tt>True/False</tt>, <tt>Yes/No</tt>, <tt>Y/N</tt> and <tt>1/0</tt> (case-insensitive).",
    params = {
        { "value", "String to convert" }
    },
    returns = "Boolean value"
}

WizardSuppressMsgBoxes = {
    proto    = "function WizardSupressMsgBoxes: Boolean;",
    desc     = "Returns <tt>True</tt> if <tt>/SUPPRESSMSGBOXES</tt> command line parameter was passed to setup.",
    returns  = "True or false",
    keywords = { "/SUPPRESSMSGBOXES" },
    seealso  = { "WizardVerySilent" }
}

WizardVerySilent = {
    proto    = "function WizardVerySilent: Boolean;",
    desc     = "Returns <tt>True</tt> if <tt>/VERYSILENT</tt> command line parameter was passed to setup.",
    returns  = "True or false",
    keywords = { "/VERYSILENT" },
    seealso  = { "WizardSuppressMsgBoxes" }
}

group "Types"

TIdpForm = {
    proto = [[
type TIdpForm = record
    Page              : TWizardPage;
    TotalProgressBar  : TNewProgressBar;
    FileProgressBar   : TNewProgressBar;
    TotalProgressLabel: TNewStaticText;
    CurrentFileLabel  : TNewStaticText;
    TotalDownloaded   : TNewStaticText; 
    FileDownloaded    : TNewStaticText;
    FileNameLabel     : TNewStaticText;
    SpeedLabel        : TNewStaticText;
    StatusLabel       : TNewStaticText;
    ElapsedTimeLabel  : TNewStaticText;
    RemainingTimeLabel: TNewStaticText;
    FileName          : TNewStaticText;
    Speed             : TNewStaticText;
    Status            : TNewStaticText;
    ElapsedTime       : TNewStaticText;
    RemainingTime     : TNewStaticText;
    DetailsButton     : TButton;
    GIDetailsButton   : HWND;{note-1}
    DetailsVisible    : Boolean;
end;

var IDPForm: TIdpForm;
]],
    desc     = "This record holds all IDP wizard page controls. They are accessible after calling idpDownloadAfter().",
    notes    = { "Details button handle when <tt>GRAPHICAL_INSTALLER_PROJECT</tt> is defined and <tt>SkinnedButton</tt> set to 1" },
    seealso  = { "idpDownloadAfter" },
    keywords = { "TIdpForm", "IDPForm", "controls" }
}

group "Macros"

IDP_VER = {
    title = "IDP_VER, IDP_VER_STR, IDP_VER_MAJOR, IDP_VER_MINOR, IDP_VER_REV, IDP_VER_BUILD",
    proto = [[
#define IDP_VER_STR
#define IDP_VER
#define IDP_VER_MAJOR
#define IDP_VER_MINOR
#define IDP_VER_REV
#define IDP_VER_BUILD
]],
    desc = "These predefined macros stores Inno Download Plugin version numbers.",
    params = {
        { "IDP_VER_STR",   "Version as string (<tt>"                 .. verStr   .. "</tt>)" },
        { "IDP_VER",       "Version encoded as 32-bit integer (<tt>" .. verDword .. "</tt>)" },
        { "IDP_VER_MAJOR", "Version major number (<tt>"              .. verMajor .. "</tt>)" },
        { "IDP_VER_MINOR", "Version minor number (<tt>"              .. verMinor .. "</tt>)" },
        { "IDP_VER_REV",   "Version revision number (<tt>"           .. verRev   .. "</tt>)" },
        { "IDP_VER_BUILD", "Version build number (<tt>"              .. verBuild .. "</tt>)" }
    },
    keywords = { "version" },
}

IDP_VER_STR   = IDP_VER
IDP_VER_MAJOR = IDP_VER
IDP_VER_MINOR = IDP_VER
IDP_VER_REV   = IDP_VER
IDP_VER_BUILD = IDP_VER

IDP_DEBUG = {
    proto   = "#define IDP_DEBUG",
    desc    = [[If <tt>IDP_DEBUG</tt> is defined before including idp.iss, script will use debug version of idp.dll
                (not included, you need to build it from sources), which prints debug information during download process.
                Debug dll messages can be viewed with <a href="http://technet.microsoft.com/en-us/sysinternals/bb896647.aspx">SysInternals DebugView</a>.]],
    example = [[
#define IDP_DEBUG
#include &lt;idp.iss&gt;
]],
    keywords = { "Debugging" }
}
