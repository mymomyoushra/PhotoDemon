VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "pdFont"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
'***************************************************************************
'PhotoDemon Font Renderer
'Copyright 2013-2018 by Tanner Helland
'Created: 31/May/13
'Last updated: 25/August/17
'Last update: improve font creation performance
'
'While VB6 actually provides pretty good font support, PhotoDemon has some unique needs (as usual).  Chief among these
' are detailed handling over font positioning, rendering to arbitrary DCs, and managing fonts in a more speed-friendly
' way to maximize peformance.
'
'This class provides persistent storage for a variety of font parameters.  To maximize performance, it breaks down font
' management into three steps:
' 1) Set font parameters.  This can be done via a variety of support functions.  All attributes (minus color and
'     alignment, which are set separately) should be set before attempting to create the font.
' 2) Create font.  Do not do this until all settings are specified, because font creation is computationally expensive.
' 3) Attach font to DC.  Font color and text alignment should be set prior to this action.
' 4) (Optional) Render font to attached DC.  At present, ClearType antialiasing is assumed, but in the future it may
'     become user-settable.
'
'Obviously, this class relies heavily on WAPI.  Functions are documented to the best of my knowledge and ability.
'
'All source code in this file is licensed under a modified BSD license.  This means you may use the code in your own
' projects IF you provide attribution.  For more information, please visit http://photodemon.org/about/license/
'
'***************************************************************************

Option Explicit

Private Type LOGFONT
    lfHeight As Long
    lfWidth As Long
    lfEscapement As Long
    lfOrientation As Long
    lfWeight As Long
    lfItalic As Byte
    lfUnderline As Byte
    lfStrikeOut As Byte
    lfCharSet As Byte
    lfOutPrecision As Byte
    lfClipPrecision As Byte
    lfQuality As Byte
    lfPitchAndFamily As Byte
    lfFaceName(0 To 63) As Byte
End Type

'Previously we only suppored an ANSI charset, but now we want to default to the system value
Private Const ANSI_CHARSET = 0
Private Const DEFAULT_CHARSET = 1

'Pitch and family constants
Private Const DEFAULT_PITCH = 0
Private Const FIXED_PITCH = 1
Private Const VARIABLE_PITCH = 2
Private Const FF_DONTCARE = 0    'Any family works
Private Const FF_ROMAN = 16      'Variable stroke width + serifs
Private Const FF_SWISS = 32      'Variable stroke width + sans-serif
Private Const FF_MODERN = 48     'Constant stroke width + serif AND sans-serif
Private Const FF_SCRIPT = 64
Private Const FF_DECORATIVE = 80

'Constants for font weight (bold)
Private Const FW_DONTCARE As Long = 0
Private Const FW_THIN As Long = 100
Private Const FW_EXTRALIGHT As Long = 200
Private Const FW_ULTRALIGHT As Long = 200
Private Const FW_LIGHT As Long = 300
Private Const FW_NORMAL As Long = 400
Private Const FW_REGULAR As Long = 400
Private Const FW_MEDIUM As Long = 500
Private Const FW_SEMIBOLD As Long = 600
Private Const FW_DEMIBOLD As Long = 600
Private Const FW_BOLD As Long = 700
Private Const FW_EXTRABOLD As Long = 800
Private Const FW_ULTRABOLD As Long = 800
Private Const FW_HEAVY As Long = 900
Private Const FW_BLACK As Long = 900

'Font precision
Private Const OUT_DEFAULT_PRECIS As Long = 0
Private Const OUT_CHARACTER_PRECIS As Long = 2
Private Const OUT_DEVICE_PRECIS As Long = 5

'Font quality
Private Const DEFAULT_QUALITY As Long = 0
Private Const DRAFT_QUALITY As Long = 1
Private Const PROOF_QUALITY As Long = 2
Private Const NONANTIALIASED_QUALITY As Long = 3
Private Const ANTIALIASED_QUALITY As Long = 4
Private Const CLEARTYPE_QUALITY As Byte = 5

'Text alignment
Private Const TA_LEFT = 0
Private Const TA_RIGHT = 2
Private Const TA_CENTER = 6

Private Const TA_TOP = 0
Private Const TA_BOTTOM = 8
Private Const TA_BASELINE = 24

Private Const TA_UPDATECP = 1
Private Const TA_NOUPDATECP = 0

'Transparent font background
Private Const FONT_TRANSPARENT = &H3

