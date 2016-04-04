#include "ui.h"
#include "url.h"
#include "timer.h"
#include "trace.h"
#include "downloader.h"

//HACK: to allow set parent window for InternetErrorDlg in Url class.
static HWND uiMainWindowHandle = NULL;

HWND uiMainWindow()
{
    return uiMainWindowHandle ? uiMainWindowHandle : GetDesktopWindow();
}

Ui::Ui()
{
    controls["TotalProgressBar"] = NULL;
    controls["FileProgressBar"]  = NULL;
    controls["TotalDownloaded"]  = NULL;
    controls["FileDownloaded"]   = NULL;
    controls["FileName"]         = NULL;
    controls["Speed"]            = NULL;
    controls["Status"]           = NULL;
    controls["ElapsedTime"]      = NULL;
    controls["RemainingTime"]    = NULL;
    controls["NextButton"]       = NULL;
    controls["BackButton"]       = NULL;
    controls["WizardForm"]       = NULL;
    controls["WizardPage"]       = NULL;
    controls["LabelFont"]        = NULL;
    //Graphical Installer
    controls["GINextButton"]     = NULL;
    controls["GIBackButton"]     = NULL;
    //HACK to call idpReportError in main thread
    controls["InvisibleButton"]  = NULL;

    allowContinue    = false;
    hasRetryButton   = true;
    detailedMode     = false;
    redrawBackground = false;
    errorDlgMode     = DLG_SIMPLE;
    dllHandle        = NULL;

    _tsetlocale(LC_ALL, _T(""));
}

Ui::~Ui()
{
}

void Ui::connectControl(tstring name, HWND handle)
{
    controls[toansi(name)] = handle;

    if(name.compare(_T("WizardForm")) == 0)
        uiMainWindowHandle = handle;
}

void Ui::addMessage(tstring name, tstring message)
{
    messages[toansi(name)] = message;
}

void Ui::setFileName(tstring filename)
{
    setLabelText(controls["FileName"], filename);
    clearLabel(controls["FileDownloaded"]);
}

tstring Ui::msg(string key)
{
    if(messages.count(key))
        return messages[key].empty() ? tocurenc(key) : messages[key];
    else
        return tocurenc(key);
}

void Ui::setProgressInfo(DWORDLONG totalSize, DWORDLONG totalDownloaded, DWORDLONG fileSize, DWORDLONG fileDownloaded)
{
    if(!(totalSize == FILE_SIZE_UNKNOWN))
    {
        double totalPercents = 100.0 / ((double)totalSize / (double)totalDownloaded);
        setProgressBarPos(controls["TotalProgressBar"], f2i(totalPercents));
    }

    if(!(fileSize == FILE_SIZE_UNKNOWN))
    {
        double filePercents  = 100.0 / ((double)fileSize / (double)fileDownloaded);
        setProgressBarPos(controls["FileProgressBar"], f2i(filePercents));
    }
}

void Ui::setSpeedInfo(DWORD speed, DWORD remainingTime)
{
    setLabelText(controls["RemainingTime"], speed ? Timer::msecToStr(remainingTime, _T("%02u:%02u:%02u")) : msg("Unknown"));
    setLabelText(controls["Speed"],         formatspeed(speed, msg("KB/s"), msg("MB/s")));
}

void Ui::setSpeedInfo(DWORD speed)
{
    setLabelText(controls["RemainingTime"], msg("Unknown"));
    setLabelText(controls["Speed"],         formatspeed(speed, msg("KB/s"), msg("MB/s")));
}

void Ui::setSizeTimeInfo(DWORDLONG totalSize, DWORDLONG totalDownloaded, DWORDLONG fileSize, DWORDLONG fileDownloaded, DWORD elapsedTime)
{
    setLabelText(controls["ElapsedTime"], Timer::msecToStr(elapsedTime, _T("%02u:%02u:%02u")));
    
    if(totalDownloaded > totalSize)
        clearLabel(controls["TotalDownloaded"]);

    tstring totalSizeText = ((totalSize == FILE_SIZE_UNKNOWN) || (totalDownloaded > totalSize)) ?
                            formatsize(totalDownloaded, msg("KB"), msg("MB"), msg("GB")) :
                            formatsize(msg("%.2f of %.2f"), totalDownloaded, totalSize, msg("KB"), msg("MB"), msg("GB"));

    tstring fileSizeText = (fileSize == FILE_SIZE_UNKNOWN) ?
                           formatsize(fileDownloaded, msg("KB"), msg("MB"), msg("GB")) :
                           formatsize(msg("%.2f of %.2f"), fileDownloaded, fileSize, msg("KB"), msg("MB"), msg("GB"));

    rightAlignLabel(controls["TotalDownloaded"], totalSizeText);
    rightAlignLabel(controls["FileDownloaded"],  fileSizeText);

    setLabelText(controls["TotalDownloaded"], totalSizeText);
    setLabelText(controls["FileDownloaded"],  fileSizeText);
}

void Ui::setStatus(tstring status)
{
    statusStr = status;
    setLabelText(detailedMode ? controls["Status"] : controls["TotalProgressLabel"], status);
}

void Ui::setMarquee(bool marquee, bool total)
{
    if(total)
        setProgressBarMarquee(controls["TotalProgressBar"], marquee);
    
    setProgressBarMarquee(controls["FileProgressBar"],  marquee);
}

