function varargout = MPHG_Problem_Specific_settings(varargin)
% MPHG_PROBLEM_SPECIFIC_SETTINGS MATLAB code for MPHG_Problem_Specific_settings.fig
%      MPHG_PROBLEM_SPECIFIC_SETTINGS, by itself, creates a new MPHG_PROBLEM_SPECIFIC_SETTINGS or raises the existing
%      singleton*.
%
%      H = MPHG_PROBLEM_SPECIFIC_SETTINGS returns the handle to a new MPHG_PROBLEM_SPECIFIC_SETTINGS or the handle to
%      the existing singleton*.
%
%      MPHG_PROBLEM_SPECIFIC_SETTINGS('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in MPHG_PROBLEM_SPECIFIC_SETTINGS.M with the given input arguments.
%
%      MPHG_PROBLEM_SPECIFIC_SETTINGS('Property','Value',...) creates a new MPHG_PROBLEM_SPECIFIC_SETTINGS or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before MPHG_Problem_Specific_settings_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to MPHG_Problem_Specific_settings_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help MPHG_Problem_Specific_settings

% Last Modified by GUIDE v2.5 27-Jan-2016 09:37:11

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @MPHG_Problem_Specific_settings_OpeningFcn, ...
                   'gui_OutputFcn',  @MPHG_Problem_Specific_settings_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    try
    gui_mainfcn(gui_State, varargin{:});
    catch
    end
end
% End initialization code - DO NOT EDIT




% --- Executes just before MPHG_Problem_Specific_settings is made visible.
function MPHG_Problem_Specific_settings_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to MPHG_Problem_Specific_settings (see VARARGIN)

data_controller = varargin{1};
if isempty(data_controller.imgdata), 
    errordlg('no data loaded - can not continue'), 
    fh = ancestor(hObject,'figure');     
    delete(fh);
    return, 
end;

handles.data_controller = data_controller;
        % 
        handles.MPHG_chNuc = data_controller.MPHG_chNuc;
        handles.MPHG_chCell = data_controller.MPHG_chCell;
        handles.MPHG_chGran = data_controller.MPHG_chGran;

        handles.saved_MPHG_chNuc = data_controller.MPHG_chNuc;
        handles.saved_MPHG_chCell = data_controller.MPHG_chCell;
        handles.saved_MPHG_chGran = data_controller.MPHG_chGran;
        
        set(handles.edit3,'String',num2str(handles.MPHG_chNuc)); 
        set(handles.edit27,'String',num2str(handles.MPHG_chCell)); 
        set(handles.edit34,'String',num2str(handles.MPHG_chGran));
                        
% Choose default command line output for MPHG_Problem_Specific_settings
handles.output = hObject;

output_value = 1;

handles.output = output_value;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes MPHG_Problem_Specific_settings wait for user response (see UIRESUME)
uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = MPHG_Problem_Specific_settings_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure

% varargout{1} = 1.;
% if isfield(handles,'output')
%     varargout{1} = handles.output;
% end;
varargout = [];
% ????????

function edit3_Callback(hObject, eventdata, handles)
% hObject    handle to edit3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit3 as text
%        str2double(get(hObject,'String')) returns contents of edit3 as a double
data_controller = handles.data_controller;
[~,~,~,sC,~]=size(data_controller.imgdata);
value = fix(str2double(get(hObject,'String')));
if ~isnan(value) && value >= 1 && value <= sC
    handles.MPHG_chNuc = fix(value);
    guidata(hObject,handles);
else
    value = handles.MPHG_chNuc;
    set(hObject,'String',num2str(value));
end
uiresume(handles.figure1);


% --- Executes during object creation, after setting all properties.
function edit3_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% OK
% --- Executes on button press in pushbutton1.
function pushbutton1_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
data_controller = handles.data_controller;
        
        data_controller.MPHG_chNuc = handles.MPHG_chNuc;        
        data_controller.MPHG_chCell = handles.MPHG_chCell;
        data_controller.MPHG_chGran = handles.MPHG_chGran;
           
    fh = ancestor(hObject,'figure');     
    delete(fh);

% Cancel    
% --- Executes on button press in pushbutton2.
function pushbutton2_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    data_controller = handles.data_controller;
        data_controller.MPHG_chNuc = handles.saved_MPHG_chNuc;        
        data_controller.MPHG_chCell = handles.saved_MPHG_chCell;
        data_controller.MPHG_chGran = handles.saved_MPHG_chGran;        
    fh = ancestor(hObject,'figure');     
    delete(fh);



function edit27_Callback(hObject, eventdata, handles)
% hObject    handle to edit27 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit27 as text
%        str2double(get(hObject,'String')) returns contents of edit27 as a double
data_controller = handles.data_controller;
[~,~,~,sC,~]=size(data_controller.imgdata);
value = fix(str2double(get(hObject,'String')));
if ~isnan(value) && value >= 1 && value <= sC
    handles.MPHG_chCell = fix(value);
    guidata(hObject,handles);
else
    value = handles.MPHG_chCell;
    set(hObject,'String',num2str(value));
end
uiresume(handles.figure1);

% --- Executes during object creation, after setting all properties.
function edit27_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit27 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function edit34_Callback(hObject, eventdata, handles)
% hObject    handle to edit33 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit33 as text
%        str2double(get(hObject,'String')) returns contents of edit33 as a double
data_controller = handles.data_controller;
[~,~,~,sC,~]=size(data_controller.imgdata);
value = fix(str2double(get(hObject,'String')));
if ~isnan(value) && value >= 1 && value <= sC
    handles.MPHG_chGran = fix(value);
    guidata(hObject,handles);
else
    value = handles.MPHG_chGran;
    set(hObject,'String',num2str(value));
end
uiresume(handles.figure1);

% --- Executes during object creation, after setting all properties.
function edit34_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit33 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
