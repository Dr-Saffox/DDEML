program DDEML_CLINET;

{
  Created by Saffox,
  Программа представляет собой КЛИЕНТ,
  реализующий диалог по протоколу DDE
  (программа снабжена меню и акселераторами)

  Способ реализации: DDEML
  Тип соединения: холодное
  Данные: 
	- Вещественные (в том числе Extended)
	- Короткие строки (PascalString)
  - BMP
	- Блоки текста
}

uses
  windows,
  messages,
  Dialogs,
  SysUtils,  // для преобразований и отладки
  DDEml;     // "статическая" загрузка DDEML.dll

{интерфейсы к системным DLL}
{$R RESTR.res} // Подключается файл ресурсов

{$H-}

var idInst:Integer;   // идентификатор зарегистрированного приложения в DDE
    hConv:THandle;    // хэндл установленного соединения
    hAccel:THandle;   // хэндл акселераторов
    selType:THandle;  // выбранный формат
    floatType, pascalType, BMPType:integer; // зарегистрированные форматы данных
    hSrv,hTopic,hItem:HSZ;            // хэндлы зарегистрированных строк
    buffer: array[1..3] of array[0..255] of char;  // буфер строк (сервис, раздел, данные)
    pasc:pointer;     // указатель на буфер (для копировани данных с сервера)
    flagBMP:boolean;  // "флажок" для перерисовки изображения
    DataStr:string;     // строка для локального сохранения данных, полученных с сервера
    
function WndProc(hWnd: THandle; Msg: integer;
                 wParam: longint; lParam: longint): longint;
                 stdcall; forward;

function MyDdeCallback (
  uType: integer;    // тип транзакции
  uFmt: integer;     // формат данных буфера обмена
  hconv: Thandle;    // хэндл DDE-сеанса
  hsz1: Thandle;     // хэндл строки
  hsz2: Thandle;     // хэндл строки
  hdata: Thandle;    // хэндл объекта в глобальной памяти
  dwData1: dword;    // дополнительный параметр транзакции
  dwData2: dword     // дополнительный параметр транзакции
): THandle; stdcall; // Функция обратного вызова клиента для динамического обмена данными

begin
   result := 0;
   case  (uType and XTYP_MASK) of  // тип транзакции
    XTYP_DISCONNECT:          // (?) неожиданный обрыв соединения от сервера
      begin
        DDEDisconnect(hConv);
        hConv:= 0; // обнуление хэндла текущего соединения
      end;

    {                         // Если бы данные передавались бы асинхронно, то "распаковывать" логичнее было бы здесь...
    XTYP_XACT_COMPLETE:
    begin                     // транзакция, инициированная вызовом функции DdeClientTransaction, завершена
        if (uFmt = selType) then begin
          if (selType = floatType) then begin
            //...
          end
          else if (selType = blocktextType) then begin
            //...
          end;
          result:=DDE_FACK; // успешный результат обработки
        end else begin
          result:=DDE_FNOTPROCESSED;  // не тот тип данных
        end;
    end;
    }
   end;

end;

procedure WinMain; {Основной цикл обработки сообщений}
  const szClassName='DDE-Client';
  var   wndClass:TWndClassEx;
        msg:TMsg;
        hwnd1,hwnd2:THandle;
begin
  wndClass.cbSize:=sizeof(wndClass);        // размер этой структуры в байтах
  wndClass.style:=0;                        // стиль окна
  wndClass.lpfnWndProc:=@WndProc;           // указат. на оконную процедуру
  wndClass.cbClsExtra:=0;                   // доп. байты
  wndClass.cbWndExtra:=dlgwindowextra;      // доп. байты   // или "dlgwindowextra" (?)
  wndClass.hInstance:=hInstance;            // опред. экземпляр, внутри которого оконная проц.
  wndClass.hIcon:=loadIcon(hInstance, 'TRICON');
  wndClass.hCursor:=loadCursor(0, idc_Arrow);
  wndClass.hbrBackground:=GetStockObject(ltgray_Brush);
  wndClass.lpszMenuName:='TRMENU';
  wndClass.lpszClassName:=szClassName;
  wndClass.hIconSm:=wndClass.hIcon;        // маленький значок

  RegisterClassEx(wndClass);

  hwnd1:=CreateWindowEx(ws_ex_controlparent,
         szClassName, {имя класса окна}
         'DDEML-Client',    {заголовок окна}
         ws_popupwindow or ws_sysmenu or ws_caption or ws_border or ws_visible,       {стиль окна}
         10,                      {Left}
         10,                      {Top}
         700,                     {Width}
         370,                     {Height}
         0,                       {хэндл родительского окна}
         0,                       {хэндл оконного меню}
         hInstance,               {хэндл экземпляра приложения}
         nil);                    {параметры создания окна}

  while GetMessage(msg,0,0,0) do begin
    if TranslateAccelerator(hwnd1, hAccel, msg)=0 then begin

      if not IsDialogMessage(GetActiveWindow,msg)
           {Если Windows не распознает и не обрабатывает клавиатурные сообщения
            как команды переключения между оконными органами управления,
            тогда чообщение идет на стандартную обработку}
      then begin
      TranslateMessage(msg);
      DispatchMessage(msg);
      end;  {выход по wm_quit, на которое GetMessage вернет FALSE}

    end;
  end;