'Formatting constants for DrawText
Private Const DT_TOP = &H0&
Private Const DT_LEFT = &H0&
Private Const DT_CENTER = &H1&
Private Const DT_RIGHT = &H2&
Private Const DT_VCENTER = &H4&
Private Const DT_BOTTOM = &H8&
Private Const DT_WORDBREAK = &H10&
Private Const DT_SINGLELINE = &H20&
Private Const DT_EXPANDTABS = &H40&
Private Const DT_TABSTOP = &H80&
Private Const DT_NOCLIP = &H100&
Private Const DT_EXTERNALLEADING = &H200&
Private Const DT_CALCRECT = &H400&
Private Const DT_NOPREFIX = &H800&
Private Const DT_INTERNAL = &H1000&
Private Const DT_EDITCONTROL = &H2000&
Private Const DT_PATH_ELLIPSIS = &H4000&
Private Const DT_END_ELLIPSIS = &H8000&
Private Const DT_MODIFYSTRING = &H10000
Private Const DT_RTLREADING = &H20000
Private Const DT_WORD_ELLIPSIS = &H40000

Private Declare Function CreateFontIndirect Lib "gdi32" Alias "CreateFontIndirectW" (ByVal ptrToLogFont As Long) As Long
Private Declare Function DeleteObject Lib "gdi32" (ByVal hObject As Long) As Long
Private Declare Function DrawText Lib "user32" Alias "DrawTextW" (ByVal hDC As Long, ByVal lpStr As Long, ByVal nCount As Long, ByRef lpRect As RECT, ByVal wFormat As Long) As Long
Private Declare Function ExtTextOut Lib "gdi32" Alias "ExtTextOutW" (ByVal hDC As Long, ByVal x As Long, ByVal y As Long, ByVal wOptions As Long, ByRef lpRect As RECT, ByVal lpStrPointer As Long, ByVal nCount As Long, ByRef lpDx As Long) As Long
Private Declare Function ExtTextOutNoRect Lib "gdi32" Alias "ExtTextOutW" (ByVal hDC As Long, ByVal x As Long, ByVal y As Long, ByVal wOptions As Long, ByVal fakeRectPointer As Long, ByVal lpStrPointer As Long, ByVal nCount As Long, ByRef lpDx As Long) As Long
Private Declare Function GetTextExtentPoint32 Lib "gdi32" Alias "GetTextExtentPoint32W" (ByVal hDC As Long, ByVal lpStrPointer As Long, ByVal cbString As Long, ByRef lpSize As POINTAPI) As Long
Private Declare Function SelectObject Lib "gdi32" (ByVal hDC As Long, ByVal hObject As Long) As Long
Private Declare Function SetBkMode Lib "gdi32" (ByVal hDC As Long, ByVal nBkMode As Long) As Long
Private Declare Function SetTextAlign Lib "gdi32" (ByVal hDC As Long, ByVal wFlags As Long) As Long
Private Declare Function SetTextColor Lib "gdi32" (ByVal hDC As Long, ByVal crColor As Long) As Long

Private Declare Sub CopyMemoryStrict Lib "kernel32" Alias "RtlMoveMemory" (ByVal lpDst As Long, ByVal lpSrc As Long, ByVal byteLength As Long)
Private Declare Sub FillMemory Lib "kernel32" Alias "RtlFillMemory" (ByVal dstPointer As Long, ByVal Length As Long, ByVal Fill As Byte)

Private Declare Function GetClientRect Lib "user32" (ByVal hndWindow As Long, ByRef lpRect As winRect) As Long
Private Declare Function WindowFromDC Lib "user32" (ByVal hDC As Long) As Long

'Used to track the created font
Private curFont As Long, oldFont As Long

'Used to track the DC we are rendering to
Private curDC As Long

'Current text alignment (as an API constant, not a VB one)
Private curTextAlignment As Long

'Current font color
Private fontColor As Long

'This LOGFONT object stores all current settings for the font
Private m_currentLogFont As LOGFONT

'Certain settings have to be modified before placing them inside a LOGFONT struct.  We store local copies of these values in VB-friendly formats,
' which simplies the process of checking these properties prior to replacing them.
Private m_origFontFace As String
Private m_origFontSize As Single
Private m_origFontBold As Boolean
Private m_origFontItalic As Boolean

'If the user wants to call DrawText manually, they can use this function.  Note that hDC is *not* part of the call, as it's assumed
' the caller has already selected this object into the relevant DC!
Friend Function DrawTextWrapper(ByVal lpStr As Long, ByVal nCount As Long, ByRef lpRect As RECT, ByVal wFormat As Long) As Long
    DrawText curDC, lpStr, nCount, lpRect, wFormat
End Function

