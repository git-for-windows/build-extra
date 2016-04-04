history = {
    --release  rev   description
    { "1.0.0",  86, "First release" },
    { "1.0.1",  89, "Fixed incorrect opening of some HTTP URLs.<br/>French &amp; German language files (partial)." },
    { "1.1.0", 104, [[Support for mirrors.<br/>
                      <tt>ConnectTimeout</tt>, <tt>SendTimeout</tt> and <tt>ReceiveTimeout</tt> options.<br/>
                      German &amp; Polish translations]]},
    { "1.1.1", 106, "Fixed Issue 2: V512 A call of the 'memset' function will lead to underflow of the buffer 'buf'. trace.cpp 23" },
    { "1.1.2", 112, "Belarusian translation.<br/>Small changes &amp; bugfixes." },
    { "1.2.0", 121, "Compatibility with Graphical Installer.<br/><tt>Referer</tt> option to set referer URL." },
    { "1.2.1", 124, "Fix: idpGetFilesSize() now uses specified internet options.<br/>Marquee on progress bars now working when ISSkin is used." },
    { "1.2.2", 130, [[If <tt>AllowContinue</tt> option turned on, IDP will continue downloading files, even if one or more files cannot 
                      be downloaded. Also, <tt>StopOnError</tt> option added to control this behavior.<br/>
                      <tt>idpFileDownloaded()</tt> function to check status of single file.<br/>
                      Fixed incorrect function of SSL error dialog (bug was introduced in version 1.2.0).]] },
    { "1.2.3", 133, "Fixed idpFileDownloaded() function.<br/>Progress bar now working when part of files cannot be downloaded." },
    { "1.3.0", 142, [[idpAddFileComp()/idpAddFileSizeComp() functions.<br/>
                      Advanced error dialog, showing list of not downloaded files &amp; <tt>ErrorDialog</tt> option to switch between standard/advanced dialogs<br/>
                      Brazilian Portuguese translation.]] },
    { "1.3.1", 144, "Finnish translation." },
    { "1.3.2", 147, "Downloading now works correctly in silent mode (/SILENT)<br>idpDownloadFilesComp() function." },
    { "1.3.3", 154, [[Download progress window now visible in silent mode. Use /VERYSILENT parameter to hide it.<br/>
                      Support for /SUPPRESSMSGBOXES command line parameter.<br/>
                      Italian translation.]] },
    { "1.4.0", 158, "Support for setting proxy name, port, username and password." },
    { "1.4.1", 165, "Simplified Chinese translation.<br/>Compatibility with VCL Styles for Inno Setup." },
    { "1.4.2", 168, "idpSetLogin() function for setting user name and password." },
    { "1.4.3", 170, "IDP_VER* macros." },
    { "1.5.0", 179, "idpAddFtpDir() function for downloading whole directories with single function call."},
}