end;

function WndProc(hWnd: THandle; Msg: integer; wParam: longint; lParam: longint): longint; stdcall;
  const   // определение ID "контролов"
      btnRequest1 = 100;    item1 = 110;      item2 = 210;      Srv = 400;
      btnRequest2 = 200;    topic1 = 120;     topic2 = 220;     MsgServer = 500;
      btnReset = 300;       format1N = 131;   format2N = 231;   MsgData = 600;
                            format1T = 132;   format2T = 232;
                            format1B = 133;   format2B = 233;
                            format1P = 134;   format2P = 234;

  var rect:TRect;         // размеры клиентской области
      hData:THandle;      // хэндл загруженного ресурса 'Описание ТР'
      pData:PChar;        // указатель на 'Описание ТР'
      hDDEData: THandle;  // хэндл текущей транзакции на сервер
      dataSize:integer;   // размер буфера для копирования данных с сервера
      bufferMsg: string;  // буфер для "набора" сообщений о прохождении WM_DDE...
      lenDDE, lenData:integer;        // вспомогательные  переменные (кол-во записей в "окнах")
      hDC:THandle;        // хэндлы контекста устройства (WM_PAINT)
      bmi:^TBitmapInfo;   // указатель на заголовок BMP
      BMPdata:pointer;    // указатель на данные BMP
      ps:TPaintStruct;    // указатель на PAINTSTRUCT