'This function draws horizontally and vertically centered text onto the attached DC, and it does it without modifying any of the current
' font settings (including alignment).  It is designed for one-off renderings of centered text.
Friend Sub DrawCenteredText(ByRef srcString As String, Optional ByVal customWidth As Long = -1, Optional ByVal customHeight As Long = -1)

    'Because DCs are dimensionless abstractions, we need to retrieve the attached window and use it to calculate the output rect.
    ' (Note that this does not work when rendering to a windowless DC, like a DIB.)
    Dim winClientRect As winRect
    GetClientRect WindowFromDC(curDC), winClientRect
    
    'Use the client rectangle to determine a width and height midpoint for the target DC
    Dim halfDCWidth As Long, halfDCHeight As Long
    If winClientRect.x2 = 0 Then
        halfDCWidth = customWidth \ 2
        halfDCHeight = customHeight \ 2
    Else
        halfDCWidth = winClientRect.x2 \ 2
        halfDCHeight = winClientRect.y2 \ 2
    End If
    
    'Create a bounding rect for the text
    Dim tmpRect As RECT
    
    tmpRect.Left = halfDCWidth
    tmpRect.Right = tmpRect.Left + GetWidthOfString(srcString)
    tmpRect.Top = halfDCHeight
    tmpRect.Bottom = tmpRect.Top + GetHeightOfWordwrapString(srcString, GetWidthOfString(srcString))
    
    'DrawText handles the actual rendering
    DrawText curDC, StrPtr(srcString), Len(srcString), tmpRect, DT_WORDBREAK Or DT_NOCLIP
    
End Sub

'This function draws horizontally and vertically centered text within a specified rect, and it does it without modifying any of the current
' font settings (including alignment).  It is designed for one-off renderings of centered text.
Friend Sub DrawCenteredTextToRect(ByVal srcString As String, ByRef dstRect As RECT, Optional ByVal centerVertically As Boolean = False)
    
    Dim dtFlags As Long
    dtFlags = DT_CENTER
    
    If centerVertically Then
        dtFlags = dtFlags Or DT_VCENTER Or DT_SINGLELINE
    Else
        dtFlags = dtFlags Or DT_WORDBREAK
    End If
    
    'Rendering this style of text is pretty damn easy
    DrawText curDC, StrPtr(srcString), Len(srcString), dstRect, dtFlags
    
End Sub

'If the font has already been created and set to a DC, this function can be used to quickly render text (because no
' additional parameters have to be set).  Note that it only works for left-aligned text, as no contraining rect is used.
Friend Sub FastRenderText(ByVal dstX As Long, ByVal dstY As Long, ByRef srcString As String)
    ExtTextOutNoRect curDC, dstX, dstY, 0, ByVal 0&, StrPtr(srcString), Len(srcString), ByVal 0&
End Sub

'A roughly identical function to fastRenderText, above, but with a constraining rect
Friend Sub FastRenderTextWithClipping(ByVal dstX As Long, ByVal dstY As Long, ByVal dstWidth As Long, ByVal dstHeight As Long, ByVal srcString As String, Optional ByVal useEllipses As Boolean = True, Optional ByVal centerVertically As Boolean = False, Optional ByVal treatAmpAsControlChar As Boolean = True)
    
    'IMPORTANT NOTE!  Per MSDN, the following caveat is made regarding the source string pointer:
    '  "A pointer to the string that specifies the text to be drawn. If the nCount parameter is -1, the string must
    '   be null-terminated.  If uFormat includes DT_MODIFYSTRING, the function could add up to four additional characters
    '   to this string. The buffer containing the string should be large enough to accommodate these extra characters."
    '
    'Because the string may be modified to fit within the clipping boundaries, we need to extend the string array by four chars.
    Dim srcStringLen As Long
    srcStringLen = Len(srcString)
    
    If useEllipses Then srcString = srcString & String$(4, ChrW(0))
    
    Dim tmpRect As RECT
    tmpRect.Left = dstX
    tmpRect.Top = dstY
    tmpRect.Right = dstX + dstWidth
    tmpRect.Bottom = dstY + dstHeight
    
    'If the text is going to extend past the target rect, draw it with ellipses.  Note that we deliberately misrepresent the
    ' actual length of the string in that case.  This is on purpose, to account for the DT_MODIFYSTRING flag above.  (If the
    ' string is too long to fit inside the clipping rect, DrawText may choose to extend the character count of the string.
    ' As such, we pass only the currently relevant length of the string, without our added null chars, and DrawText can use
    ' the extra buffer space as necessary.)
    Dim dtFlags As Long
    If centerVertically Then dtFlags = DT_VCENTER Else dtFlags = DT_TOP
    If (Not treatAmpAsControlChar) Then dtFlags = dtFlags Or DT_NOPREFIX
    
    Const ELLIPSES_METHOD As Long = DT_WORD_ELLIPSIS
    
    Select Case curTextAlignment
        
        Case TA_LEFT
            If useEllipses Then
                dtFlags = dtFlags Or ELLIPSES_METHOD Or DT_MODIFYSTRING Or DT_LEFT
            Else
                dtFlags = dtFlags Or DT_SINGLELINE Or DT_LEFT Or DT_NOCLIP
            End If
            
        Case TA_RIGHT
            If useEllipses Then
                dtFlags = dtFlags Or ELLIPSES_METHOD Or DT_MODIFYSTRING Or DT_RIGHT
            Else
                dtFlags = dtFlags Or DT_SINGLELINE Or DT_RIGHT Or DT_NOCLIP
            End If
            
        Case TA_CENTER
            If useEllipses Then
                dtFlags = dtFlags Or ELLIPSES_METHOD Or DT_MODIFYSTRING Or DT_CENTER
            Else
                dtFlags = dtFlags Or DT_SINGLELINE Or DT_CENTER Or DT_NOCLIP
            End If
        
    End Select
    
    DrawText curDC, StrPtr(srcString), srcStringLen, tmpRect, dtFlags
    
