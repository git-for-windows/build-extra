; *** Inno Setup 版本 6.4.0+ 中文语言文件 ***
;
; 下载用户贡献的翻译文件请访问：
;   https://jrsoftware.org/files/istrans/
;
; 注意：翻译时请勿在没有句号的消息末尾添加句号（.），
; 因为 Inno Setup 会自动添加句号（添加会导致显示两个句号）。

[LangOptions]
; 以下三个条目非常重要，请务必阅读并理解帮助文件中的 "[LangOptions] 部分"
LanguageName=简体中文
LanguageID=$0409
LanguageCodePage=0
; 如果目标语言需要特殊字体或字号，请取消注释并修改以下条目
;DialogFontName=
;DialogFontSize=8
;WelcomeFontName=Verdana
;WelcomeFontSize=12
;TitleFontName=Arial
;TitleFontSize=29
;CopyrightFontName=Arial
;CopyrightFontSize=8

[Messages]

; *** 应用程序标题
SetupAppTitle=安装程序
SetupWindowTitle=安装程序 - %1
UninstallAppTitle=卸载程序
UninstallAppFullTitle=%1 卸载程序

; *** 通用消息
InformationTitle=信息
ConfirmTitle=确认
ErrorTitle=错误

; *** SetupLdr 消息
SetupLdrStartupMessage=即将安装 %1。是否继续？
LdrCannotCreateTemp=无法创建临时文件。安装已中止
LdrCannotExecTemp=无法在临时目录执行文件。安装已中止
HelpTextNote=

; *** 启动错误消息
LastErrorMessage=%1.%n%n错误 %2: %3
SetupFileMissing=安装目录中缺少文件 %1。请解决问题或获取程序新副本。
SetupFileCorrupt=安装文件已损坏。请获取程序新副本。
SetupFileCorruptOrWrongVer=安装文件已损坏，或与此版本安装程序不兼容。请解决问题或获取程序新副本。
InvalidParameter=命令行参数无效：%n%n%1
SetupAlreadyRunning=安装程序已在运行。
WindowsVersionNotSupported=本程序不支持您计算机运行的 Windows 版本。
WindowsServicePackRequired=本程序需要 %1 Service Pack %2 或更高版本。
NotOnThisPlatform=本程序无法在 %1 上运行。
OnlyOnThisPlatform=本程序必须在 %1 上运行。
OnlyOnTheseArchitectures=本程序只能安装在以下处理器架构的 Windows 版本：%n%n%1
WinVersionTooLowError=本程序需要 %1 版本 %2 或更高。
WinVersionTooHighError=本程序无法安装在 %1 版本 %2 或更高。
AdminPrivilegesRequired=安装本程序需要管理员权限。
PowerUserPrivilegesRequired=安装本程序需要管理员或 Power Users 组成员权限。
SetupAppRunningError=检测到 %1 正在运行。%n%n请先关闭所有实例，然后点击确定继续，或取消退出。
UninstallAppRunningError=检测到 %1 正在运行。%n%n请先关闭所有实例，然后点击确定继续，或取消退出。

; *** 启动问题
PrivilegesRequiredOverrideTitle=选择安装模式
PrivilegesRequiredOverrideInstruction=选择安装模式
PrivilegesRequiredOverrideText1=%1 可为所有用户安装（需管理员权限），或仅当前用户。
PrivilegesRequiredOverrideText2=%1 可仅为您安装，或为所有用户安装（需管理员权限）。
PrivilegesRequiredOverrideAllUsers=为所有用户安装(&A)
PrivilegesRequiredOverrideAllUsersRecommended=为所有用户安装（推荐）(&A)
PrivilegesRequiredOverrideCurrentUser=仅为我安装(&M)
PrivilegesRequiredOverrideCurrentUserRecommended=仅为我安装（推荐）(&M)

; *** 其他错误
ErrorCreatingDir=无法创建目录 "%1"
ErrorTooManyFilesInDir=无法在目录 "%1" 中创建文件，因为包含文件过多

