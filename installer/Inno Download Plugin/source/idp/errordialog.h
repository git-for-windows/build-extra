#pragma once

#include <windows.h>
#include <map>
#include "netfile.h"
#include "tstring.h"

#define DLG_NONE     0
#define DLG_SIMPLE   1
#define DLG_FILELIST 2
#define DLG_URLLIST  3

using namespace std;

class Ui;

class ErrorDialog
{
public:
    ErrorDialog(Ui *parent = NULL);
    ~ErrorDialog();

    void setUi(Ui *parent);
    void setFont(HFONT newFont);
    void setErrorMsg(tstring msg);
    void setFileList(map<tstring, NetFile *> fileList);
    void setComponents(set<tstring> componentList);
    int  exec();

protected:
    void localize();
    void setItemText(int id, tstring text);
    void fillFileList();

    map<tstring, NetFile *> files;
    set<tstring>            components;
    HWND                    handle;
    HWND                    listBox;
    Ui                     *ui;
    HFONT                   font;
    tstring                 errorMsg;

    friend BOOL CALLBACK ErrorDialogProc(HWND hDlg, UINT msg, WPARAM wParam, LPARAM lParam);
};

BOOL CALLBACK ErrorDialogProc(HWND hDlg, UINT msg, WPARAM wParam, LPARAM lParam);
