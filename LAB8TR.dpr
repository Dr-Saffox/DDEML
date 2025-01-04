program DDEML_CLINET;

{
  Created by Saffox,
  ��������� ������������ ����� ������,
  ����������� ������ �� ��������� DDE
  (��������� �������� ���� � ��������������)

  ������ ����������: DDEML
  ��� ����������: ��������
  ������: 
	- ������������ (� ��� ����� Extended)
	- �������� ������ (PascalString)
  - BMP
	- ����� ������
}

uses
  windows,
  messages,
  Dialogs,
  SysUtils,  // ��� �������������� � �������
  DDEml;     // "�����������" �������� DDEML.dll

{���������� � ��������� DLL}
{$R RESTR.res} // ������������ ���� ��������

{$H-}

var idInst:Integer;   // ������������� ������������������� ���������� � DDE
    hConv:THandle;    // ����� �������������� ����������
    hAccel:THandle;   // ����� �������������
    selType:THandle;  // ��������� ������
    floatType, pascalType, BMPType:integer; // ������������������ ������� ������
    hSrv,hTopic,hItem:HSZ;            // ������ ������������������ �����
    buffer: array[1..3] of array[0..255] of char;  // ����� ����� (������, ������, ������)
    pasc:pointer;     // ��������� �� ����� (��� ���������� ������ � �������)
    flagBMP:boolean;  // "������" ��� ����������� �����������
    DataStr:string;     // ������ ��� ���������� ���������� ������, ���������� � �������
    
function WndProc(hWnd: THandle; Msg: integer;
                 wParam: longint; lParam: longint): longint;
                 stdcall; forward;

function MyDdeCallback (
  uType: integer;    // ��� ����������
  uFmt: integer;     // ������ ������ ������ ������
  hconv: Thandle;    // ����� DDE-������
  hsz1: Thandle;     // ����� ������
  hsz2: Thandle;     // ����� ������
  hdata: Thandle;    // ����� ������� � ���������� ������
  dwData1: dword;    // �������������� �������� ����������
  dwData2: dword     // �������������� �������� ����������
): THandle; stdcall; // ������� ��������� ������ ������� ��� ������������� ������ �������

begin
   result := 0;
   case  (uType and XTYP_MASK) of  // ��� ����������
    XTYP_DISCONNECT:          // (?) ����������� ����� ���������� �� �������
      begin
        DDEDisconnect(hConv);
        hConv:= 0; // ��������� ������ �������� ����������
      end;

    {                         // ���� �� ������ ������������ �� ����������, �� "�������������" �������� ���� �� �����...
    XTYP_XACT_COMPLETE:
    begin                     // ����������, �������������� ������� ������� DdeClientTransaction, ���������
        if (uFmt = selType) then begin
          if (selType = floatType) then begin
            //...
          end
          else if (selType = blocktextType) then begin
            //...
          end;
          result:=DDE_FACK; // �������� ��������� ���������
        end else begin
          result:=DDE_FNOTPROCESSED;  // �� ��� ��� ������
        end;
    end;
    }
   end;

end;

procedure WinMain; {�������� ���� ��������� ���������}
  const szClassName='DDE-Client';
  var   wndClass:TWndClassEx;
        msg:TMsg;
        hwnd1,hwnd2:THandle;