; *** 安装程序通用消息
ExitSetupTitle=退出安装程序
ExitSetupMessage=安装尚未完成。如果现在退出，程序将无法安装。%n%n您可以稍后重新运行安装程序完成安装。%n%n确定退出？
AboutSetupMenuItem=关于安装程序(&A)...
AboutSetupTitle=关于安装程序
AboutSetupMessage=%1 版本 %2%n%3%n%n%1 主页：%n%4
AboutSetupNote=
TranslatorNote=

; *** 按钮
ButtonBack=< 上一步(&B)
ButtonNext=下一步(&N) >
ButtonInstall=安装(&I)
ButtonOK=确定
ButtonCancel=取消
ButtonYes=是(&Y)
ButtonYesToAll=全部是(&A)
ButtonNo=否(&N)
ButtonNoToAll=全部否(&O)
ButtonFinish=完成(&F)
ButtonBrowse=浏览(&B)...
ButtonWizardBrowse=浏览(&R)...
ButtonNewFolder=新建文件夹(&M)

; *** "选择语言" 对话框
SelectLanguageTitle=选择安装语言
SelectLanguageLabel=选择安装过程中使用的语言。

; *** 通用向导文本
ClickNext=点击下一步继续，或取消退出安装。
BeveledLabel=
BrowseDialogTitle=浏览文件夹
BrowseDialogLabel=从列表中选择文件夹，然后点击确定。
NewFolderName=新建文件夹

; *** "欢迎" 向导页
WelcomeLabel1=欢迎使用 [name] 安装向导
WelcomeLabel2=即将在您的计算机上安装 [name/ver]。%n%n建议在继续之前关闭所有其他应用程序。

; *** "密码" 向导页
WizardPassword=密码
PasswordLabel1=本安装程序受密码保护。
PasswordLabel3=请输入密码，然后点击下一步继续。密码区分大小写。
PasswordEditLabel=密码(&P)：
IncorrectPassword=输入的密码不正确，请重试。

; *** "许可协议" 向导页
WizardLicense=许可协议
LicenseLabel=在继续之前，请阅读以下重要信息。
LicenseLabel3=请阅读以下许可协议。必须接受协议条款才能继续安装。
LicenseAccepted=我接受协议(&A)
LicenseNotAccepted=我不接受协议(&D)

; *** "信息" 向导页
WizardInfoBefore=信息
InfoBeforeLabel=在继续之前，请阅读以下重要信息。
InfoBeforeClickLabel=准备好继续安装后，请点击下一步。
WizardInfoAfter=信息
InfoAfterLabel=在继续之前，请阅读以下重要信息。
InfoAfterClickLabel=准备好继续安装后，请点击下一步。

; *** "用户信息" 向导页
WizardUserInfo=用户信息
UserInfoDesc=请输入您的信息。
UserInfoName=用户名(&U)：
UserInfoOrg=单位(&O)：
UserInfoSerial=序列号(&S)：
UserInfoNameRequired=必须输入用户名。

; *** "选择目标位置" 向导页
WizardSelectDir=选择目标位置
SelectDirDesc=您想将 [name] 安装到哪个位置？
SelectDirLabel3=安装程序将把 [name] 安装到以下文件夹。
SelectDirBrowseLabel=点击下一步继续。要选择其他文件夹，请点击浏览。
DiskSpaceGBLabel=至少需要 [gb] GB 可用磁盘空间。
DiskSpaceMBLabel=至少需要 [mb] MB 可用磁盘空间。
CannotInstallToNetworkDrive=无法安装到网络驱动器。
CannotInstallToUNCPath=无法安装到 UNC 路径。
InvalidPath=必须输入带驱动器号的完整路径，例如：%n%nC:\APP%n%n或 UNC 路径格式：%n%n\\服务器\共享
InvalidDrive=选择的驱动器或 UNC 共享不存在或无法访问。请选择其他位置。
DiskSpaceWarningTitle=磁盘空间不足
DiskSpaceWarning=安装需要至少 %1 KB 可用空间，但所选驱动器仅有 %2 KB 可用。%n%n是否继续？
DirNameTooLong=文件夹名称或路径过长。
InvalidDirName=文件夹名称无效。
BadDirName32=文件夹名称不能包含以下字符：%n%n%1
DirExistsTitle=文件夹已存在
DirExists=文件夹：%n%n%1%n%n已存在。是否仍要安装到此文件夹？
DirDoesntExistTitle=文件夹不存在
DirDoesntExist=文件夹：%n%n%1%n%n不存在。是否创建此文件夹？