begin
  result:=0;
  case Msg of
    wm_create: {Органы управления создаются при создании главного окна}
    begin
      GetClientRect(hwnd,rect); // получение размеров клиентской области

      {---------------------- buttons --------------------------------------}
        CreateWindow('button',
                   'Запрос 1',
                   ws_visible or ws_child or bs_pushbutton or ws_tabstop,
                   380,190,
                   100,25,
                   hwnd,
                   100, //btnRequest1
                   hInstance,
                   nil);
        CreateWindow('button',
                   'Запрос 2',
                   ws_visible or ws_child or bs_pushbutton or ws_tabstop,
                   380,220,
                   100,25,
                   hwnd,
                   200, //btnRequest2
                   hInstance,
                   nil);
        CreateWindow('button',
                   'Очистить окна',
                   ws_visible or ws_child or bs_pushbutton or ws_tabstop,
                   380,250,
                   100,25,
                   hwnd,
                   300, //btnReset
                   hInstance,
                   nil);
        // Окна дял визаулизации данных и сообщений
        CreateWindow('button',
                   'Прохождение сообщ. DDEML:',
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
                   'Данные:',
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
                   'Рисунок:',
                   ws_visible or ws_child or bs_groupbox,
                   490,110,
                   200,200,
                   hwnd,
                   97,  // For BitmapFile (frame)
                   hInstance,
                   nil);
        {--------------------- "Settings" -----------------------------------}
        CreateWindow('button',
                   'Настройки:',
                   ws_visible or ws_child or bs_groupbox,
                   5,0,
                   680,100,
                   hwnd,
                   96,
                   hInstance,
                   nil);

        // Начало первой группы органов управления
        CreateWindow('button',
                   'Запрос 1:',
                   ws_visible or ws_child or bs_groupbox or ws_group,
                   5,35,
                   10,10,
                   hwnd,
                   95,
                   hInstance,
                   nil);
        CreateWindowEx(WS_EX_CLIENTEDGE, // Утопленная рамка
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

        // Начало второй группы органов управления
        CreateWindow('button',
                   'Запрос 2:',
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
                   'Сервис:',
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

        bufferMsg := '                                            '; // "очистка буфера"
        flagBMP := False;  // изначально флаг "сброшен" (данных нет!)

        // настройка исходного состояния радиокнопок
        SendMessage(GetDlgItem(hwnd,format1N), BM_SETCHECK, BST_CHECKED, 0);
        SendMessage(GetDlgItem(hwnd,format2N), BM_SETCHECK, BST_CHECKED, 0);

        // загрузка акселераторов
        hAccel := LoadAccelerators(hInstance, 'ACCEL');

        // инициализация DDEML
        idInst:= 0;
        DdeInitialize(idInst, @MyDdeCallback, APPCMD_CLIENTONLY, 0);   // функция инициализации DDEML

        // регистрация типов данных
        floatType := RegisterClipboardFormat('Float10');
        pascalType := RegisterClipboardFormat('PascalString');
        BMPType := RegisterClipboardFormat('BitmapFile');
    end;

    wm_command: // Обработка команд от всех органов управления
    begin
      case hiword(wParam) of
        BN_Clicked:        // 0
        begin

          case loword(wparam) of     // Если сообщение адресовано акселераторам
            101:
            begin
              // Вывод описания задания в отдельном окне
              hData := LoadResource(hInstance, FindResource(hInstance, 'data1', 'DESCRIPTTR') );    // подгрузка ресурса 'Описание ТР'
              pData := LockResource(hData);        // получение указателя на данные по хэндлу
                                                  // (т.к. для работы с самими данными необходим не хэндл, а указатель)
              MessageBox(0, pData, 'Описание варианта Типового расчёта', mb_ok or MB_ICONINFORMATION);
            end;
            102: MessageBox(0, 'Спасение утопающих - дело рук самих утопающих...', 'HELP', mb_ok or MB_ICONINFORMATION);  // www.ЯПЛАКАЛ... :)
            103: sendmessage(hwnd, wm_close, 0, 0);    // закрытие по "Alt+X"
          end;

          if (loword(wParam) = btnRequest1) or (loword(wParam) = btnRequest2) then begin

            // создание хэндлов строк (имя сервера, раздела и элемента)
            GetDlgItemText(hWnd,Srv,@buffer[1],256);
            hSrv:=DdeCreateStringHandle(idInst,@buffer[1],CP_WINANSI);

            // имя раздела и элемента в зависимости от того, с какой кнопки запрос
            if(loword(wParam) = btnRequest1) then begin

              // Формирование хэндлов по "запросу 1"
              GetDlgItemText(hWnd,topic1,@buffer[2],256);
              hTopic:=DdeCreateStringHandle(idInst,@buffer[2],CP_WINANSI);

              GetDlgItemText(hWnd,item1,@buffer[3],256);
              hItem:=DdeCreateStringHandle(idInst,@buffer[3],CP_WINANSI);

              // определение выбранного типа данных
              if (SendMessage(GetDlgItem(hwnd,format1N), BM_GETCHECK,0,0) <> 0) then selType := floatType
              else if (SendMessage(GetDlgItem(hwnd,format1B), BM_GETCHECK,0,0) <> 0) then selType := BMPType
              else if (SendMessage(GetDlgItem(hwnd,format1P), BM_GETCHECK,0,0) <> 0) then selType := pascalType
              else selType := 1;    // CF_TEXT = 1   НО МОЖНО УКАЗАТЬ pascalType

            end
            else
            begin

              // Формирование хэндлов по "запросу 2"
              GetDlgItemText(hWnd,topic2,@buffer[2],256);
              hTopic:=DdeCreateStringHandle(idInst,@buffer[2],CP_WINANSI);

              GetDlgItemText(hWnd,item2,@buffer[3],256);
              hItem:=DdeCreateStringHandle(idInst,@buffer[3],CP_WINANSI);

              // определение выбранного типа данных
              if (SendMessage(GetDlgItem(hwnd,format2N), BM_GETCHECK,0,0) <> 0) then selType := floatType
              else if (SendMessage(GetDlgItem(hwnd,format2B), BM_GETCHECK,0,0) <> 0) then selType := BMPType
              else if (SendMessage(GetDlgItem(hwnd,format2P), BM_GETCHECK,0,0) <> 0) then selType := pascalType
              else selType := 1;    // CF_TEXT = 1   НО МОЖНО УКАЗАТЬ pascalType
            end;

            hConv := DDEConnect(idInst, hSrv, hTopic, nil);  // установление соединения (в результате в hConv - хэндл текущего соединения)

            bufferMsg := '<<-- DDEConnect              ';        // вывод сообщения о запросе соединения с сервером          WM_DDE_INITIATE
            SendDlgItemMessage(hwnd, MsgServer, LB_ADDSTRING, 0, integer(@bufferMsg)+1);
            bufferMsg := '                                    ';

            if (hConv = 0) then begin  // вывод сообщения о том, что сервер не отвечает на запрос
              bufferMsg := 'S: ***Нет ответа сервера...';
              SendDlgItemMessage(hwnd, MsgServer, LB_ADDSTRING, 0, integer(@bufferMsg)+1);
            end
            else begin
              SetLength(bufferMsg,15);
              bufferMsg := '+>> Подтверждение подкл.';              // вывод сообщения об "успешном" подключении  WM_DDE_ACK
              //bufferMsg := copy(bufferMsg,1,15);
              SendDlgItemMessage(hwnd, MsgServer, LB_ADDSTRING, 0, integer(@bufferMsg)+1);
              bufferMsg := '                                    ';

              // запрос на получение данных от сервера (запрос синхронный - выход _____)
              hDDEData := DdeClientTransaction(nil, 0, hConv, hItem, selType, XTYP_REQUEST, 3000, nil); // в результате в hDDEData - указатель на данные

              bufferMsg := '<<-- DdeClientTransaction';    // вывод сообщения об отправке запроса серверу   WM_DDE_REQUEST(item)
              SendDlgItemMessage(hwnd, MsgServer, LB_ADDSTRING, 0, integer(@bufferMsg)+1);
              bufferMsg := '                                    ';

              // проверка результата отправления запроса на сервер
              if hDDEData <> 0 then
              begin
                bufferMsg := '+>> Получен хэндл данных';       // получен "успешный" ответ от сервера      WM_DDE_DATA(item)
                SendDlgItemMessage(hwnd, MsgServer, LB_ADDSTRING, 0, integer(@bufferMsg)+1);
                bufferMsg := '                                    ';

                dataSize:=0;                                  // "очистка" размера данных
                dataSize:=DdeGetData(hDDEData,nil,300,0);     // ф-я вернёт объем данный в байтах, которые будут скопированы в буфер
                                                              // "300" - максимальный объём для копироваия в байтах (хотя, как будто бы, плевал он на это...)
                ShowMessage('Размер полученного блока данных: ' + IntToStr(dataSize) + ' байт.');      // для отладки

                // (пере)выделение памяти под копируемую информацию (определённого размера!)
                freemem(pasc);
                pasc:=0;
                getmem(pasc,dataSize);

                DdeGetData(hDDEData,pasc,dataSize,0);      // тут уже копирование в буфер назначения по указателю

                // вывод данных в "окно" пользователю в зависимости от запрошенного типа
                if (selType = 1) then begin   // блоки текста 'CF_TEXT'

                  //hDCListBox = GetDC(GetDlgItem(hInstance,MsgData);
                  //GetTextExtentPoint32(hDCListBox,DataStr,strlen(DataStr), &lpSize);
                  //if (___) then SendDlgItemMessage(hwnd, MsgData, LB_SETHORIZONTALEXTENT, ___, 0);

                  SendDlgItemMessage(hwnd, MsgData, LB_SETHORIZONTALEXTENT, 9350, 0);
                  SendDlgItemMessage(hwnd, MsgData, LB_ADDSTRING, 0, Integer(pasc)); // непосредственно - вывод данных пользователю
                end
                else if (selType = floatType) then begin  // вещественные 'Float10'

                  DataStr := FloatToStr(Extended(pasc^));   // преобразование в строку по указателю
                                                            // т.к. по заданию веществ. число м.б. в т.ч. Ext -> можем смело преобразовывать
                  //ShowMessage(DataStr);
                  SendDlgItemMessage(hwnd, MsgData, LB_ADDSTRING, 0, Integer(@DataStr));  // непосредственно - вывод данных пользователю
                  DataStr := '                                    ';
                  
                end
                else if (selType = pascalType) then begin  // короткие строки (паскаль-строки)

                  DataStr := string(pasc^);  // преобразование в строку по указателю (для коротких паскалевских строк)
                  SendDlgItemMessage(hwnd, MsgData, LB_ADDSTRING, 0, Integer(@DataStr)); // непосредственно - вывод данных пользователю
                  DataStr := '                                    ';

                end
                else begin                                // рисунок BMP  'BitmapFile' - АЛЬТЕРНАТИВА БЛОКАМ ТЕКСТА

                  flagBMP := True;                        // "взведенный" флаг - сигнализатор в wm_paint о том, что необходимо "отрисовать" даннные
                  GetClientRect(hwnd,rect);
                  InvalidateRect(hwnd,@rect,true);        // Перерисовка экрана окна (инициирование wm_paint)

                end;

                DDEFreeDataHandle(hDDEData); // освобождение хэндла данных, полученных от сервера
              end
              else
              begin
                bufferMsg := '+>> Получен "0"-й хэндл';  // получен ответ от сервера об отсутствии запрашиваемых данных   WM_DDE_DATA(negative)
                SendDlgItemMessage(hwnd, MsgServer, LB_ADDSTRING, 0, integer(@bufferMsg)+1);
                bufferMsg := '                                    ';
              end;
            end;

            //DdeFreeStringHandle(idInst,hSrv);     // |удаление хэндлов строк
            //DdeFreeStringHandle(idInst,hTopic);   // |(сервиса, раздела, элемента)
            //DdeFreeStringHandle(idInst,hItem);    // |

            if (hConv <> 0) then begin  // проверяем было ли подключение и если было - инициируем "разрыв"

              bufferMsg := '<<-- DDEDisconnect';       // вывод сообщения о запросе на разрыв соединения к серверу      WM_DDE_TERMINATE
              SendDlgItemMessage(hwnd, MsgServer, LB_ADDSTRING, 0, integer(@bufferMsg)+1);
              bufferMsg := '                                    ';

              // отправка запроса на "разрыв" соединения с последующей проверкой результата
              if(DDEDisconnect(hConv) <> False) then begin
                bufferMsg := '+>> Подтверждение откл.';       // "подтверждение" разрыва соединения сервером    WM_DDE_TERMINATE
                SendDlgItemMessage(hwnd, MsgServer, LB_ADDSTRING, 0, integer(@bufferMsg)+1);
                bufferMsg := '                                    ';
              end
              else  begin
                bufferMsg := 'S: ***Поломка соединения...';  // ежели от сервера тишина...
                SendDlgItemMessage(hwnd, MsgServer, LB_ADDSTRING, 0, integer(@bufferMsg)+1);
                bufferMsg := '                                    ';
              end;
              
              hConv:=0;  // обнуление хэндла текущего соединения
            end;
          end;

          // очистка окон данных и прохождения сообщений DDE
          if (loword(wParam) = btnReset) then begin
            // выяснение количества строк в "окнах"
            lenDDE := SendDlgItemMessage(hwnd,MsgServer,LB_GETCOUNT,0,0);
            lenData := SendDlgItemMessage(hwnd,MsgData,LB_GETCOUNT,0,0);

            while ((lenDDE <> 0) or (lenData <> 0)) do begin
              // удаление "нижней" строки из окон
              if (lenDDE <> 0) then SendDlgItemMessage(hwnd,MsgServer,LB_DELETESTRING,lenDDE-1,0);
              if (lenData <> 0) then SendDlgItemMessage(hwnd,MsgData,LB_DELETESTRING,lenData-1,0);
              // выяснение количества оставшихся строк в окне
              lenDDE := SendDlgItemMessage(hwnd,MsgServer,LB_GETCOUNT,0,0);;
              lenData := SendDlgItemMessage(hwnd,MsgData,LB_GETCOUNT,0,0);;
            end;

            InvalidateRect(hwnd,nil,true);         // Перерисовка экрана окна ("сброс" графических данных)
          end;
        end;

        1:
        begin
          if (lparam = 0) then begin
            case loword(wparam) of
              101: PostMessage(hwnd, wm_command, 101, 0);     //  "Q" - Описание
              103: PostMessage(hwnd, wm_command, 103, 0);     // "ALT+X" - Выход
            end;
          end;
        end;

      end;
    end;


    wm_paint:
    begin
      hDC:=BeginPaint(hWnd,ps);
      GetClientRect(hWnd,rect);

        // отрисовка графических данных, если флаг "взведён"
        if (flagBMP = True) then begin
          integer(bmi):=integer(pasc)+sizeof(TBitmapFileheader);
          integer(BMPdata):=integer(pasc)+TBitmapFileheader(pasc^).bfOffBits;

          stretchDiBits(hDC, 495, 130, 190, 175,                               // координаты и размеры целевого буфера (область окна)
                        0,0,bmi^.bmiheader.biWidth, bmi^.bmiheader.biHeight,  // координаты и размеры исходного буфера
                        BMPdata,bmi^,DIB_RGB_COLORS,srccopy);

          flagBMP := False;        // после отрисовки графических данных - сброс флага
        end;

      EndPaint(hWnd,ps);
    end;


    wm_close:
    begin     // Органы управления уничтожаются автоматически

      if (hConv <> 0) then DDEDisconnect(hConv);      // разрыв соединения с сервером
      DdeUninitialize(idInst);                        // освобождение системных ресурсов
                                                      // захваченных под DDEML
      FreeResource(hData);                            // освободжение ресурсов
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
