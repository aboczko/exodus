inherited frmDockable: TfrmDockable
  Caption = 'frmDockable'
  ClientWidth = 188
  DragKind = dkDock
  DragMode = dmAutomatic
  KeyPreview = True
  OnClose = FormClose
  OnDragDrop = OnDockedDragDrop
  OnDragOver = OnDockedDragOver
  OnKeyDown = FormKeyDown
  ExplicitWidth = 212
  ExplicitHeight = 201
  PixelsPerInch = 96
  TextHeight = 12
  object pnlDockTop: TPanel
    Left = 0
    Top = 0
    Width = 188
    Height = 30
    Align = alTop
    BevelOuter = bvNone
    ParentColor = True
    TabOrder = 0
    object tbDockBar: TToolBar
      AlignWithMargins = True
      Left = 139
      Top = 3
      Width = 46
      Height = 24
      Align = alRight
      AutoSize = True
      DockSite = True
      EdgeInner = esNone
      EdgeOuter = esNone
      HideClippedButtons = True
      Images = frmExodus.ImageList2
      TabOrder = 0
      Transparent = True
      Wrapable = False
      object btnDockToggle: TToolButton
        AlignWithMargins = True
        Left = 0
        Top = 0
        Margins.Left = 0
        Margins.Top = 0
        Margins.Right = 0
        Margins.Bottom = 0
        AutoSize = True
        Caption = 'btnDockToggle'
        ImageIndex = 82
        OnClick = btnDockToggleClick
      end
      object btnCloseDock: TToolButton
        AlignWithMargins = True
        Left = 23
        Top = 0
        Hint = 'Close this tab'
        Margins.Left = 0
        Margins.Top = 0
        Margins.Right = 0
        Margins.Bottom = 0
        AutoSize = True
        Caption = 'btnCloseDock'
        ImageIndex = 83
        OnClick = btnCloseDockClick
      end
    end
  end
end