; *** "选择组件" 向导页
WizardSelectComponents=选择组件
SelectComponentsDesc=要安装哪些组件？
SelectComponentsLabel2=选择要安装的组件，取消选择不需要的组件。点击下一步继续。
FullInstallation=完全安装
CompactInstallation=精简安装
CustomInstallation=自定义安装
NoUninstallWarningTitle=组件已存在
NoUninstallWarning=检测到以下组件已安装在计算机上：%n%n%1%n%n取消选择不会卸载这些组件。%n%n是否继续？
ComponentSize1=%1 KB
ComponentSize2=%1 MB
ComponentsDiskSpaceGBLabel=当前选择需要至少 [gb] GB 磁盘空间。
ComponentsDiskSpaceMBLabel=当前选择需要至少 [mb] MB 磁盘空间。

; *** "选择附加任务" 向导页
WizardSelectTasks=选择附加任务
SelectTasksDesc=要执行哪些附加任务？
SelectTasksLabel2=选择安装 [name] 时要执行的附加任务，然后点击下一步。

; *** "选择开始菜单文件夹" 向导页
WizardSelectProgramGroup=选择开始菜单文件夹
SelectStartMenuFolderDesc=安装程序应将程序的快捷方式放在哪里？
SelectStartMenuFolderLabel3=安装程序将在以下开始菜单文件夹创建快捷方式。
SelectStartMenuFolderBrowseLabel=点击下一步继续。要选择其他文件夹，请点击浏览。
MustEnterGroupName=必须输入文件夹名称。
GroupNameTooLong=文件夹名称或路径过长。
InvalidGroupName=文件夹名称无效。
BadGroupName=文件夹名称不能包含以下字符：%n%n%1
NoProgramGroupCheck2=不创建开始菜单文件夹(&D)

; *** "准备安装" 向导页
WizardReady=准备安装
ReadyLabel1=安装程序已准备好开始安装 [name]。
ReadyLabel2a=点击安装继续，或点击返回检查设置。
ReadyLabel2b=点击安装继续。
ReadyMemoUserInfo=用户信息：
ReadyMemoDir=目标位置：
ReadyMemoType=安装类型：
ReadyMemoComponents=已选组件：
ReadyMemoGroup=开始菜单文件夹：
ReadyMemoTasks=附加任务：

; *** 下载向导页相关
DownloadingLabel=正在下载附加文件...
ButtonStopDownload=停止下载(&S)
StopDownload=确定要停止下载吗？
ErrorDownloadAborted=下载已中止
ErrorDownloadFailed=下载失败：%1 %2
ErrorDownloadSizeFailed=获取大小失败：%1 %2
ErrorFileHash1=文件哈希校验失败：%1
ErrorFileHash2=文件哈希无效：预期 %1，实际 %2
ErrorProgress=进度无效：%1 / %2
ErrorFileSize=文件大小无效：预期 %1，实际 %2

; *** 解压向导页相关
ExtractionLabel=正在解压附加文件...
ButtonStopExtraction=停止解压(&S)
StopExtraction=确定要停止解压吗？
ErrorExtractionAborted=解压已中止
ErrorExtractionFailed=解压失败：%1