begin
  wndClass.cbSize:=sizeof(wndClass);        // ������ ���� ��������� � ������
  wndClass.style:=0;                        // ����� ����
  wndClass.lpfnWndProc:=@WndProc;           // ������. �� ������� ���������
  wndClass.cbClsExtra:=0;                   // ���. �����
  wndClass.cbWndExtra:=dlgwindowextra;      // ���. �����   // ��� "dlgwindowextra" (?)
  wndClass.hInstance:=hInstance;            // �����. ���������, ������ �������� ������� ����.
  wndClass.hIcon:=loadIcon(hInstance, 'TRICON');
  wndClass.hCursor:=loadCursor(0, idc_Arrow);
  wndClass.hbrBackground:=GetStockObject(ltgray_Brush);
  wndClass.lpszMenuName:='TRMENU';
  wndClass.lpszClassName:=szClassName;
  wndClass.hIconSm:=wndClass.hIcon;        // ��������� ������

  RegisterClassEx(wndClass);

  hwnd1:=CreateWindowEx(ws_ex_controlparent,
         szClassName, {��� ������ ����}
         'DDEML-Client',    {��������� ����}
         ws_popupwindow or ws_sysmenu or ws_caption or ws_border or ws_visible,       {����� ����}
         10,                      {Left}
         10,                      {Top}
         700,                     {Width}
         370,                     {Height}
         0,                       {����� ������������� ����}
         0,                       {����� �������� ����}
         hInstance,               {����� ���������� ����������}
         nil);                    {��������� �������� ����}

  while GetMessage(msg,0,0,0) do begin
    if TranslateAccelerator(hwnd1, hAccel, msg)=0 then begin

      if not IsDialogMessage(GetActiveWindow,msg)
           {���� Windows �� ���������� � �� ������������ ������������ ���������
            ��� ������� ������������ ����� �������� �������� ����������,
            ����� ��������� ���� �� ����������� ���������}
      then begin
      TranslateMessage(msg);
      DispatchMessage(msg);
      end;  {����� �� wm_quit, �� ������� GetMessage ������ FALSE}

    end;
  end;

end;

function WndProc(hWnd: THandle; Msg: integer; wParam: longint; lParam: longint): longint; stdcall;
  const   // ����������� ID "���������"
      btnRequest1 = 100;    item1 = 110;      item2 = 210;      Srv = 400;
      btnRequest2 = 200;    topic1 = 120;     topic2 = 220;     MsgServer = 500;
      btnReset = 300;       format1N = 131;   format2N = 231;   MsgData = 600;
                            format1T = 132;   format2T = 232;
                            format1B = 133;   format2B = 233;
                            format1P = 134;   format2P = 234;

  var rect:TRect;         // ������� ���������� �������
      hData:THandle;      // ����� ������������ ������� '�������� ��'
      pData:PChar;        // ��������� �� '�������� ��'
      hDDEData: THandle;  // ����� ������� ���������� �� ������
      dataSize:integer;   // ������ ������ ��� ����������� ������ � �������
      bufferMsg: string;  // ����� ��� "������" ��������� � ����������� WM_DDE...
      lenDDE, lenData:integer;        // ���������������  ���������� (���-�� ������� � "�����")
      hDC:THandle;        // ������ ��������� ���������� (WM_PAINT)
      bmi:^TBitmapInfo;   // ��������� �� ��������� BMP
      BMPdata:pointer;    // ��������� �� ������ BMP
      ps:TPaintStruct;    // ��������� �� PAINTSTRUCT