End Sub

'A roughly identical function to fastRenderText, above, but with a constraining rect and expansion to multiple lines as necessary
Friend Sub FastRenderMultilineTextWithClipping(ByVal dstX As Long, ByVal dstY As Long, ByVal dstWidth As Long, ByVal dstHeight As Long, ByVal srcString As String, Optional ByVal centerVertically As Boolean = False, Optional ByVal preProcessAmps As Boolean = True)
    
    'Multiline text does not need ellipses, so this function is actually simpler than its single-line counterpart
    Dim srcStringLen As Long
    srcStringLen = Len(srcString)
    
    Dim tmpRect As RECT
    tmpRect.Left = dstX
    tmpRect.Top = dstY
    tmpRect.Right = dstX + dstWidth
    tmpRect.Bottom = dstY + dstHeight
    
    'When rendering multiline text, we want top-alignment by default (vertical centering is handled manually).
    ' We must also specify word-breaking, and the caller can control whether ampersands are treated as control chars.
    Dim dtFlags As Long
    dtFlags = DT_WORDBREAK Or DT_TOP
    If (Not preProcessAmps) Then dtFlags = dtFlags Or DT_NOPREFIX
    
    'Vertical centering isn't automatic when multiline text is used.  Instead, we need to manually calculate centering.
    If centerVertically Then
        Dim tmpHeight As Single
        tmpHeight = Me.GetHeightOfWordwrapString(srcString, dstWidth)
        tmpRect.Top = dstY + (dstHeight - tmpHeight) \ 2
    End If
    
    Select Case curTextAlignment
        
        Case TA_LEFT
            dtFlags = dtFlags Or DT_LEFT
            
        Case TA_RIGHT
            dtFlags = dtFlags Or DT_RIGHT
            
        Case TA_CENTER
            dtFlags = dtFlags Or DT_CENTER
        
    End Select
    
    DrawText curDC, StrPtr(srcString), srcStringLen, tmpRect, dtFlags
    
End Sub

'A roughly identical function to fastRenderText, above, but with support for linebreaks
Friend Sub FastRenderMultilineText(ByVal dstX As Long, ByVal dstY As Long, ByRef srcString As String)
        
    'Find the bounding rect of the text
    Dim tmpRect As RECT
    
    'Modify the rect to account for the specified offset
    tmpRect.Left = dstX
    tmpRect.Top = dstY
    tmpRect.Right = dstX + GetWidthOfString(srcString)
    tmpRect.Bottom = dstY + GetHeightOfWordwrapString(srcString, GetWidthOfString(srcString))
    
    'If the text is going to extend past the target rect, draw it with ellipses
    DrawText curDC, StrPtr(srcString), Len(srcString), tmpRect, DT_LEFT Or DT_TOP Or DT_WORDBREAK
    
End Sub

'Select the current font and other text settings into the specified DC.  Ideally, this should only be done when absolutely
' necessary to keep speed high.  (Also, note the DC so we can do fast font rendering later.)
Friend Sub AttachToDC(ByVal targetDC As Long)
    
    If (targetDC = 0) Then Debug.Print "WARNING!  pdFont.AttachToDC() was called with targetDC = 0.  Fix this!"
    If (curDC <> 0) Then Debug.Print "WARNING!  pdFont.AttachToDC() was called, but this font is already selected into a DC!"
    If (targetDC = curDC) Then Debug.Print "WARNING!  pdFont.AttachToDC() was called, but the specified DC is already the current DC!"
    
    'Set the font
    If (targetDC <> curDC) Then
        oldFont = SelectObject(targetDC, curFont)
        curDC = targetDC
    End If
    
    'Set other font parameters
    SetTextColor targetDC, fontColor
    SetTextAlign targetDC, curTextAlignment
    
    'Enable transparent font rendering
    SetBkMode targetDC, FONT_TRANSPARENT
    
End Sub

'If we want to detach this font from its current DC, use this call
Friend Sub ReleaseFromDC()
    If (curDC <> 0) Then
        SelectObject curDC, oldFont
        curDC = 0
    End If
End Sub

'Create the font object on-demand
Friend Function CreateFontObject() As Boolean

    'If a font has already been created, delete it now
    If (curDC <> 0) Then Me.ReleaseFromDC
    If (curFont <> 0) Then Me.DeleteCurrentFont
    
    curFont = CreateFontIndirect(VarPtr(m_currentLogFont))
    CreateFontObject = (curFont <> 0)
    
    'Inside debug mode, increase a global font counter.  This is extremely helpful for finding font leaks
    If CreateFontObject Then g_FontsCreated = g_FontsCreated + 1
    