; *** "准备安装" 向导页
WizardPreparing=准备安装
PreparingDesc=安装程序正在准备安装 [name]。
PreviousInstallNotCompleted=之前的安装/卸载未完成。需要重启计算机完成该操作。%n%n重启后请再次运行安装程序。
CannotContinue=无法继续安装。请点击取消退出。
ApplicationsFound=以下应用程序正在使用需要更新的文件。建议允许安装程序自动关闭它们。
ApplicationsFound2=以下应用程序正在使用需要更新的文件。建议允许安装程序自动关闭。安装完成后将尝试重启这些应用。
CloseApplications=自动关闭应用程序(&A)
DontCloseApplications=不关闭应用程序(&D)
ErrorCloseApplications=无法自动关闭所有应用程序。建议在继续前手动关闭相关应用。
PrepareToInstallNeedsRestart=必须重启计算机。重启后请再次运行安装程序。%n%n是否立即重启？

; *** "正在安装" 向导页
WizardInstalling=正在安装
InstallingLabel=正在安装 [name]，请稍候...

; *** "安装完成" 向导页
FinishedHeadingLabel=完成 [name] 安装向导
FinishedLabelNoIcons=已成功安装 [name]。
FinishedLabel=已成功安装 [name]。可通过快捷方式启动程序。
ClickFinish=点击完成退出安装程序。
FinishedRestartLabel=要完成安装，必须重启计算机。是否立即重启？
FinishedRestartMessage=要完成安装，必须重启计算机。%n%n是否立即重启？
ShowReadmeCheck=是，我要查看自述文件
YesRadio=是，立即重启(&Y)
NoRadio=否，稍后手动重启(&N)
RunEntryExec=运行 %1
RunEntryShellExec=查看 %1

; *** "需要下一张磁盘" 相关
ChangeDiskTitle=需要下一张磁盘
SelectDiskLabel2=请插入磁盘 %1 并点击确定。%n%n如果文件在其他位置，请输入正确路径或点击浏览。
PathLabel=路径(&P)：
FileNotInDir2=在 "%2" 中找不到文件 "%1"。请插入正确磁盘或选择其他文件夹。
SelectDirectoryLabel=请指定下一张磁盘的位置。

; *** 安装阶段消息
SetupAborted=安装未完成。%n%n请解决问题后重新运行安装程序。
AbortRetryIgnoreSelectAction=选择操作
AbortRetryIgnoreRetry=重试(&T)
AbortRetryIgnoreIgnore=忽略错误继续(&I)
AbortRetryIgnoreCancel=取消安装

; *** 安装状态消息
StatusClosingApplications=正在关闭应用程序...
StatusCreateDirs=正在创建目录...
StatusExtractFiles=正在解压文件...
StatusCreateIcons=正在创建快捷方式...
StatusCreateIniEntries=正在创建 INI 条目...
StatusCreateRegistryEntries=正在创建注册表项...
StatusRegisterFiles=正在注册文件...
StatusSavingUninstall=正在保存卸载信息...
StatusRunProgram=正在完成安装...
StatusRestartingApplications=正在重启应用程序...
StatusRollback=正在回滚更改...

; *** 其他错误
ErrorInternal2=内部错误：%1
ErrorFunctionFailedNoCode=%1 失败
ErrorFunctionFailed=%1 失败；代码 %2
ErrorFunctionFailedWithMessage=%1 失败；代码 %2.%n%3
ErrorExecutingProgram=无法执行文件：%n%1

; *** 注册表错误
ErrorRegOpenKey=打开注册表项失败：%n%1\%2
ErrorRegCreateKey=创建注册表项失败：%n%1\%2
ErrorRegWriteKey=写入注册表项失败：%n%1\%2

; *** INI 错误
ErrorIniEntry=在文件 "%1" 中创建 INI 条目失败。

