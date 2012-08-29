Attribute VB_Name = "Menu_Icons"
'***************************************************************************
'Specialized Icon Handler
'Copyright �2011-2012 by Tanner Helland
'Created: 24/June/12
'Last updated: 12/August/12
'Last update: Added ResetMenuIcons, which redraws menu icons that may have been dropped due to the menu
'             caption changing (necessary for Undo/Redo text updating)
'
'Because VB6 doesn't provide many mechanisms for working with icons, I've had to manually add a number of
' icon-related functions to PhotoDemon.  First is a way to add icons/bitmaps to menus, as originally written
' by Leandro Ascierto.  Menu icons are extracted from a resource file (where they're stored in PNG format) and
' rendered to the menu at run-time.  See the clsMenuImage class for details on how this works.
' (A link to Leandro's original project can also be found there.)
'
'NOTE: Because the Windows XP version of Leandro's code utilizes potentially dirty subclassing,
' PhotoDemon automatically disables menu icons while running in the IDE on Windows XP.  Compile the project to see icons.
' (Windows Vista and 7 use a different mechanism, so menu icons are enabled in the IDE, and menu icons appear on all
' versions of Windows when compiled.)
'
'Also in this module is a heavily modified version of Paul Turcksin's "Icon Handlemaker" project, which I've modified
' to convert bitmaps to icons on the fly (the "CreateCustomFormIcon" sub).  PhotoDemon uses this to dynamically change
' the icon of its MDI child forms.  To see Paul's original project, please visit this PSC link:
' http://www.planetsourcecode.com/vb/scripts/ShowCode.asp?txtCodeId=60600&lngWId=1
'
'***************************************************************************

Option Explicit

'API calls for building an icon at run-time
Private Declare Function BitBlt Lib "gdi32" (ByVal hDestDC As Long, ByVal x As Long, ByVal y As Long, ByVal nWidth As Long, ByVal nHeight As Long, ByVal hSrcDC As Long, ByVal xSrc As Long, ByVal ySrc As Long, ByVal dwRop As Long) As Long
Private Declare Function CreateCompatibleBitmap Lib "gdi32" (ByVal hDC As Long, ByVal nWidth As Long, ByVal nHeight As Long) As Long
Private Declare Function CreateCompatibleDC Lib "gdi32" (ByVal hDC As Long) As Long
Private Declare Function CreateIconIndirect Lib "user32" (icoInfo As ICONINFO) As Long
Private Declare Function DeleteDC Lib "gdi32" (ByVal hDC As Long) As Long
Private Declare Function DeleteObject Lib "gdi32" (ByVal hObject As Long) As Long
Private Declare Function DestroyIcon Lib "user32" (ByVal hIcon As Long) As Long
Private Declare Function GetObject Lib "gdi32" Alias "GetObjectA" (ByVal hObject As Long, ByVal nCount As Long, lpObject As Any) As Long
Private Declare Function GetBkColor Lib "gdi32" (ByVal hDC As Long) As Long
'Private Declare Function OleCreatePictureIndirect Lib "olepro32.dll" (lppictDesc As pictDesc, riid As Guid, ByVal fown As Long, ipic As IPicture) As Long
Private Declare Function SelectObject Lib "gdi32" (ByVal hDC As Long, ByVal hObject As Long) As Long
Private Declare Function SetBkColor Lib "gdi32" (ByVal hDC As Long, ByVal crColor As Long) As Long
Private Declare Function SetTextColor Lib "gdi32" (ByVal hDC As Long, ByVal crColor As Long) As Long

'Types required by the above API calls
Private Type Bitmap
   bmType As Long
   bmWidth As Long
   bmHeight As Long
   bmWidthBytes As Long
   bmPlanes As Integer
   bmBitsPixel As Integer
   bmBits As Long
End Type

Private Type ICONINFO
   fIcon As Boolean
   xHotspot As Long
   yHotspot As Long
   hbmMask As Long
   hbmColor As Long
   End Type

'This array will be used to store our icon handles so we can delete them on program exit
Dim numOfIcons As Long
Dim iconHandles() As Long

'The types and constants below (commented out) can be used to generate an icon object for use within VB

'Private Type Guid
'   Data1 As Long
'   Data2 As Integer
'   Data3 As Integer
'   Data4(7) As Byte
'   End Type

'Private Type pictDesc
'   cbSizeofStruct As Long
'   picType As Long
'   hImage As Long
'End Type

'Constants required by the icon-related API calls
'Private Const PICTYPE_BITMAP = 1
'Private Const PICTYPE_ICON = 3