End Function

'Shortcut function to set all font properties at once
Friend Sub SetFontPropsAllAtOnce(ByRef newFace As String, ByVal newFontSize As Single, ByVal newBold As Boolean, ByVal newItalic As Boolean, ByVal newUnderline As Boolean)
    
    'First, cache all persistent settings
    m_origFontFace = newFace
    m_origFontSize = newFontSize
    m_origFontBold = newBold
    m_origFontItalic = newItalic
    
    'Next, translate these into actual LOGFONT properties
    
    'Make sure we have a trailing null char before copying the font name into place
    If (Len(newFace) < 32) Then
        FillMemory VarPtr(m_currentLogFont.lfFaceName(0)), 64, 0
        CopyMemoryStrict VarPtr(m_currentLogFont.lfFaceName(0)), StrPtr(newFace), Len(newFace) * 2
    Else
        CopyMemoryStrict VarPtr(m_currentLogFont.lfFaceName(0)), StrPtr(newFace), 64
    End If
    
    m_currentLogFont.lfHeight = Fonts.ConvertToGDIFontSize(newFontSize)
    If newBold Then m_currentLogFont.lfWeight = FW_BOLD Else m_currentLogFont.lfWeight = FW_NORMAL
    m_currentLogFont.lfItalic = -1 * newItalic
    m_currentLogFont.lfUnderline = -1 * newUnderline
    
End Sub

Friend Function GetFontBold() As Boolean
    GetFontBold = m_origFontBold
End Function

Friend Sub SetFontBold(ByVal newBold As Boolean)
    m_origFontBold = newBold
    If newBold Then
        m_currentLogFont.lfWeight = FW_BOLD
    Else
        m_currentLogFont.lfWeight = FW_NORMAL
    End If
End Sub

Friend Sub SetFontColor(ByVal newFontColor As Long)
    
    fontColor = newFontColor
    
    'If we are currently selected into a DC, update the color immediately; otherwise, the color will be applied upon DC selection
    If (curDC <> 0) Then SetTextColor curDC, fontColor
    
End Sub

Friend Function GetFontFace() As String
    GetFontFace = m_origFontFace
End Function

Friend Sub SetFontFace(ByRef newFace As String)
    
    m_origFontFace = newFace
    
    'Make sure we have a trailing null char before copying the font name into place
    If (Len(newFace) < 32) Then
        FillMemory VarPtr(m_currentLogFont.lfFaceName(0)), 64, 0
        CopyMemoryStrict VarPtr(m_currentLogFont.lfFaceName(0)), StrPtr(newFace), Len(newFace) * 2
    Else
        CopyMemoryStrict VarPtr(m_currentLogFont.lfFaceName(0)), StrPtr(newFace), 64
    End If
    
End Sub

Friend Function GetFontItalic() As Boolean
    GetFontItalic = m_origFontItalic
End Function

Friend Sub SetFontItalic(ByVal newItalic As Boolean)
    m_origFontItalic = newItalic
    m_currentLogFont.lfItalic = -1 * newItalic
End Sub

Friend Function GetFontSize() As Single
    GetFontSize = m_origFontSize
End Function

Friend Sub SetFontSize(ByVal newFontSize As Single)
    m_origFontSize = newFontSize
    m_currentLogFont.lfHeight = Fonts.ConvertToGDIFontSize(newFontSize)
End Sub

Friend Sub SetFontStrikeout(ByVal newStrikeout As Boolean)
    m_currentLogFont.lfStrikeOut = -1 * newStrikeout
End Sub

Friend Sub SetFontUnderline(ByVal newUnderline As Boolean)
    m_currentLogFont.lfUnderline = -1 * newUnderline
End Sub

Friend Function GetFontUnderline() As Boolean
    GetFontUnderline = (m_currentLogFont.lfUnderline * -1)
End Function

Friend Sub SetTextAlignment(ByVal newAlignment As AlignmentConstants)
    
    Select Case newAlignment
        Case vbLeftJustify
            curTextAlignment = TA_LEFT
        Case vbCenter
            curTextAlignment = TA_CENTER
        Case vbRightJustify
            curTextAlignment = TA_RIGHT
    End Select
    
    'All alignment settings are handled via flags to DrawText.  For DrawText flags to work, the alignment of the current DC must be
    ' set to TA_LEFT, TA_TOP, and TA_NOUPDATECP (see http://msdn.microsoft.com/en-us/library/dd162498.aspx)
    If (curDC <> 0) Then SetTextAlign curDC, TA_LEFT Or TA_TOP Or TA_NOUPDATECP
    
End Sub