begin
  result:=0;
  case Msg of
    wm_create: {������ ���������� ��������� ��� �������� �������� ����}
    begin
      GetClientRect(hwnd,rect); // ��������� �������� ���������� �������

      {---------------------- buttons --------------------------------------}
        CreateWindow('button',
                   '������ 1',
                   ws_visible or ws_child or bs_pushbutton or ws_tabstop,
                   380,190,
                   100,25,
                   hwnd,
                   100, //btnRequest1
                   hInstance,
                   nil);
        CreateWindow('button',
                   '������ 2',
                   ws_visible or ws_child or bs_pushbutton or ws_tabstop,
                   380,220,
                   100,25,
                   hwnd,
                   200, //btnRequest2
                   hInstance,
                   nil);
        CreateWindow('button',
                   '�������� ����',
                   ws_visible or ws_child or bs_pushbutton or ws_tabstop,
                   380,250,
                   100,25,
                   hwnd,
                   300, //btnReset
                   hInstance,
                   nil);
        // ���� ��� ������������ ������ � ���������
        CreateWindow('button',
                   '����������� �����. DDEML:',
                   ws_visible or ws_child or bs_groupbox,
                   5,120,
                   1,200,
                   hwnd,
                   99,
                   hInstance,
                   nil);
        CreateWindowEx(WS_EX_CLIENTEDGE,
                   'listbox',
                   '',
                   ws_visible or ws_child or ws_border or ws_tabstop or ws_vscroll {or ws_hscroll},
                   10,140,
                   210,180,
                   hwnd,
                   500, // MsgServer (for messages DDE)
                   hInstance,
                   nil);
        CreateWindow('button',
                   '������:',
                   ws_visible or ws_child or bs_groupbox,
                   235,120,
                   1,200,
                   hwnd,
                   98,
                   hInstance,
                   nil);
        CreateWindowEx(WS_EX_CLIENTEDGE,
                   'listbox',
                   '',
                   ws_visible or ws_child or ws_border or ws_tabstop or ws_vscroll or ws_hscroll,
                   240,140,
                   120,180,
                   hwnd,
                   600, // MsgData (for result data)
                   hInstance,
                   nil);
        CreateWindow('button',
                   '�������:',
                   ws_visible or ws_child or bs_groupbox,
                   490,110,
                   200,200,
                   hwnd,
                   97,  // For BitmapFile (frame)
                   hInstance,
                   nil);
        {--------------------- "Settings" -----------------------------------}
        CreateWindow('button',
                   '���������:',
                   ws_visible or ws_child or bs_groupbox,
                   5,0,
                   680,100,
                   hwnd,
                   96,
                   hInstance,
                   nil);

        // ������ ������ ������ ������� ����������
        CreateWindow('button',
                   '������ 1:',
                   ws_visible or ws_child or bs_groupbox or ws_group,
                   5,35,
                   10,10,
                   hwnd,
                   95,
                   hInstance,
                   nil);
        CreateWindowEx(WS_EX_CLIENTEDGE, // ���������� �����
                   'edit',
                   'Item1',
                   ws_visible or ws_child or ws_border or ws_tabstop,
                   90,30,
                   80,25,
                   hwnd,
                   110, // Item1
                   hInstance,
                   nil);
        CreateWindowEx(WS_EX_CLIENTEDGE,
                   'edit',
                   'Topic1',
                   ws_visible or ws_child or ws_border or ws_tabstop,
                   175,30,
                   80,25,
                   hwnd,
                   120, // Topic1
                   hInstance,
                   nil);
        CreateWindow('button',
                   'Float10',
                   ws_visible or ws_child or bs_autoradiobutton OR WS_TABSTOP,
                   265,25,
                   70,35,
                   hWnd,
                   131, // Format1N
                   hInstance,
                   nil);
        CreateWindow('button',
                   'CF_TEXT',
                   ws_visible or ws_child or bs_autoradiobutton,
                   340,25,
                   80,35,
                   hWnd,
                   132, // Format1T
                   hInstance,
                   nil);
        CreateWindow('button',
                   'BMP',
                   ws_visible or ws_child or bs_autoradiobutton,
                   425,25,
                   50,35,
                   hWnd,
                   133, // Format1B
                   hInstance,
                   nil);
        CreateWindow('button',
                   'PascalString',
                   ws_visible or ws_child or bs_autoradiobutton,
                   490,25,
                   100,35,
                   hWnd,
                   134, // Format1P
                   hInstance,
                   nil);

        // ������ ������ ������ ������� ����������
        CreateWindow('button',
                   '������ 2:',
                   ws_visible or ws_child or bs_groupbox or ws_group,
                   5,65,
                   10,10,
                   hwnd,
                   94,
                   hInstance,
                   nil);
        CreateWindowEx(WS_EX_CLIENTEDGE,
                   'edit',
                   'Item2',
                   ws_visible or ws_child or ws_border or ws_tabstop,
                   90,60,
                   80,25,
                   hwnd,
                   210, // Item2
                   hInstance,
                   nil);
        CreateWindowEx(WS_EX_CLIENTEDGE,
                   'edit',
                   'Topic2',
                   ws_visible or ws_child or ws_border or ws_tabstop,
                   175,60,
                   80,25,
                   hwnd,
                   220, // Topic2
                   hInstance,
                   nil);
         CreateWindow('button',
                   'Float10',
                   ws_visible or ws_child or bs_autoradiobutton OR ws_tabstop,
                   265,55,
                   70,35,
                   hWnd,
                   231, // Format2N
                   hInstance,
                   nil);
        CreateWindow('button',
                   'CF_TEXT',
                   ws_visible or ws_child or bs_autoradiobutton,
                   340,55,
                   80,35,
                   hWnd,
                   232, // Format2T
                   hInstance,
                   nil);
        CreateWindow('button',
                   'BMP',
                   ws_visible or ws_child or bs_autoradiobutton,
                   425,55,
                   50,35,
                   hWnd,
                   233, // Format2B
                   hInstance,
                   nil);
        CreateWindow('button',
                   'PascalString',
                   ws_visible or ws_child or bs_autoradiobutton,
                   490,55,
                   100,35,
                   hWnd,
                   234, // Format2P
                   hInstance,
                   nil);

        CreateWindow('button',
                   '������:',
                   ws_visible or ws_child or bs_groupbox,
                   380,120,
                   100,60,
                   hwnd,
                   93,
                   hInstance,
                   nil);
         CreateWindowEx(WS_EX_CLIENTEDGE,
                   'edit',
                   'dde_srv',
                   ws_visible or ws_child or ws_border or ws_tabstop,
                   390,140,
                   80,25,
                   hwnd,
                   400, // Srv
                   hInstance,
                   nil);
        {-----------------------------------------------------------------}

        bufferMsg := '                                            '; // "������� ������"
        flagBMP := False;  // ���������� ���� "�������" (������ ���!)

        // ��������� ��������� ��������� �����������
        SendMessage(GetDlgItem(hwnd,format1N), BM_SETCHECK, BST_CHECKED, 0);
        SendMessage(GetDlgItem(hwnd,format2N), BM_SETCHECK, BST_CHECKED, 0);

        // �������� �������������
        hAccel := LoadAccelerators(hInstance, 'ACCEL');

        // ������������� DDEML
        idInst:= 0;
        DdeInitialize(idInst, @MyDdeCallback, APPCMD_CLIENTONLY, 0);   // ������� ������������� DDEML

        // ����������� ����� ������
        floatType := RegisterClipboardFormat('Float10');
        pascalType := RegisterClipboardFormat('PascalString');
        BMPType := RegisterClipboardFormat('BitmapFile');
    end;

    wm_command: // ��������� ������ �� ���� ������� ����������
    begin
      case hiword(wParam) of
        BN_Clicked:        // 0
        begin

          case loword(wparam) of     // ���� ��������� ���������� �������������
            101:
            begin
              // ����� �������� ������� � ��������� ����
              hData := LoadResource(hInstance, FindResource(hInstance, 'data1', 'DESCRIPTTR') );    // ��������� ������� '�������� ��'
              pData := LockResource(hData);        // ��������� ��������� �� ������ �� ������
                                                  // (�.�. ��� ������ � ������ ������� ��������� �� �����, � ���������)
              MessageBox(0, pData, '�������� �������� �������� �������', mb_ok or MB_ICONINFORMATION);
            end;
            102: MessageBox(0, '�������� ��������� - ���� ��� ����� ���������...', 'HELP', mb_ok or MB_ICONINFORMATION);  // www.�������... :)
            103: sendmessage(hwnd, wm_close, 0, 0);    // �������� �� "Alt+X"
          end;

          if (loword(wParam) = btnRequest1) or (loword(wParam) = btnRequest2) then begin

            // �������� ������� ����� (��� �������, ������� � ��������)
            GetDlgItemText(hWnd,Srv,@buffer[1],256);
            hSrv:=DdeCreateStringHandle(idInst,@buffer[1],CP_WINANSI);

            // ��� ������� � �������� � ����������� �� ����, � ����� ������ ������
            if(loword(wParam) = btnRequest1) then begin

              // ������������ ������� �� "������� 1"
              GetDlgItemText(hWnd,topic1,@buffer[2],256);
              hTopic:=DdeCreateStringHandle(idInst,@buffer[2],CP_WINANSI);

              GetDlgItemText(hWnd,item1,@buffer[3],256);
              hItem:=DdeCreateStringHandle(idInst,@buffer[3],CP_WINANSI);

              // ����������� ���������� ���� ������
              if (SendMessage(GetDlgItem(hwnd,format1N), BM_GETCHECK,0,0) <> 0) then selType := floatType
              else if (SendMessage(GetDlgItem(hwnd,format1B), BM_GETCHECK,0,0) <> 0) then selType := BMPType
              else if (SendMessage(GetDlgItem(hwnd,format1P), BM_GETCHECK,0,0) <> 0) then selType := pascalType
              else selType := 1;    // CF_TEXT = 1   �� ����� ������� pascalType

            end
            else
            begin

              // ������������ ������� �� "������� 2"
              GetDlgItemText(hWnd,topic2,@buffer[2],256);
              hTopic:=DdeCreateStringHandle(idInst,@buffer[2],CP_WINANSI);

              GetDlgItemText(hWnd,item2,@buffer[3],256);
              hItem:=DdeCreateStringHandle(idInst,@buffer[3],CP_WINANSI);

              // ����������� ���������� ���� ������
              if (SendMessage(GetDlgItem(hwnd,format2N), BM_GETCHECK,0,0) <> 0) then selType := floatType
              else if (SendMessage(GetDlgItem(hwnd,format2B), BM_GETCHECK,0,0) <> 0) then selType := BMPType
              else if (SendMessage(GetDlgItem(hwnd,format2P), BM_GETCHECK,0,0) <> 0) then selType := pascalType
              else selType := 1;    // CF_TEXT = 1   �� ����� ������� pascalType
            end;

            hConv := DDEConnect(idInst, hSrv, hTopic, nil);  // ������������ ���������� (� ���������� � hConv - ����� �������� ����������)

            bufferMsg := '<<-- DDEConnect              ';        // ����� ��������� � ������� ���������� � ��������          WM_DDE_INITIATE
            SendDlgItemMessage(hwnd, MsgServer, LB_ADDSTRING, 0, integer(@bufferMsg)+1);
            bufferMsg := '                                    ';

            if (hConv = 0) then begin  // ����� ��������� � ���, ��� ������ �� �������� �� ������
              bufferMsg := 'S: ***��� ������ �������...';
              SendDlgItemMessage(hwnd, MsgServer, LB_ADDSTRING, 0, integer(@bufferMsg)+1);
            end
            else begin
              SetLength(bufferMsg,15);
              bufferMsg := '+>> ������������� �����.';              // ����� ��������� �� "��������" �����������  WM_DDE_ACK
              //bufferMsg := copy(bufferMsg,1,15);
              SendDlgItemMessage(hwnd, MsgServer, LB_ADDSTRING, 0, integer(@bufferMsg)+1);
              bufferMsg := '                                    ';

              // ������ �� ��������� ������ �� ������� (������ ���������� - ����� _____)
              hDDEData := DdeClientTransaction(nil, 0, hConv, hItem, selType, XTYP_REQUEST, 3000, nil); // � ���������� � hDDEData - ��������� �� ������

              bufferMsg := '<<-- DdeClientTransaction';    // ����� ��������� �� �������� ������� �������   WM_DDE_REQUEST(item)
              SendDlgItemMessage(hwnd, MsgServer, LB_ADDSTRING, 0, integer(@bufferMsg)+1);
              bufferMsg := '                                    ';

              // �������� ���������� ����������� ������� �� ������
              if hDDEData <> 0 then
              begin
                bufferMsg := '+>> ������� ����� ������';       // ������� "��������" ����� �� �������      WM_DDE_DATA(item)
                SendDlgItemMessage(hwnd, MsgServer, LB_ADDSTRING, 0, integer(@bufferMsg)+1);
                bufferMsg := '                                    ';

                dataSize:=0;                                  // "�������" ������� ������
                dataSize:=DdeGetData(hDDEData,nil,300,0);     // �-� ����� ����� ������ � ������, ������� ����� ����������� � �����
                                                              // "300" - ������������ ����� ��� ���������� � ������ (����, ��� ����� ��, ������ �� �� ���...)
                ShowMessage('������ ����������� ����� ������: ' + IntToStr(dataSize) + ' ����.');      // ��� �������

                // (����)��������� ������ ��� ���������� ���������� (������������ �������!)
                freemem(pasc);
                pasc:=0;
                getmem(pasc,dataSize);

                DdeGetData(hDDEData,pasc,dataSize,0);      // ��� ��� ����������� � ����� ���������� �� ���������

                // ����� ������ � "����" ������������ � ����������� �� ������������ ����
                if (selType = 1) then begin   // ����� ������ 'CF_TEXT'

                  //hDCListBox = GetDC(GetDlgItem(hInstance,MsgData);
                  //GetTextExtentPoint32(hDCListBox,DataStr,strlen(DataStr), &lpSize);
                  //if (___) then SendDlgItemMessage(hwnd, MsgData, LB_SETHORIZONTALEXTENT, ___, 0);

                  SendDlgItemMessage(hwnd, MsgData, LB_SETHORIZONTALEXTENT, 9350, 0);
                  SendDlgItemMessage(hwnd, MsgData, LB_ADDSTRING, 0, Integer(pasc)); // ��������������� - ����� ������ ������������
                end
                else if (selType = floatType) then begin  // ������������ 'Float10'

                  DataStr := FloatToStr(Extended(pasc^));   // �������������� � ������ �� ���������
                                                            // �.�. �� ������� �������. ����� �.�. � �.�. Ext -> ����� ����� ���������������
                  //ShowMessage(DataStr);
                  SendDlgItemMessage(hwnd, MsgData, LB_ADDSTRING, 0, Integer(@DataStr));  // ��������������� - ����� ������ ������������
                  DataStr := '                                    ';
                  
                end
                else if (selType = pascalType) then begin  // �������� ������ (�������-������)

                  DataStr := string(pasc^);  // �������������� � ������ �� ��������� (��� �������� ������������ �����)
                  SendDlgItemMessage(hwnd, MsgData, LB_ADDSTRING, 0, Integer(@DataStr)); // ��������������� - ����� ������ ������������
                  DataStr := '                                    ';

                end
                else begin                                // ������� BMP  'BitmapFile' - ������������ ������ ������

                  flagBMP := True;                        // "����������" ���� - ������������ � wm_paint � ���, ��� ���������� "����������" �������
                  GetClientRect(hwnd,rect);
                  InvalidateRect(hwnd,@rect,true);        // ����������� ������ ���� (������������� wm_paint)

                end;

                DDEFreeDataHandle(hDDEData); // ������������ ������ ������, ���������� �� �������
              end
              else
              begin
                bufferMsg := '+>> ������� "0"-� �����';  // ������� ����� �� ������� �� ���������� ������������� ������   WM_DDE_DATA(negative)
                SendDlgItemMessage(hwnd, MsgServer, LB_ADDSTRING, 0, integer(@bufferMsg)+1);
                bufferMsg := '                                    ';
              end;
            end;

            //DdeFreeStringHandle(idInst,hSrv);     // |�������� ������� �����
            //DdeFreeStringHandle(idInst,hTopic);   // |(�������, �������, ��������)
            //DdeFreeStringHandle(idInst,hItem);    // |

            if (hConv <> 0) then begin  // ��������� ���� �� ����������� � ���� ���� - ���������� "������"

              bufferMsg := '<<-- DDEDisconnect';       // ����� ��������� � ������� �� ������ ���������� � �������      WM_DDE_TERMINATE
              SendDlgItemMessage(hwnd, MsgServer, LB_ADDSTRING, 0, integer(@bufferMsg)+1);
              bufferMsg := '                                    ';

              // �������� ������� �� "������" ���������� � ����������� ��������� ����������
              if(DDEDisconnect(hConv) <> False) then begin
                bufferMsg := '+>> ������������� ����.';       // "�������������" ������� ���������� ��������    WM_DDE_TERMINATE
                SendDlgItemMessage(hwnd, MsgServer, LB_ADDSTRING, 0, integer(@bufferMsg)+1);
                bufferMsg := '                                    ';
              end
              else  begin
                bufferMsg := 'S: ***������� ����������...';  // ����� �� ������� ������...
                SendDlgItemMessage(hwnd, MsgServer, LB_ADDSTRING, 0, integer(@bufferMsg)+1);
                bufferMsg := '                                    ';
              end;
              
              hConv:=0;  // ��������� ������ �������� ����������
            end;
          end;

          // ������� ���� ������ � ����������� ��������� DDE
          if (loword(wParam) = btnReset) then begin
            // ��������� ���������� ����� � "�����"
            lenDDE := SendDlgItemMessage(hwnd,MsgServer,LB_GETCOUNT,0,0);
            lenData := SendDlgItemMessage(hwnd,MsgData,LB_GETCOUNT,0,0);

            while ((lenDDE <> 0) or (lenData <> 0)) do begin
              // �������� "������" ������ �� ����
              if (lenDDE <> 0) then SendDlgItemMessage(hwnd,MsgServer,LB_DELETESTRING,lenDDE-1,0);
              if (lenData <> 0) then SendDlgItemMessage(hwnd,MsgData,LB_DELETESTRING,lenData-1,0);
              // ��������� ���������� ���������� ����� � ����
              lenDDE := SendDlgItemMessage(hwnd,MsgServer,LB_GETCOUNT,0,0);;
              lenData := SendDlgItemMessage(hwnd,MsgData,LB_GETCOUNT,0,0);;
            end;

            InvalidateRect(hwnd,nil,true);         // ����������� ������ ���� ("�����" ����������� ������)
          end;
        end;

        1:
        begin
          if (lparam = 0) then begin
            case loword(wparam) of
              101: PostMessage(hwnd, wm_command, 101, 0);     //  "Q" - ��������
              103: PostMessage(hwnd, wm_command, 103, 0);     // "ALT+X" - �����
            end;
          end;
        end;

      end;
    end;


    wm_paint:
    begin
      hDC:=BeginPaint(hWnd,ps);
      GetClientRect(hWnd,rect);

        // ��������� ����������� ������, ���� ���� "������"
        if (flagBMP = True) then begin
          integer(bmi):=integer(pasc)+sizeof(TBitmapFileheader);
          integer(BMPdata):=integer(pasc)+TBitmapFileheader(pasc^).bfOffBits;

          stretchDiBits(hDC, 495, 130, 190, 175,                               // ���������� � ������� �������� ������ (������� ����)
                        0,0,bmi^.bmiheader.biWidth, bmi^.bmiheader.biHeight,  // ���������� � ������� ��������� ������
                        BMPdata,bmi^,DIB_RGB_COLORS,srccopy);

          flagBMP := False;        // ����� ��������� ����������� ������ - ����� �����
        end;

      EndPaint(hWnd,ps);
    end;


    wm_close:
    begin     // ������ ���������� ������������ �������������

      if (hConv <> 0) then DDEDisconnect(hConv);      // ������ ���������� � ��������
      DdeUninitialize(idInst);                        // ������������ ��������� ��������
                                                      // ����������� ��� DDEML
      FreeResource(hData);                            // ������������ ��������
      DestroyWindow(hwnd);
    end;


    wm_destroy: PostQuitMessage(0);

  else
    result:=DefDlgProc(hwnd,msg,wparam,lparam);
  end;
end;


begin
  WinMain;
end.
