Attribute VB_Name = "GDI"
'***************************************************************************
'GDI interop manager
'Copyright 2001-2016 by Tanner Helland
'Created: 03/April/2001
'Last updated: 20/June/16
'Last update: split the GDI parts of the massive Drawing module into this dedicated module
'
'Like any Windows application, PD frequently interacts with GDI.  This module tries to manage the messiest bits
' of interop code.
'
'All source code in this file is licensed under a modified BSD license. This means you may use the code in your own
' projects IF you provide attribution. For more information, please visit http://photodemon.org/about/license/
'
'***************************************************************************

Option Explicit

'For clarity, GDI's "BITMAP" type is referred to as "GDI_BITMAP" throughout PD.
Public Type GDI_Bitmap
    Type As Long
    Width As Long
    Height As Long
    WidthBytes As Long
    Planes As Integer
    BitsPerPixel As Integer
    Bits As Long
End Type

Private Enum GDI_PenStyle
    PS_SOLID = 0
    PS_DASH = 1
    PS_DOT = 2
    PS_DASHDOT = 3
    PS_DASHDOTDOT = 4
End Enum

#If False Then
    Private Const PS_SOLID = 0, PS_DASH = 1, PS_DOT = 2, PS_DASHDOT = 3, PS_DASHDOTDOT = 4
#End If

Private Const GDI_OBJ_BITMAP As Long = 7&
Private Declare Function CreateCompatibleDC Lib "gdi32" (ByVal hDC As Long) As Long
Private Declare Function CreatePen Lib "gdi32" (ByVal nPenStyle As GDI_PenStyle, ByVal nWidth As Long, ByVal srcColor As Long) As Long
Private Declare Function CreateSolidBrush Lib "gdi32" (ByVal srcColor As Long) As Long
Private Declare Function DeleteDC Lib "gdi32" (ByVal hDC As Long) As Long
Private Declare Function DeleteObject Lib "gdi32" (ByVal hObject As Long) As Long
Private Declare Function GdiFlush Lib "gdi32" () As Long
Private Declare Function GetCurrentObject Lib "gdi32" (ByVal srcDC As Long, ByVal srcObjectType As Long) As Long
Private Declare Function GetObject Lib "gdi32" Alias "GetObjectW" (ByVal hObject As Long, ByVal sizeOfBuffer As Long, ByVal ptrToBuffer As Long) As Long
Private Declare Function LineTo Lib "gdi32" (ByVal hDC As Long, ByVal x As Long, ByVal y As Long) As Long
Private Declare Function MoveToEx Lib "gdi32" (ByVal hDC As Long, ByVal x As Long, ByVal y As Long, ByVal pointerToRectOfOldCoords As Long) As Long
Private Declare Function Rectangle Lib "gdi32" (ByVal hDC As Long, ByVal x1 As Long, ByVal y1 As Long, ByVal x2 As Long, ByVal y2 As Long) As Long
Private Declare Function SelectObject Lib "gdi32" (ByVal hDC As Long, ByVal hObject As Long) As Long

'Convenience wrappers that return pass/fail results
Public Function BitBltWrapper(ByVal hDstDC As Long, ByVal dstX As Long, ByVal dstY As Long, ByVal dstWidth As Long, ByVal dstHeight As Long, ByVal hSrcDC As Long, ByVal srcX As Long, ByVal srcY As Long, Optional ByVal rastOp As Long = vbSrcCopy) As Boolean
    BitBltWrapper = CBool(BitBlt(hDstDC, dstX, dstY, dstWidth, dstHeight, hSrcDC, srcX, srcY, rastOp) <> 0)
End Function

Public Function StretchBltWrapper(ByVal hDstDC As Long, ByVal dstX As Long, ByVal dstY As Long, ByVal dstWidth As Long, ByVal dstHeight As Long, ByVal hSrcDC As Long, ByVal srcX As Long, ByVal srcY As Long, ByVal srcWidth As Long, ByVal srcHeight As Long, Optional ByVal rastOp As Long = vbSrcCopy) As Boolean
    StretchBltWrapper = CBool(StretchBlt(hDstDC, dstX, dstY, dstWidth, dstHeight, hSrcDC, srcX, srcY, srcWidth, srcHeight, rastOp) <> 0)