; *** 文件复制错误
FileAbortRetryIgnoreSkipNotRecommended=跳过此文件（不推荐）(&S)
FileAbortRetryIgnoreIgnoreNotRecommended=忽略错误继续（不推荐）(&I)
SourceIsCorrupted=源文件已损坏
SourceDoesntExist=源文件 "%1" 不存在
ExistingFileReadOnly2=无法替换只读文件。
ExistingFileReadOnlyRetry=去除只读属性后重试(&R)
ExistingFileReadOnlyKeepExisting=保留现有文件(&K)
ErrorReadingExistingDest=读取现有文件时出错：
FileExistsSelectAction=选择操作
FileExists2=文件已存在。
FileExistsOverwriteExisting=覆盖现有文件(&O)
FileExistsKeepExisting=保留现有文件(&K)
FileExistsOverwriteOrKeepAll=对后续冲突执行相同操作(&D)
ExistingFileNewerSelectAction=选择操作
ExistingFileNewer2=现有文件比安装文件新。
ExistingFileNewerOverwriteExisting=覆盖现有文件(&O)
ExistingFileNewerKeepExisting=保留现有文件（推荐）(&K)
ExistingFileNewerOverwriteOrKeepAll=对后续冲突执行相同操作(&D)
ErrorChangingAttr=修改文件属性时出错：
ErrorCreatingTemp=在目标目录创建文件时出错：
ErrorReadingSource=读取源文件时出错：
ErrorCopying=复制文件时出错：
ErrorReplacingExistingFile=替换现有文件时出错：
ErrorRestartReplace=重启替换失败：
ErrorRenamingTemp=重命名目标目录文件时出错：
ErrorRegisterServer=无法注册 DLL/OCX：%1
ErrorRegSvr32Failed=RegSvr32 退出代码 %1
ErrorRegisterTypeLib=无法注册类型库：%1

; *** 卸载显示名称标记
UninstallDisplayNameMark=%1 (%2)
UninstallDisplayNameMarks=%1 (%2, %3)
UninstallDisplayNameMark32Bit=32 位
UninstallDisplayNameMark64Bit=64 位
UninstallDisplayNameMarkAllUsers=所有用户
UninstallDisplayNameMarkCurrentUser=当前用户

; *** 安装后错误
ErrorOpeningReadme=打开自述文件时出错。
ErrorRestartingComputer=无法自动重启计算机，请手动重启。

; *** 卸载程序消息
UninstallNotFound=文件 "%1" 不存在。无法卸载。
UninstallOpenError=无法打开文件 "%1"。无法卸载
UninstallUnsupportedVer=卸载日志 "%1" 格式不被支持。无法卸载
UninstallUnknownEntry=卸载日志中存在未知条目 (%1)
ConfirmUninstall=确定要完全移除 %1 及其所有组件吗？
UninstallOnlyOnWin64=本安装只能在 64 位 Windows 上卸载。
OnlyAdminCanUninstall=只有管理员用户才能卸载此程序。
UninstallStatusLabel=正在从计算机移除 %1，请稍候...
UninstalledAll=已成功从计算机移除 %1。
UninstalledMost=%1 卸载完成。%n%n部分元素无法移除，需手动删除。
UninstalledAndNeedsRestart=要完成卸载，必须重启计算机。%n%n是否立即重启？
UninstallDataCorrupted=文件 "%1" 已损坏。无法卸载

; *** 卸载阶段消息
ConfirmDeleteSharedFileTitle=删除共享文件？
ConfirmDeleteSharedFile2=系统检测到此共享文件已不被其他程序使用。是否删除？%n%n如果仍有程序使用此文件，删除可能导致异常。如不确定请选否。保留文件无害。
SharedFileNameLabel=文件名：
SharedFileLocationLabel=位置：
WizardUninstalling=卸载状态
StatusUninstalling=正在卸载 %1...

; *** 关机阻止原因
ShutdownBlockReasonInstallingApp=正在安装 %1。
ShutdownBlockReasonUninstallingApp=正在卸载 %1。

[CustomMessages]

NameAndVersion=%1 版本 %2
AdditionalIcons=附加快捷方式：
CreateDesktopIcon=创建桌面快捷方式(&D)
CreateQuickLaunchIcon=创建快速启动快捷方式(&Q)
ProgramOnTheWeb=%1 官方网站
UninstallProgram=卸载 %1
LaunchProgram=启动 %1
AssocFileExtension=将 %1 关联到 %2 文件类型(&A)
AssocingFileExtension=正在关联 %1 到 %2 文件类型...
AutoStartProgramGroupDescription=启动：
AutoStartProgram=自动启动 %1
AddonHostProgramNotFound=在所选文件夹找不到 %1。%n%n是否继续？