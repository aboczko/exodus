inherited frmJud: TfrmJud
  BorderIcons = [biSystemMenu, biMaximize]
  BorderStyle = bsSizeable
  Caption = 'Jabber Search'
  ClientHeight = 355
  ClientWidth = 409
  OldCreateOrder = True
  OnClose = FormClose
  OnResize = FormResize
  ExplicitWidth = 417
  PixelsPerInch = 96
  TextHeight = 13
  inherited TntPanel1: TTntPanel
    Top = 314
    Width = 409
    ExplicitTop = 314
    ExplicitWidth = 409
    inherited Bevel1: TBevel
      Width = 409
      ExplicitWidth = 409
    end
    inherited btnBack: TTntButton
      Left = 167
      Anchors = [akTop, akRight]
      Cancel = True
      OnClick = btnBackClick
      ExplicitLeft = 167
    end
    inherited btnNext: TTntButton
      Left = 243
      Anchors = [akTop, akRight]
      Default = True
      OnClick = btnNextClick
      ExplicitLeft = 243
    end
    inherited btnCancel: TTntButton
      Left = 327
      Anchors = [akTop, akRight]
      OnClick = btnCancelClick
      ExplicitLeft = 327
    end
  end
  inherited Panel1: TPanel
    Width = 409
    ExplicitWidth = 409
    inherited Bevel2: TBevel
      Width = 409
      ExplicitWidth = 409
    end
    inherited lblWizardTitle: TTntLabel
      Width = 126
      Caption = 'Jabber Search Wizard'
      ExplicitWidth = 126
    end
    inherited lblWizardDetails: TTntLabel
      Caption = ''
    end
    inherited Image1: TImage
      Left = 368
      ExplicitLeft = 368
    end
  end
  inherited Tabs: TPageControl
    Width = 409
    Height = 254
    ExplicitWidth = 409
    ExplicitHeight = 254
    inherited TabSheet1: TTabSheet
      object lblSelect: TTntLabel
        Left = 0
        Top = 0
        Width = 401
        Height = 13
        Align = alTop
        Caption = 
          'Select the user database or enter in the Jabber ID of the search' +
          ' agent to use:'
        WordWrap = True
        ExplicitWidth = 365
      end
      object cboJID: TTntComboBox
        Left = 16
        Top = 33
        Width = 233
        Height = 21
        ItemHeight = 13
        Sorted = True
        TabOrder = 0
      end
    end
    object TabSheet2: TTabSheet
      Caption = 'TabSheet2'
      ImageIndex = 1
      ExplicitLeft = 0
      ExplicitTop = 0
      ExplicitWidth = 0
      ExplicitHeight = 0
      object lblWait: TTntLabel
        Left = 0
        Top = 0
        Width = 179
        Height = 13
        Align = alTop
        Caption = 'Please wait. Contacting search agent:'
        WordWrap = True
      end
      object aniWait: TAnimate
        Left = 0
        Top = 13
        Width = 401
        Height = 50
        Align = alTop
        CommonAVI = aviFindFolder
        StopFrame = 29
      end
    end
    object TabFields: TTabSheet
      Caption = 'TabFields'
      ImageIndex = 2
      ExplicitLeft = 0
      ExplicitTop = 0
      ExplicitWidth = 0
      ExplicitHeight = 0
      object lblInstructions: TTntLabel
        Left = 0
        Top = 0
        Width = 204
        Height = 13
        Align = alTop
        Caption = 'Fill in the search criteria to find contacts on.'
        WordWrap = True
      end
    end
    object TabSheet4: TTabSheet
      Caption = 'TabSheet4'
      ImageIndex = 3
      ExplicitLeft = 0
      ExplicitTop = 0
      ExplicitWidth = 0
      ExplicitHeight = 0
      object Panel2: TPanel
        Left = 0
        Top = 166
        Width = 401
        Height = 59
        Align = alBottom
        BevelOuter = bvNone
        BorderWidth = 2
        TabOrder = 0
        object Label3: TTntLabel
          Left = 2
          Top = 2
          Width = 128
          Height = 13
          Caption = 'Add Contacts to this group:'
        end
        object lblAddGrp: TTntLabel
          Left = 2
          Top = 43
          Width = 83
          Height = 13
          Cursor = crHandPoint
          Caption = 'Add a new Group'
          Color = clBtnFace
          ParentColor = False
          OnClick = lblAddGrpClick
        end
        object lblCount: TTntLabel
          Left = 322
          Top = 2
          Width = 65
          Height = 13
          Alignment = taRightJustify
          Caption = 'N items found'
        end
        object cboGroup: TTntComboBox
          Left = 5
          Top = 20
          Width = 228
          Height = 21
          Style = csDropDownList
          ItemHeight = 0
          Sorted = True
          TabOrder = 0
        end
        object Button1: TButton
          Left = 256
          Top = 19
          Width = 145
          Height = 25
          Caption = 'Add Contacts'
          TabOrder = 1
          OnClick = popAddClick
        end
      end
      object lstContacts: TTntListView
        Left = 0
        Top = 0
        Width = 401
        Height = 164
        Align = alClient
        Columns = <
          item
          end
          item
          end
          item
          end>
        HideSelection = False
        MultiSelect = True
        OwnerData = True
        ReadOnly = True
        RowSelect = True
        PopupMenu = PopupMenu1
        TabOrder = 1
        ViewStyle = vsReport
        OnColumnClick = lstContactsColumnClick
        OnContextPopup = lstContactsContextPopup
        OnData = lstContactsData
        ExplicitHeight = 166
      end
    end
    object TabXData: TTabSheet
      Caption = 'TabXData'
      ImageIndex = 4
      ExplicitLeft = 0
      ExplicitTop = 0
      ExplicitWidth = 0
      ExplicitHeight = 0
      inline xdataBox: TframeXData
        Left = 0
        Top = 0
        Width = 401
        Height = 225
        Align = alClient
        TabOrder = 0
        TabStop = True
        ExplicitWidth = 401
        ExplicitHeight = 225
        inherited Panel1: TPanel
          Width = 401
          Height = 225
          ExplicitWidth = 401
          ExplicitHeight = 225
          inherited ScrollBox1: TScrollBox
            Width = 391
            Height = 215
            ExplicitWidth = 391
            ExplicitHeight = 215
          end
        end
      end
    end
  end
  object PopupMenu1: TTntPopupMenu
    Left = 296
    Top = 16
    object popAdd: TTntMenuItem
      Caption = 'Add Contact'
      OnClick = popAddClick
    end
    object popProfile: TTntMenuItem
      Caption = 'View Profile'
      OnClick = popProfileClick
    end
    object N1: TTntMenuItem
      Caption = '-'
    end
    object popChat: TTntMenuItem
      Caption = 'Start Chat'
      OnClick = popChatClick
    end
    object popMessage: TTntMenuItem
      Caption = 'Send Message'
      OnClick = popMessageClick
    end
  end
end