'API call for manually setting a 32-bit icon to a form (as opposed to Form.Icon = ...)
Private Declare Function SendMessageLong Lib "user32" Alias "SendMessageA" (ByVal HWnd As Long, ByVal wMsg As Long, ByVal wParam As Long, ByVal lParam As Long) As Long

'clsMenuImage does the heavy lifting for inserting icons into menus
Dim cMenuImage As clsMenuImage


'Load all the menu icons from PhotoDemon's embedded resource file
Public Sub LoadMenuIcons()

    Set cMenuImage = New clsMenuImage

    With cMenuImage
    
        'Disable menu icon drawing if on Windows XP and uncompiled (to prevent subclassing crashes on unclean IDE breaks)
        If (Not .IsWindowVistaOrLater) And (IsProgramCompiled = False) Then Exit Sub
        
        .Init FormMain.HWnd, 16, 16
        
        .AddImageFromStream LoadResData("OPENIMG", "CUSTOM")     '0
        .AddImageFromStream LoadResData("OPENREC", "CUSTOM")     '1
        .AddImageFromStream LoadResData("IMPORT", "CUSTOM")      '2
        .AddImageFromStream LoadResData("SAVE", "CUSTOM")        '3
        .AddImageFromStream LoadResData("SAVEAS", "CUSTOM")      '4
        .AddImageFromStream LoadResData("CLOSE", "CUSTOM")       '5
        .AddImageFromStream LoadResData("BCONVERT", "CUSTOM")    '6
        .AddImageFromStream LoadResData("PRINT", "CUSTOM")       '7
        .AddImageFromStream LoadResData("SCANNER", "CUSTOM")     '8
        .AddImageFromStream LoadResData("DOWNLOAD", "CUSTOM")    '9
        .AddImageFromStream LoadResData("SCREENCAP", "CUSTOM")   '10
        .AddImageFromStream LoadResData("FRXIMPORT", "CUSTOM")   '11
        .AddImageFromStream LoadResData("UNDO", "CUSTOM")        '12
        .AddImageFromStream LoadResData("REDO", "CUSTOM")        '13
        .AddImageFromStream LoadResData("REPEAT", "CUSTOM")      '14
        .AddImageFromStream LoadResData("COPY", "CUSTOM")        '15
        .AddImageFromStream LoadResData("PASTE", "CUSTOM")       '16
        .AddImageFromStream LoadResData("CLEAR", "CUSTOM")       '17
        .AddImageFromStream LoadResData("PREFERENCES", "CUSTOM") '18
        .AddImageFromStream LoadResData("RESIZE", "CUSTOM")      '19
        .AddImageFromStream LoadResData("ROTATECW", "CUSTOM")    '20
        .AddImageFromStream LoadResData("ROTATECCW", "CUSTOM")   '21
        .AddImageFromStream LoadResData("ROTATE180", "CUSTOM")   '22
        .AddImageFromStream LoadResData("FLIP", "CUSTOM")        '23
        .AddImageFromStream LoadResData("MIRROR", "CUSTOM")      '24
        .AddImageFromStream LoadResData("PDWEBSITE", "CUSTOM")   '25
        .AddImageFromStream LoadResData("FEEDBACK", "CUSTOM")    '26
        .AddImageFromStream LoadResData("ABOUT", "CUSTOM")       '27
        .AddImageFromStream LoadResData("FITWINIMG", "CUSTOM")   '28
        .AddImageFromStream LoadResData("FITONSCREEN", "CUSTOM") '29
        .AddImageFromStream LoadResData("TILEHOR", "CUSTOM")     '30
        .AddImageFromStream LoadResData("TILEVER", "CUSTOM")     '31
        .AddImageFromStream LoadResData("CASCADE", "CUSTOM")     '32
        .AddImageFromStream LoadResData("ARNGICONS", "CUSTOM")   '33
        .AddImageFromStream LoadResData("MINALL", "CUSTOM")      '34
        .AddImageFromStream LoadResData("RESTOREALL", "CUSTOM")  '35
        .AddImageFromStream LoadResData("OPENMACRO", "CUSTOM")   '36
        .AddImageFromStream LoadResData("RECORD", "CUSTOM")      '37
        .AddImageFromStream LoadResData("RECORDSTOP", "CUSTOM")  '38
        .AddImageFromStream LoadResData("BUG", "CUSTOM")         '39
        .AddImageFromStream LoadResData("FAVORITE", "CUSTOM")    '40
        .AddImageFromStream LoadResData("UPDATES", "CUSTOM")     '41
        .AddImageFromStream LoadResData("DUPLICATE", "CUSTOM")   '42
        .AddImageFromStream LoadResData("EXIT", "CUSTOM")        '43
        .AddImageFromStream LoadResData("CLEARRECENT", "CUSTOM") '44
        .AddImageFromStream LoadResData("SCANNERSEL", "CUSTOM")  '45
        .AddImageFromStream LoadResData("BRIGHT", "CUSTOM")      '46
        .AddImageFromStream LoadResData("GAMMA", "CUSTOM")       '47
        .AddImageFromStream LoadResData("LEVELS", "CUSTOM")      '48
        .AddImageFromStream LoadResData("WHITEBAL", "CUSTOM")    '49
        .AddImageFromStream LoadResData("HISTOGRAM", "CUSTOM")   '50
        .AddImageFromStream LoadResData("EQUALIZE", "CUSTOM")    '51
        .AddImageFromStream LoadResData("STRETCH", "CUSTOM")     '52
        .AddImageFromStream LoadResData("COLORSHIFTR", "CUSTOM") '53
        .AddImageFromStream LoadResData("COLORSHIFTL", "CUSTOM") '54
        .AddImageFromStream LoadResData("RECHANNELR", "CUSTOM")  '55
        .AddImageFromStream LoadResData("RECHANNELG", "CUSTOM")  '56
        .AddImageFromStream LoadResData("RECHANNELB", "CUSTOM")  '57
        .AddImageFromStream LoadResData("BLACKWHITE", "CUSTOM")  '58
        .AddImageFromStream LoadResData("COLORIZE", "CUSTOM")    '59
        .AddImageFromStream LoadResData("ENHANCE", "CUSTOM")     '60
        .AddImageFromStream LoadResData("ENCONTRAST", "CUSTOM")  '61
        .AddImageFromStream LoadResData("ENHIGHLIGHT", "CUSTOM") '62
        .AddImageFromStream LoadResData("ENMIDTONE", "CUSTOM")   '63
        .AddImageFromStream LoadResData("ENSHADOW", "CUSTOM")    '64
        .AddImageFromStream LoadResData("GRAYSCALE", "CUSTOM")   '65
        .AddImageFromStream LoadResData("INVERT", "CUSTOM")      '66
        .AddImageFromStream LoadResData("INVCMYK", "CUSTOM")     '67
        .AddImageFromStream LoadResData("INVHUE", "CUSTOM")      '68
        .AddImageFromStream LoadResData("INVRGB", "CUSTOM")      '69
        .AddImageFromStream LoadResData("POSTERIZE", "CUSTOM")   '70
        .AddImageFromStream LoadResData("REDUCECOLORS", "CUSTOM") '71
        .AddImageFromStream LoadResData("COUNTCOLORS", "CUSTOM") '72
        .AddImageFromStream LoadResData("FADELAST", "CUSTOM")    '73
        .AddImageFromStream LoadResData("ARTISTIC", "CUSTOM")    '74
        .AddImageFromStream LoadResData("BLUR", "CUSTOM")        '75
        .AddImageFromStream LoadResData("DIFFUSE", "CUSTOM")     '76
        .AddImageFromStream LoadResData("EDGES", "CUSTOM")       '77
        .AddImageFromStream LoadResData("NATURAL", "CUSTOM")     '78
        .AddImageFromStream LoadResData("NOISE", "CUSTOM")       '79
        .AddImageFromStream LoadResData("OTHER", "CUSTOM")       '80
        .AddImageFromStream LoadResData("RANK", "CUSTOM")        '81
        .AddImageFromStream LoadResData("SHARPEN", "CUSTOM")     '82
        .AddImageFromStream LoadResData("ANTIQUE", "CUSTOM")     '83
        .AddImageFromStream LoadResData("COMICBOOK", "CUSTOM")   '84
        .AddImageFromStream LoadResData("MOSAIC", "CUSTOM")      '85
        .AddImageFromStream LoadResData("PENCIL", "CUSTOM")      '86
        .AddImageFromStream LoadResData("RELIEF", "CUSTOM")      '87
        .AddImageFromStream LoadResData("ANTIALIAS", "CUSTOM")   '88
        .AddImageFromStream LoadResData("SOFTEN", "CUSTOM")      '89
        .AddImageFromStream LoadResData("SOFTENMORE", "CUSTOM")  '90
        .AddImageFromStream LoadResData("BLUR2", "CUSTOM")       '91
        .AddImageFromStream LoadResData("BLURMORE", "CUSTOM")    '92
        .AddImageFromStream LoadResData("GAUSSBLUR", "CUSTOM")   '93
        .AddImageFromStream LoadResData("GAUSSBLURMOR", "CUSTOM") '94
        .AddImageFromStream LoadResData("GRIDBLUR", "CUSTOM")    '95
        .AddImageFromStream LoadResData("DIFFUSEMORE", "CUSTOM") '96
        .AddImageFromStream LoadResData("DIFFUSECUST", "CUSTOM") '97
        .AddImageFromStream LoadResData("CUSTFILTER", "CUSTOM")  '98
        .AddImageFromStream LoadResData("EDGEENHANCE", "CUSTOM") '99
        .AddImageFromStream LoadResData("EMBOSS", "CUSTOM")      '100
        .AddImageFromStream LoadResData("INVCOMPOUND", "CUSTOM") '101
        .AddImageFromStream LoadResData("FADE", "CUSTOM")        '102
        .AddImageFromStream LoadResData("FADELOW", "CUSTOM")     '103
        .AddImageFromStream LoadResData("FADEHIGH", "CUSTOM")    '104
        .AddImageFromStream LoadResData("CUSTOMFADE", "CUSTOM")  '105
        .AddImageFromStream LoadResData("UNFADE", "CUSTOM")      '106
        .AddImageFromStream LoadResData("ATMOSPHERE", "CUSTOM")  '107
        .AddImageFromStream LoadResData("BURN", "CUSTOM")        '108
        .AddImageFromStream LoadResData("FOG", "CUSTOM")         '109
        .AddImageFromStream LoadResData("FREEZE", "CUSTOM")      '110
        .AddImageFromStream LoadResData("LAVA", "CUSTOM")        '111
        .AddImageFromStream LoadResData("OCEAN", "CUSTOM")       '112
        .AddImageFromStream LoadResData("RAINBOW", "CUSTOM")     '113
        .AddImageFromStream LoadResData("STEEL", "CUSTOM")       '114
        .AddImageFromStream LoadResData("WATER", "CUSTOM")       '115
        .AddImageFromStream LoadResData("ADDNOISE", "CUSTOM")    '116
        .AddImageFromStream LoadResData("DESPECKLE", "CUSTOM")   '117
        .AddImageFromStream LoadResData("REMOVEORPHAN", "CUSTOM") '118
        .AddImageFromStream LoadResData("DILATE", "CUSTOM")      '119
        .AddImageFromStream LoadResData("ERODE", "CUSTOM")       '120
        .AddImageFromStream LoadResData("EXTREME", "CUSTOM")     '121
        .AddImageFromStream LoadResData("CUSTRANK", "CUSTOM")    '122
        .AddImageFromStream LoadResData("SHARPENMORE", "CUSTOM") '123
        .AddImageFromStream LoadResData("UNSHARP", "CUSTOM")     '124
        .AddImageFromStream LoadResData("ISOMETRIC", "CUSTOM")   '125
        .AddImageFromStream LoadResData("ALIEN", "CUSTOM")       '126
        .AddImageFromStream LoadResData("BLACKLIGHT", "CUSTOM")  '127
        .AddImageFromStream LoadResData("DREAM", "CUSTOM")       '128
        .AddImageFromStream LoadResData("RADIOACTIVE", "CUSTOM") '129
        .AddImageFromStream LoadResData("SOLARIZE", "CUSTOM")    '130
        .AddImageFromStream LoadResData("SYNTHESIZE", "CUSTOM")  '131
        .AddImageFromStream LoadResData("TILE", "CUSTOM")        '132
        .AddImageFromStream LoadResData("TWINS", "CUSTOM")       '133
        .AddImageFromStream LoadResData("VIBRATE", "CUSTOM")     '134
        
        
        'File Menu
        .PutImageToVBMenu 0, 0, 0       'Open Image
        .PutImageToVBMenu 1, 1, 0       'Open recent
        .PutImageToVBMenu 2, 2, 0       'Import
        .PutImageToVBMenu 3, 4, 0       'Save
        .PutImageToVBMenu 4, 5, 0       'Save As...
        .PutImageToVBMenu 5, 7, 0       'Close...
        .PutImageToVBMenu 6, 9, 0       'Batch conversion
        .PutImageToVBMenu 7, 11, 0      'Print
        .PutImageToVBMenu 43, 13, 0     'Exit
        
        '--> Import Sub-Menu
        'NOTE: the specific menu values will be different if the scanner plugin (eztw32.dll) isn't found.
        If ScanEnabled = True Then
            .PutImageToVBMenu 8, 0, 0, 2       'Scan Image
            .PutImageToVBMenu 45, 1, 0, 2      'Select Scanner
            .PutImageToVBMenu 9, 3, 0, 2       'Download Image
            .PutImageToVBMenu 10, 5, 0, 2      'Capture Screen
            .PutImageToVBMenu 11, 7, 0, 2      'Import from FRX
        Else
            .PutImageToVBMenu 9, 0, 0, 2       'Download Image
            .PutImageToVBMenu 10, 2, 0, 2      'Capture Screen
            .PutImageToVBMenu 11, 4, 0, 2      'Import from FRX
        End If
        
        'Edit Menu
        .PutImageToVBMenu 12, 0, 1      'Undo
        .PutImageToVBMenu 13, 1, 1      'Redo
        .PutImageToVBMenu 14, 2, 1      'Repeat Last Action
        .PutImageToVBMenu 15, 4, 1      'Copy
        .PutImageToVBMenu 16, 5, 1      'Paste
        .PutImageToVBMenu 17, 6, 1      'Empty Clipboard
        .PutImageToVBMenu 18, 8, 1      'Program Preferences
        
        'Image Menu
        .PutImageToVBMenu 42, 0, 2
        .PutImageToVBMenu 19, 2, 2      'Resize
        .PutImageToVBMenu 23, 4, 2      'Flip
        .PutImageToVBMenu 24, 5, 2      'Mirror
        .PutImageToVBMenu 22, 6, 2      'Top Rotate menu
        .PutImageToVBMenu 20, 0, 2, 6     'Rotate Clockwise (rotate submenu)
        .PutImageToVBMenu 21, 1, 2, 6     'Rotate Counter-clockwise (rotate submenu)
        .PutImageToVBMenu 22, 2, 2, 6     'Rotate 180 (rotate submenu)
        .PutImageToVBMenu 125, 8, 2     'Isometric
        
        'Color Menu
        .PutImageToVBMenu 46, 0, 3      'Brightness/Contrast
        .PutImageToVBMenu 47, 1, 3      'Gamma Correction
        .PutImageToVBMenu 48, 2, 3      'Levels
        .PutImageToVBMenu 49, 3, 3      'White Balance
        .PutImageToVBMenu 50, 5, 3      'Histogram
            '--> Histogram sub-menu
            .PutImageToVBMenu 50, 0, 3, 5   'Display Histogram
            .PutImageToVBMenu 51, 1, 3, 5   'Equalize
            .PutImageToVBMenu 52, 2, 3, 5   'Stretch
        .PutImageToVBMenu 53, 7, 3      'Color Shift
            '--> Color-Shift sub-menu
            .PutImageToVBMenu 53, 0, 3, 7   'Shift Right
            .PutImageToVBMenu 54, 1, 3, 7   'Shift Left
        .PutImageToVBMenu 57, 8, 3      'Rechannel
            '--> Rechannel sub-menu
            .PutImageToVBMenu 55, 0, 3, 8   'Red
            .PutImageToVBMenu 56, 1, 3, 8   'Green
            .PutImageToVBMenu 57, 2, 3, 8   'Blue
        .PutImageToVBMenu 58, 10, 3      'Black and White
        .PutImageToVBMenu 59, 11, 3      'Colorize
        .PutImageToVBMenu 60, 12, 3      'Enhance
            '--> Enhance sub-menu
            .PutImageToVBMenu 61, 0, 3, 12   'Contrast
            .PutImageToVBMenu 62, 1, 3, 12   'Highlights
            .PutImageToVBMenu 63, 2, 3, 12   'Midtones
            .PutImageToVBMenu 64, 3, 3, 12   'Shadows
        .PutImageToVBMenu 102, 13, 3     'Fade
            '--> Fade sub-menu
            .PutImageToVBMenu 103, 0, 3, 13  'Low Fade
            .PutImageToVBMenu 102, 1, 3, 13  'Medium Fade
            .PutImageToVBMenu 104, 2, 3, 13  'High Fade
            .PutImageToVBMenu 105, 3, 3, 13  'Custom Fade
            .PutImageToVBMenu 106, 5, 3, 13  'Unfade
        .PutImageToVBMenu 65, 14, 3      'Grayscale
        .PutImageToVBMenu 66, 15, 3      'Invert
            '--> Invert sub-menu
            .PutImageToVBMenu 101, 0, 3, 15  'Compound Invert
            .PutImageToVBMenu 67, 1, 3, 15   'Invert CMYK
            .PutImageToVBMenu 68, 2, 3, 15   'Invert Hue
            .PutImageToVBMenu 69, 3, 3, 15   'Invert RGB
        .PutImageToVBMenu 70, 16, 3      'Posterize
        .PutImageToVBMenu 71, 17, 3      'Reduce Colors
        .PutImageToVBMenu 72, 19, 3      'Count Colors
        
        'Filters Menu
        .PutImageToVBMenu 73, 0, 4       'Fade Last
        .PutImageToVBMenu 74, 2, 4       'Artistic
            '--> Artistic sub-menu
            .PutImageToVBMenu 83, 0, 4, 2   'Antique (Sepia)
            .PutImageToVBMenu 84, 1, 4, 2   'Comic Book
            .PutImageToVBMenu 85, 2, 4, 2   'Mosaic
            .PutImageToVBMenu 86, 3, 4, 2   'Pencil
            .PutImageToVBMenu 87, 4, 4, 2   'Relief
        .PutImageToVBMenu 75, 3, 4       'Blur
            '--> Blur sub-menu
            .PutImageToVBMenu 88, 0, 4, 3   'Antialias
            .PutImageToVBMenu 89, 2, 4, 3   'Soften
            .PutImageToVBMenu 90, 3, 4, 3   'Soften More
            .PutImageToVBMenu 91, 4, 4, 3   'Blur
            .PutImageToVBMenu 92, 5, 4, 3   'Blur More
            .PutImageToVBMenu 93, 6, 4, 3   'Gaussian Blur
            .PutImageToVBMenu 94, 7, 4, 3   'Gaussian Blur More
            .PutImageToVBMenu 95, 9, 4, 3   'Grid Blur
        .PutImageToVBMenu 76, 4, 4       'Diffuse
            '--> Diffuse sub-menu
            .PutImageToVBMenu 76, 0, 4, 4   'Diffuse
            .PutImageToVBMenu 96, 1, 4, 4   'Diffuse More
            .PutImageToVBMenu 97, 3, 4, 4   'Diffuse (Custom)
        .PutImageToVBMenu 77, 5, 4       'Edges
            '--> Edges sub-menu
            .PutImageToVBMenu 100, 0, 4, 5  'Emboss / Engrave
            .PutImageToVBMenu 99, 1, 4, 5   'Enhance Edges
            .PutImageToVBMenu 77, 2, 4, 5   'Find Edges
        .PutImageToVBMenu 78, 6, 4       'Natural
            '--> Natural sub-menu
            .PutImageToVBMenu 107, 0, 4, 6  'Atmosphere
            .PutImageToVBMenu 108, 1, 4, 6  'Burn
            .PutImageToVBMenu 109, 2, 4, 6  'Fog
            .PutImageToVBMenu 110, 3, 4, 6  'Freeze
            .PutImageToVBMenu 111, 4, 4, 6  'Lava
            .PutImageToVBMenu 112, 5, 4, 6  'Ocean
            .PutImageToVBMenu 113, 6, 4, 6  'Rainbow
            .PutImageToVBMenu 114, 7, 4, 6  'Steel
            .PutImageToVBMenu 115, 8, 4, 6  'Water
        .PutImageToVBMenu 79, 7, 4       'Noise
            '--> Noise sub-menu
            .PutImageToVBMenu 116, 0, 4, 7  'Add Noise
            .PutImageToVBMenu 117, 2, 4, 7  'Despeckle
            .PutImageToVBMenu 118, 3, 4, 7  'Remove Orphan
        .PutImageToVBMenu 80, 8, 4       'Other
            '--> Other sub-menu
            .PutImageToVBMenu 126, 0, 4, 8  'Alien
            .PutImageToVBMenu 127, 1, 4, 8  'Blacklight
            .PutImageToVBMenu 128, 2, 4, 8  'Dream
            .PutImageToVBMenu 129, 3, 4, 8  'Radioactive
            .PutImageToVBMenu 130, 4, 4, 8  'Solarize
            .PutImageToVBMenu 131, 5, 4, 8  'Synthesize
            .PutImageToVBMenu 132, 6, 4, 8  'Tile
            .PutImageToVBMenu 133, 7, 4, 8  'Twins
            .PutImageToVBMenu 134, 8, 4, 8  'Vibrate
        .PutImageToVBMenu 81, 9, 4       'Rank
            '--> Rank sub-menu
            .PutImageToVBMenu 119, 0, 4, 9  'Dilate
            .PutImageToVBMenu 120, 1, 4, 9  'Erode
            .PutImageToVBMenu 121, 2, 4, 9  'Extreme
            .PutImageToVBMenu 122, 4, 4, 9  'Custom Rank
        .PutImageToVBMenu 82, 10, 4      'Sharpen
            '--> Sharpen sub-menu
            .PutImageToVBMenu 124, 0, 4, 10 'Unsharp
            .PutImageToVBMenu 82, 2, 4, 10  'Sharpen
            .PutImageToVBMenu 123, 3, 4, 10 'Sharpen More
        .PutImageToVBMenu 98, 12, 4      'Custom Filter
        
        'Macro Menu
        .PutImageToVBMenu 36, 0, 5     'Open Macro
        .PutImageToVBMenu 37, 2, 5     'Start Recording
        .PutImageToVBMenu 38, 3, 5     'Stop Recording
        
        'Window Menu
        .PutImageToVBMenu 29, 0, 6     'Fit on Screen
        .PutImageToVBMenu 28, 1, 6     'Fit Window to Image
        .PutImageToVBMenu 33, 3, 6     'Arrange Icons
        .PutImageToVBMenu 32, 4, 6     'Cascade
        .PutImageToVBMenu 30, 5, 6     'Tile Horizontally
        .PutImageToVBMenu 31, 6, 6     'Tile Vertically
        .PutImageToVBMenu 34, 8, 6     'Minimize All
        .PutImageToVBMenu 35, 9, 6     'Restore All
        
        'Help Menu
        .PutImageToVBMenu 40, 0, 7     'Donate
        .PutImageToVBMenu 41, 2, 7     'Check for updates
        .PutImageToVBMenu 25, 3, 7     'Visit the PhotoDemon website
        .PutImageToVBMenu 26, 4, 7     'Submit Feedback
        .PutImageToVBMenu 39, 5, 7     'Submit Bug
        .PutImageToVBMenu 27, 7, 7     'About PD
    
    End With
    
    'Finally, calculate where to place the "Clear MRU" menu item
    Dim numOfMRUFiles As Long
    numOfMRUFiles = MRU_ReturnCount()
    cMenuImage.PutImageToVBMenu 44, numOfMRUFiles + 1, 0, 1
    
