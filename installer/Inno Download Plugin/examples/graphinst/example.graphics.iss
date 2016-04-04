 ; UI file for Graphical Installer
#define public GraphicalInstallerUI "GraphicalInstallerUI"
 
; Texts colors
#define public TextsColor    "$000000"
#define public HeadersColor  "$000000"
#define public InversedColor "$FFFFFF"
 
; Buttons colors
#define public ButtonNormalColor   "$FFFFFF"
#define public ButtonFocusedColor  "$000050"
#define public ButtonPressedColor  "$FFFFFF"
#define public ButtonDisabledColor "$000000"
 
; Images - all files must be in the same directory as this .iss file!
#define public TopPicture    "background-top.jpg"    ; 690x416 px
#define public InnerPicture  "background-inner.jpg"  ; 413x237 px
#define public BottomPicture "background-bottom.jpg" ; 690x83 px
#define public ButtonPicture "button.png"            ; 80x136 px
 
; File with core functions and procedures
#include "compiler:Graphical Installer\GraphicalInstaller_functions.iss"
  
[Files]
; Pictures with skin 
Source: {#TopPicture};    Flags: dontcopy;
Source: {#InnerPicture};  Flags: dontcopy;
Source: {#BottomPicture}; Flags: dontcopy;
Source: {#ButtonPicture}; Flags: dontcopy;
; DLLs
Source: compiler:Graphical Installer\InnoCallback.dll; Flags: dontcopy;
Source: compiler:Graphical Installer\botva2.dll;       Flags: dontcopy;