'Return the width (and below, height) of a string, in pixels.  This action REQUIRES that a DC be currently set for this
' object, as the DC's font settings are used to determine the string's dimensions.
Friend Function GetWidthOfString(ByRef srcString As String) As Long
    
    Dim txtSize As POINTAPI
    
    'If we're not currently selected into a DC, silently plug in a temporary DC
    Dim targetDC As Long, tmpDCActive As Boolean
    If (curDC = 0) Then
        tmpDCActive = True
        targetDC = GDI.GetMemoryDC()
        AttachToDC targetDC
    Else
        targetDC = curDC
    End If
    
    'Retrieve the string's dimensions
    GetTextExtentPoint32 targetDC, StrPtr(srcString), Len(srcString), txtSize
    GetWidthOfString = txtSize.x
    
    'Release the temporary DC, as necessary
    If tmpDCActive Then
        ReleaseFromDC
        GDI.FreeMemoryDC targetDC
    End If
    
End Function

'With the current font settings, find the height of either a single-line string, or a word-wrapped string.
' For convenience, I've separated these into separate functions, as the underlying logic is actually quite different.
Friend Function GetHeightOfString(ByRef srcString As String) As Long
    
    Dim txtSize As POINTAPI
    
    'If we're not currently selected into a DC, silently plug in a temporary DC
    Dim targetDC As Long, tmpDCActive As Boolean
    If curDC = 0 Then
        tmpDCActive = True
        targetDC = GDI.GetMemoryDC()
        AttachToDC targetDC
    Else
        targetDC = curDC
    End If
    
    'Retrieve the string's dimensions
    GetTextExtentPoint32 targetDC, StrPtr(srcString), Len(srcString), txtSize
    GetHeightOfString = txtSize.y
    
    'Release the temporary DC, as necessary
    If tmpDCActive Then
        ReleaseFromDC
        GDI.FreeMemoryDC targetDC
    End If
    
End Function

Friend Function GetHeightOfWordwrapString(ByRef srcString As String, ByVal strWidth As Long) As Long

    Dim tmpRect As RECT
    tmpRect.Left = 0
    tmpRect.Top = 0
    tmpRect.Bottom = 0
    tmpRect.Right = strWidth - 1
    
    'If we're not currently selected into a DC, silently plug in a temporary DC
    Dim targetDC As Long, tmpDCActive As Boolean
    If curDC = 0 Then
        tmpDCActive = True
        targetDC = GDI.GetMemoryDC()
        AttachToDC targetDC
    Else
        targetDC = curDC
    End If
    
    'Retrieve the string's dimensions
    DrawText targetDC, StrPtr(srcString), Len(srcString), tmpRect, DT_LEFT Or DT_CALCRECT Or DT_WORDBREAK Or DT_EXTERNALLEADING Or DT_NOPREFIX Or DT_TOP
    GetHeightOfWordwrapString = tmpRect.Bottom
    
    'Release the temporary DC, as necessary
    If tmpDCActive Then
        ReleaseFromDC
        GDI.FreeMemoryDC targetDC
    End If

End Function

'This is just a thin wrapper to DrawText+DT_CALCRECT.  Note the (many) caveats, per MSDN:
' "Determines the width and height of the rectangle. If there are multiple lines of text, DrawText uses the
'  width of the rectangle pointed to by the lpRect parameter and extends the base of the rectangle to bound
'  the last line of text. If the largest word is wider than the rectangle, the width is expanded. If the text
'  is less than the width of the rectangle, the width is reduced. If there is only one line of text, DrawText
'  modifies the right side of the rectangle so that it bounds the last character in the line. In either case,
'  DrawText returns the height of the formatted text but does not draw the text."
Friend Function GetBoundaryRectOfMultilineString(ByVal srcString As String, ByVal maxAllowedWidth As Long, ByRef dstRect As RectL, Optional ByVal turnOffPrefixHandling As Boolean = False) As Boolean

    Dim tmpRect As RECT
    tmpRect.Left = 0
    tmpRect.Top = 0
    tmpRect.Bottom = 0
    tmpRect.Right = maxAllowedWidth - 1
    
    'If we're not currently selected into a DC, silently plug in a temporary DC
    Dim targetDC As Long, tmpDCActive As Boolean
    If curDC = 0 Then
        tmpDCActive = True
        targetDC = GDI.GetMemoryDC()
        AttachToDC targetDC
    Else
        targetDC = curDC
    End If
    
    'Create the magical combination of DrawText flags
    Dim dtFlags As Long
    dtFlags = DT_LEFT Or DT_CALCRECT Or DT_WORDBREAK Or DT_EXTERNALLEADING Or DT_TOP
    If turnOffPrefixHandling Then dtFlags = dtFlags Or DT_NOPREFIX
    
    'Retrieve the string's dimensions
    GetBoundaryRectOfMultilineString = (DrawText(targetDC, StrPtr(srcString), Len(srcString), tmpRect, dtFlags) <> 0)
    
    With dstRect
        .Left = tmpRect.Left
        .Top = tmpRect.Top
        .Right = tmpRect.Right
        .Bottom = tmpRect.Bottom
    End With
    
    'Release the temporary DC, as necessary
    If tmpDCActive Then
        ReleaseFromDC
        GDI.FreeMemoryDC targetDC
    End If