End Sub

'When menu captions are changed, the associated images are lost.  This forces a reset.
' At present, it only address the Undo and Redo menu items.
Public Sub ResetMenuIcons()

    With cMenuImage
        .PutImageToVBMenu 12, 0, 1      'Undo
        .PutImageToVBMenu 13, 1, 1      'Redo
    End With
    
    'Dynamically calculate the position of the Clear Recent Files menu item
    Dim numOfMRUFiles As Long
    numOfMRUFiles = MRU_ReturnCount()
    cMenuImage.PutImageToVBMenu 44, numOfMRUFiles + 1, 0, 1
    
End Sub

'Create a custom form icon for an MDI child form (using the image stored in the back buffer of imgForm)
'Again, thanks to Paul Turcksin for the original draft of this code.
Public Sub CreateCustomFormIcon(ByRef imgForm As FormImage)

    'Generating an icon requires many variables; see below for specific comments on each one
    Dim BitmapData As Bitmap
    Dim iWidth As Long
    Dim iHeight As Long
    Dim srcDC As Long
    Dim oldSrcObj As Long
    Dim MonoDC As Long
    Dim MonoBmp As Long
    Dim oldMonoObj As Long
    Dim InvertDC As Long
    Dim InvertBmp As Long
    Dim oldInvertObj As Long
    Dim cBkColor As Long
    Dim maskClr As Long
    Dim icoInfo As ICONINFO
   
    'The icon can be drawn at any size, but 16x16 is how it will (typically) end up on the form.  I use 32x32 here
    ' in order to get slightly higher quality stretching during the resampling phase.
    Dim icoSize As Long
    icoSize = 32

    'Draw the form's backbuffer image to an in-memory picture
    Dim aspectRatio As Single
    aspectRatio = CSng(imgForm.BackBuffer.ScaleWidth) / CSng(imgForm.BackBuffer.ScaleHeight)
    
    'The target icon's width and height, x and y positioning
    Dim tIcoWidth As Single, tIcoHeight As Single, TX As Single, TY As Single
    
    'If the form is wider than it is tall...
    If aspectRatio > 1 Then
        
        'Determine proper sizes and (x, y) positioning so the icon will be centered
        tIcoWidth = icoSize
        tIcoHeight = icoSize * (1 / aspectRatio)
        TX = 0
        TY = (icoSize - tIcoHeight) / 2
        
    Else
    
        'Same thing, but with the math adjusted for images taller than they are wide
        tIcoHeight = icoSize
        tIcoWidth = icoSize * aspectRatio
        TY = 0
        TX = (icoSize - tIcoWidth) / 2
        
    End If
    
    'Clear out the current picture box
    imgForm.picIcon.Picture = LoadPicture("")
    
    'Resize the picture box that will receive the first draft of the icon
    imgForm.picIcon.Width = icoSize
    imgForm.picIcon.Height = icoSize
    
    'Because we'll be shrinking the image dramatically, set StretchBlt to use resampling
    SetStretchBltMode imgForm.picIcon.hDC, STRETCHBLT_HALFTONE
    
    'Render the bitmap that will ultimately be converted into an icon
    StretchBlt imgForm.picIcon.hDC, CLng(TX), CLng(TY), CLng(tIcoWidth), CLng(tIcoHeight), imgForm.BackBuffer.hDC, 0, 0, imgForm.BackBuffer.ScaleWidth, imgForm.BackBuffer.ScaleHeight, vbSrcCopy
    imgForm.picIcon.Picture = imgForm.picIcon.Image
   
    'Now that we have a first draft to work from, start preparing the data types required by the icon API calls
    GetObject imgForm.picIcon.Picture.Handle, Len(BitmapData), BitmapData

    With BitmapData
        iWidth = .bmWidth
        iHeight = .bmHeight
    End With
   
    'Create a copy of the original image; this will be used to generate a mask (necessary if the image isn't square-shaped)
    srcDC = CreateCompatibleDC(0&)
    oldSrcObj = SelectObject(srcDC, imgForm.picIcon.Picture.Handle)
   
    'If the image isn't square-shaped, the backcolor of the first draft image will need to be made transparent
    If tIcoWidth < icoSize Or tIcoHeight < icoSize Then
        maskClr = imgForm.picIcon.BackColor
    Else
        maskClr = 0
    End If
   
    'Generate two masks.  First, a monochrome mask.
    MonoDC = CreateCompatibleDC(0&)
    MonoBmp = CreateCompatibleBitmap(MonoDC, iWidth, iHeight)
    oldMonoObj = SelectObject(MonoDC, MonoBmp)
    cBkColor = GetBkColor(srcDC)
    SetBkColor srcDC, maskClr
    BitBlt MonoDC, 0, 0, iWidth, iHeight, srcDC, 0, 0, vbSrcCopy
    SetBkColor srcDC, cBkColor
    
    'Second, an AND mask
    InvertDC = CreateCompatibleDC(0&)
    InvertBmp = CreateCompatibleBitmap(imgForm.hDC, iWidth, iHeight)
    oldInvertObj = SelectObject(InvertDC, InvertBmp)
    BitBlt InvertDC, 0, 0, iWidth, iHeight, srcDC, 0, 0, vbSrcCopy
    SetBkColor InvertDC, vbBlack
    SetTextColor InvertDC, vbWhite
    BitBlt InvertDC, 0, 0, iWidth, iHeight, MonoDC, 0, 0, vbSrcAnd
  
    'We no longer need our copy of the original image, so free up that memory
    SelectObject srcDC, oldSrcObj
    DeleteDC srcDC
    'We can also free up the temporary DCs used to generate our two masks
    SelectObject MonoDC, oldMonoObj
    SelectObject InvertDC, oldInvertObj

    'Populate the icon header
    With icoInfo
      .fIcon = True
      .xHotspot = icoSize
      .yHotspot = icoSize
      .hbmMask = MonoBmp
      .hbmColor = InvertBmp
    End With
      
    'Render the icon to a handle
    Dim generatedIcon As Long
    generatedIcon = CreateIconIndirect(icoInfo)
    
    'Clear out our temporary masks (whose info are now embedded in the icon itself)
    DeleteObject icoInfo.hbmMask
    DeleteObject icoInfo.hbmColor
    DeleteDC MonoDC
    DeleteDC InvertDC
   
    'Use the API to assign this new icon to the specified MDI child form
    SendMessageLong imgForm.HWnd, &H80, 0, generatedIcon
    
    'Store this icon in our running list, so we can destroy it when the program is closed
    addIconToList generatedIcon

    'When an MDI child form is maximized, the icon is not updated properly.  This requires further investigation to solve.
    'If imgForm.WindowState = vbMaximized Then DoEvents
   
    'The chunk of code below will generate an actual icon object for use within VB.  I don't use this mechanism because
    ' VB will internally convert the icon to 256-colors before assigning it to the form. <sigh>  Rather than do that,
    ' I use an alternate API call above to assign the new icon in its transparent, full color glory.
    
    'Dim iGuid As Guid
    'With iGuid
    '   .Data1 = &H20400
    '   .Data4(0) = &HC0
    '   .Data4(7) = &H46
    'End With
    
    'Dim pDesc As pictDesc
    'With pDesc
    '   .cbSizeofStruct = Len(pDesc)
    '   .picType = PICTYPE_ICON
    '   .hImage = generatedIcon
    'End With
    
    'Dim icoObject As IPicture
    'OleCreatePictureIndirect pDesc, iGuid, 1, icoObject
    
    'imgForm.Icon = icoObject
   
End Sub

'Needs to be run only once, at the start of the program
Public Sub initializeIconHandler()
    numOfIcons = 0
End Sub

'Add another icon reference to the list
Private Sub addIconToList(ByVal hIcon As Long)

    ReDim Preserve iconHandles(0 To numOfIcons) As Long
    iconHandles(numOfIcons) = hIcon
    numOfIcons = numOfIcons + 1

End Sub

'Remove all icons generated since the program launched
Public Sub destroyAllIcons()

    Dim i As Long
    For i = 0 To numOfIcons - 1
        DestroyIcon iconHandles(i)
    Next i
    
    Erase iconHandles

End Sub