void Ui::setDetailedMode(bool mode)
{
    detailedMode = mode;

    if(detailedMode)
    {
        setLabelText(controls["Status"], statusStr);
        setLabelText(controls["TotalProgressLabel"], msg("Total progress"));
    }
    else
        setLabelText(controls["TotalProgressLabel"], statusStr);
}

void Ui::setLabelText(HWND l, tstring text)
{
    if(l)
    {
        if(redrawBackground)
        {
            RECT r;
            GetWindowRect(l, &r);
            MapWindowPoints(HWND_DESKTOP, GetParent(l), (LPPOINT)&r, 2);
            RedrawWindow(GetParent(l), &r, NULL, RDW_INVALIDATE | RDW_ERASENOW | RDW_UPDATENOW);
        }
        SendMessage(l, WM_SETTEXT, 0, (LPARAM)text.c_str());
    }
}

void Ui::clearLabel(HWND l)
{
    _TCHAR spaces[40];
    for(int i = 0; i < 40; i++)
        spaces[i] = _T(' ');
    spaces[39] = 0;
    setLabelText(l, spaces);
}

void Ui::setProgressBarPos(HWND pb, int pos)
{
    if(pb)
        PostMessage(pb, PBM_SETPOS, (int)((65535.0 / 100.0) * pos), 0);
}

void Ui::setProgressBarMarquee(HWND pb, bool marquee)
{
    if(!pb)
        return;

    LONG style = GetWindowLong(pb, GWL_STYLE);

    if(marquee)
    {
        style |= PBS_MARQUEE;
        SetWindowLong(pb, GWL_STYLE, style);
        SendMessage(pb, PBM_SETMARQUEE, (WPARAM)TRUE, 30);
    }
    else
    {
        style ^= PBS_MARQUEE;
        SendMessage(pb, PBM_SETMARQUEE, (WPARAM)FALSE, 0);
        SetWindowLong(pb, GWL_STYLE, style);
        RedrawWindow(pb, NULL, NULL, RDW_INVALIDATE | RDW_ERASENOW | RDW_UPDATENOW);
    }
}

void Ui::rightAlignLabel(HWND label, tstring text)
{
    HDC dc = GetDC(label);
    SelectObject(dc, (HGDIOBJ)controls["LabelFont"]);

    SIZE textSize;
    GetTextExtentPoint32(dc, text.c_str(), (int)text.size(), &textSize);

    RECT labelRect;
    GetWindowRect(label, &labelRect);
    MapWindowPoints(HWND_DESKTOP, GetParent(label), (LPPOINT)&labelRect, 2);

    MoveWindow(label, labelRect.right - textSize.cx, labelRect.top, textSize.cx, labelRect.bottom - labelRect.top, FALSE);
}

int Ui::messageBox(tstring text, tstring caption, DWORD type)
{
    return MessageBox(controls["WizardForm"], text.c_str(), caption.c_str(), type);
}

int Ui::errorDialog(Downloader *d)
{
    ErrorDialog dlg(this);
    dlg.setFont((HFONT)controls["LabelFont"]);
    dlg.setErrorMsg(d->getLastErrorStr());
    dlg.setFileList(d->files);
    dlg.setComponents(d->components);
    return dlg.exec();
}

void Ui::clickNextButton()
{
    if(controls["GIBackButton"])
    {
        ShowWindow(controls["BackButton"],   SW_HIDE);
        ShowWindow(controls["GIBackButton"], SW_HIDE);
    }

    if(controls["NextButton"])
    {
        EnableWindow(controls["NextButton"], TRUE);
        SendMessage(controls["WizardForm"], WM_COMMAND, MAKEWPARAM(0, BN_CLICKED), (LPARAM)controls["NextButton"]);
    }
}

void Ui::lockButtons()
{ 
    if(controls["BackButton"])
    {
        if(hasRetryButton)
            ShowWindow(controls["BackButton"], SW_HIDE);
        else
            EnableWindow(controls["BackButton"], FALSE);
    }

    if(controls["NextButton"])
        EnableWindow(controls["NextButton"], FALSE);

    //Graphical Installer
    if(controls["GIBackButton"])
    {
        if(hasRetryButton)
            ShowWindow(controls["GIBackButton"], SW_HIDE);
        else
            EnableWindow(controls["GIBackButton"], FALSE);
    }

    if(controls["GINextButton"])
        EnableWindow(controls["GINextButton"], FALSE);
}

void Ui::unlockButtons()
{ 
    if(controls["BackButton"])
    {
        if(hasRetryButton)
            ShowWindow(controls["BackButton"], SW_SHOW);
        else
            EnableWindow(controls["BackButton"], TRUE);
    }

    if(controls["NextButton"])
        EnableWindow(controls["NextButton"], allowContinue);

    //Graphical Installer    
    if(controls["GIBackButton"])
    {
        if(hasRetryButton)
            ShowWindow(controls["GIBackButton"], SW_SHOW);
        else
            EnableWindow(controls["GIBackButton"], TRUE);
    }

    if(controls["GINextButton"])
        EnableWindow(controls["GINextButton"], allowContinue);

    SendMessage(controls["TotalProgressBar"], PBM_SETMARQUEE, (WPARAM)FALSE, 0);
}

void Ui::reportError()
{
    if(controls["InvisibleButton"])
        SendMessage(controls["WizardForm"], WM_COMMAND, MAKEWPARAM(0, BN_CLICKED), (LPARAM)controls["InvisibleButton"]);
    else
        idpReportError();
}