End Function

Private Sub Class_Initialize()
    
    'When the class is initialized, set up a default PhotoDemon font.  Face is automatically set per
    ' the current OS, so external functions do not need to set this manually.
    With m_currentLogFont
    
        .lfHeight = Fonts.ConvertToGDIFontSize(11#)
        .lfWidth = 0        'This will automatically set the width based on the height
        
        .lfEscapement = 0   'Used for rotation; not utilized at present
        .lfOrientation = 0  'An additional rotation parameter; not utilized at present
        
        .lfWeight = FW_REGULAR
        
        .lfItalic = False
        .lfUnderline = False
        .lfStrikeOut = False
        
        .lfCharSet = DEFAULT_CHARSET
        
        .lfOutPrecision = 0
        .lfClipPrecision = 0
        .lfQuality = CLEARTYPE_QUALITY
        
        'Ideally, we should allow the caller to specify pitch and family requests.  I may add this in the future.
        ' For PD's purposes, however, we want to fallback to a variable width, non-serifed font if (for some reason)
        ' Segoe and Tahoma aren't available on the target machine.
        .lfPitchAndFamily = VARIABLE_PITCH Or FF_SWISS
        
        If pdMain.IsProgramRunning() Then
            m_origFontFace = Fonts.GetUIFontName()
        Else
            m_origFontFace = "Tahoma"
        End If
        
        'Make sure we have a trailing null char before copying the font name into place
        If (Len(m_origFontFace) < 32) Then
            FillMemory VarPtr(m_currentLogFont.lfFaceName(0)), 64, 0
            CopyMemoryStrict VarPtr(m_currentLogFont.lfFaceName(0)), StrPtr(m_origFontFace), Len(m_origFontFace) * 2
        Else
            CopyMemoryStrict VarPtr(m_currentLogFont.lfFaceName(0)), StrPtr(m_origFontFace), 64
        End If
        
    End With
    
    curFont = 0
    curDC = 0
        
    m_origFontBold = False
    m_origFontItalic = False
    m_origFontSize = 11
    
    fontColor = 0
    curTextAlignment = TA_LEFT
        
End Sub

'Like most things, it's ideal if the caller frees resources when they no longer need them, but this class should successfully
' release all attached GDI objects regardless of caller behavior.
Private Sub Class_Terminate()
    If curDC <> 0 Then ReleaseFromDC
    DeleteCurrentFont
End Sub

Friend Function HasFontBeenCreated() As Boolean
    HasFontBeenCreated = (curFont <> 0)
End Function

Friend Function GetAttachedDC() As Long
    GetAttachedDC = curDC
End Function

Friend Function GetFontHandle() As Long
    GetFontHandle = curFont
End Function

Friend Sub DeleteCurrentFont()
    
    'If a font was created, delete it now
    If (curFont <> 0) Then
        
        'If the font is inside a DC, remove it (otherwise we can't delete it)
        If (curDC <> 0) Then
            pdDebug.LogAction "HEY!  Font was not removed from DC - please do that before deleting it!"
            ReleaseFromDC
        End If
        
        If (DeleteObject(curFont) = 0) Then
            pdDebug.LogAction "WARNING! Could not delete font resource - is it selected into a DC??"
        Else
            g_FontsDestroyed = g_FontsDestroyed + 1
        End If
        
        curFont = 0
        
    End If
    
End Sub

'Quick and dirty function for checking font existence.  Does not use API at present, so fonts with Unicode names won't return correct results.
' I haven't done a check, but I expect this to be faster than enum-ing all available fonts and looking for a match...
Friend Function DoesFontExist(ByVal fontNameToCheck As String, Optional ByRef fontSubstitute As String, Optional ByRef nearestFontSize As Long = 8) As Boolean

    'I don't know if this function will throw errors, but better safe than sorry...
    On Error Resume Next
    
    'Create a temporary font object to test name support
    Dim tmpFont As StdFont
    Set tmpFont = New StdFont
    
    'Copy name and size (if any)
    tmpFont.Name = fontNameToCheck
    tmpFont.Size = nearestFontSize
    
    'See if the font object has the same name.  Windows will automatically substitute a new font if the requested one can't be found.
    DoesFontExist = Strings.StringsEqual(fontNameToCheck, tmpFont.Name, True)
    
    'Not sure if helpful, but return the replacement font name and nearest supported size
    fontSubstitute = tmpFont.Name
    nearestFontSize = tmpFont.Size
    
End Function