End Function

Public Function GetBitmapHeaderFromDC(ByVal srcDC As Long) As GDI_Bitmap
    
    Dim hBitmap As Long
    hBitmap = GetCurrentObject(srcDC, GDI_OBJ_BITMAP)
    If (hBitmap <> 0) Then
        If (GetObject(hBitmap, Len(GetBitmapHeaderFromDC), VarPtr(GetBitmapHeaderFromDC)) = 0) Then
            InternalGDIError "GetObject failed on source hDC", , Err.LastDllError
        End If
    Else
        InternalGDIError "No bitmap in source hDC", "You can't query a DC for bitmap data if the DC doesn't have a bitmap selected into it!", Err.LastDllError
    End If
                        
End Function

'Need a quick and dirty DC for something?  Call this.  (Just remember to free the DC when you're done!)
Public Function GetMemoryDC() As Long
    
    GetMemoryDC = CreateCompatibleDC(0&)
    
    'In debug mode, track how many DCs the program requests
    #If DEBUGMODE = 1 Then
        If GetMemoryDC <> 0 Then
            g_DCsCreated = g_DCsCreated + 1
        Else
            pdDebug.LogAction "WARNING!  GDI.GetMemoryDC() failed to create a new memory DC!"
        End If
    #End If
    
End Function

Public Sub FreeMemoryDC(ByVal srcDC As Long)
    
    If srcDC <> 0 Then
        
        Dim delConfirm As Long
        delConfirm = DeleteDC(srcDC)
    
        'In debug mode, track how many DCs the program frees
        #If DEBUGMODE = 1 Then
            If delConfirm <> 0 Then
                g_DCsDestroyed = g_DCsDestroyed + 1
            Else
                pdDebug.LogAction "WARNING!  GDI.FreeMemoryDC() failed to release DC #" & srcDC & "."
            End If
        #End If
        
    Else
        #If DEBUGMODE = 1 Then
            pdDebug.LogAction "WARNING!  GDI.FreeMemoryDC() was passed a null DC.  Fix this!"
        #End If
    End If
    
End Sub

Public Sub ForceGDIFlush()
    GdiFlush
End Sub

'Basic wrapper to line-drawing via GDI
Public Sub DrawLineToDC(ByVal targetDC As Long, ByVal x1 As Long, ByVal y1 As Long, ByVal x2 As Long, ByVal y2 As Long, ByVal crColor As Long)
    
    'Create a pen with the specified color
    Dim NewPen As Long
    NewPen = CreatePen(PS_SOLID, 1, crColor)
    
    'Select the pen into the target DC
    Dim oldObject As Long
    oldObject = SelectObject(targetDC, NewPen)
    
    'Render the line
    MoveToEx targetDC, x1, y1, 0&
    LineTo targetDC, x2, y2
    
    'Remove the pen and delete it
    SelectObject targetDC, oldObject
    DeleteObject NewPen

End Sub

'Basic wrappers for rect-filling and rect-tracing via GDI
Public Sub FillRectToDC(ByVal targetDC As Long, ByVal x1 As Long, ByVal y1 As Long, ByVal x2 As Long, ByVal y2 As Long, ByVal crColor As Long)

    'Create a brush with the specified color
    Dim tmpBrush As Long
    tmpBrush = CreateSolidBrush(crColor)
    
    'Select the brush into the target DC
    Dim oldObject As Long
    oldObject = SelectObject(targetDC, tmpBrush)
    
    'Fill the rect
    Rectangle targetDC, x1, y1, x2, y2
    
    'Remove the brush and delete it
    SelectObject targetDC, oldObject
    DeleteObject tmpBrush

End Sub

'Add your own error-handling behavior here, as desired
Private Sub InternalGDIError(Optional ByRef errName As String = vbNullString, Optional ByRef errDescription As String = vbNullString, Optional ByVal ErrNum As Long = 0)
    #If DEBUGMODE = 1 Then
        pdDebug.LogAction "WARNING!  The GDI interface encountered an error: """ & errName & """ - " & errDescription
        If (ErrNum <> 0) Then pdDebug.LogAction "(Also, an error number was reported: " & ErrNum & ")"
    #End If
End Sub