'Given a desired width (in pixels) and a source string, search for the largest font size that allows said string to fit within that width.
' Word-wrapping is not used, by design, as it's assumed the caller already tried word-wrapping as a solution.
'
'RETURNS: largest font size that fits the string into the desired width.  (7 is the smallest size this function will return, FYI.)
Friend Function GetMaxFontSizeToFitStringWidth(ByRef srcString As String, ByVal desiredWidth As Long, Optional ByVal startingFontSize As Long = 10) As Single
    
    'Start by determining a targetDC.  A temporary DC will be created and used, as necessary.
    Dim targetDC As Long, backupDC As Long
    backupDC = curDC
    
    If (curDC = 0) Then
        targetDC = GDI.GetMemoryDC()
    Else
        ReleaseFromDC
        targetDC = backupDC
    End If
    
    'Make a backup of the current font size, if any
    Dim backupFontSize As Single
    backupFontSize = m_origFontSize
    
    'Create the font anew, using the default string size we were passed
    If (startingFontSize <> m_origFontSize) Or (curFont = 0) Then
        If (curFont <> 0) Then DeleteCurrentFont
        m_origFontSize = startingFontSize
        SetFontSize m_origFontSize
        CreateFontObject
    End If
    
    'Select the font into the target DC
    AttachToDC targetDC
    
    'Measure the font relative to the current control size
    Dim stringWidth As Long
    stringWidth = GetWidthOfString(srcString)
    
    'If the string does not fit within the control size, shrink the font accordingly.
    Do While (stringWidth > desiredWidth) And (m_origFontSize >= 7!)
        
        'Shrink the font size
        m_origFontSize = m_origFontSize - 0.5
        
        'Recreate the font
        ReleaseFromDC
        DeleteCurrentFont
        Me.SetFontSize m_origFontSize
        Me.CreateFontObject
        Me.AttachToDC targetDC
        
        'Measure the new size
        stringWidth = GetWidthOfString(srcString)
        
    Loop
    
    'By this point, m_origFontSize represents the valid size.  Return it.
    GetMaxFontSizeToFitStringWidth = m_origFontSize
    
    'Before exiting, restore any parameters we changed
    ReleaseFromDC
    
    If (m_origFontSize <> backupFontSize) Then
        DeleteCurrentFont
        SetFontSize backupFontSize
        CreateFontObject
    End If
    
    'If we created a temporary DC, free it now
    If (targetDC <> backupDC) Then
        GDI.FreeMemoryDC targetDC
    
    'Conversely, if we were originally selected into a DC, restore that DC now
    Else
        If (backupDC <> 0) Then AttachToDC backupDC
    End If
    
End Function

'Given a desired width and height (in pixels) and a source string, search for the largest font size that allows said string to fit within
' that rect.  Word-wrapping will be used.
'
'RETURNS: largest font size that fits the string into the desired width.  (7 is the smallest size this function will return, FYI.)
Friend Function GetMaxFontSizeToFitWordWrap(ByRef srcString As String, ByVal desiredWidth As Long, ByVal desiredHeight As Long, Optional ByVal startingFontSize As Long = 10) As Single
    
    'Start by determining a targetDC.  A temporary DC will be created and used, as necessary.
    Dim targetDC As Long, backupDC As Long
    backupDC = curDC
    
    If (curDC = 0) Then
        targetDC = GDI.GetMemoryDC()
    Else
        ReleaseFromDC
        targetDC = backupDC
    End If
    
    'Make a backup of the current font size, if any
    Dim backupFontSize As Single
    backupFontSize = m_origFontSize
    
    'Create the font anew, using the default string size we were passed
    ReleaseFromDC
    m_origFontSize = startingFontSize
    SetFontSize m_origFontSize
    CreateFontObject
    AttachToDC targetDC
    
    'Measure the font relative to the current control size
    Dim stringHeight As Long
    stringHeight = GetHeightOfWordwrapString(srcString, desiredWidth)
    
    'If the string does not fit within the control size, shrink the font accordingly.
    Do While (stringHeight > desiredHeight) And (m_origFontSize >= 7)
        
        'Shrink the font size
        m_origFontSize = m_origFontSize - 0.5
        
        'Recreate the font
        ReleaseFromDC
        SetFontSize m_origFontSize
        CreateFontObject
        AttachToDC targetDC
        
        'Measure the new size
        stringHeight = GetHeightOfWordwrapString(srcString, desiredWidth)
        
    Loop
    
    'By this point, m_origFontSize represents the valid size.  Return it.
    GetMaxFontSizeToFitWordWrap = m_origFontSize
    
    'Before exiting, restore any parameters we changed
    ReleaseFromDC
    
    If (m_origFontSize <> backupFontSize) Then
        SetFontSize backupFontSize
        CreateFontObject
    End If
    
    'If we created a temporary DC, free it now
    If (targetDC <> backupDC) Then
        GDI.FreeMemoryDC targetDC
    
    'Conversely, if we were originally selected into a DC, restore that DC now
    Else
        If (backupDC <> 0) Then AttachToDC backupDC
    End If
    
End Function
