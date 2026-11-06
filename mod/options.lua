-- Copyright (C) 2026 Luiz-AVcruz. AGPL-3.0-or-later; see ADDITIONAL-PERMISSION.
-- Classic options context: deliberately independent of client/server and gameplay.
#include "scripts/common.lua"
#include "scripts/strings.lua"

local capturing=false
local message=""
local messageKey=nil
local scroll=0
local maxScroll=0
local pressed=false
local consumed=false
local pointerX,pointerY=0,0
local clip=nil

local function text(x,y,value,size,width,muted)
    UiPush();UiTranslate(x,y);UiAlign("left top");UiFont("regular.ttf",size)
    UiTextDisableWildcards(true);UiColor(muted and .70 or .95,muted and .70 or .95,muted and .67 or .91)
    UiWordWrap(width);UiText(value);UiPop()
end

local function rect(x,y,w,h,r,g,b)
    UiPush();UiTranslate(x,y);UiColor(r,g,b,1);UiRect(w,h);UiPop()
end

local function button(x,y,w,label,active,disabled)
    local inside=pointerX>=x and pointerX<x+w and pointerY>=y and pointerY<y+36
    if clip and (pointerY<clip.top or pointerY>=clip.bottom) then inside=false end
    rect(x,y,w,36,active and .24 or .16,active and .22 or .16,active and .16 or .15)
    text(x+10,y+8,label,16,w-20,disabled)
    if inside and pressed and not consumed and not disabled then consumed=true;return true end
    return false
end

function draw()
    local T=OSS.text
    pressed=InputPressed("lmb");consumed=false
    if InputPressed("esc") then
        if capturing then capturing=false;message="";messageKey=nil else Menu();return end
    elseif capturing then
        local key=OSS.pressedShortcutKey()
        if key=="esc" then capturing=false;message="";messageKey=nil
        elseif key~="" then
            messageKey=key:upper()
            if OSS.validShortcut(key) then
                SetString(OSS.root.."shortcut",key);message="shortcut_saved_key";capturing=false
            else message="shortcut_rejected_key" end
        end
    end
    local canvas=UiCanvasSize()
    local width=math.min(760,canvas.w-32)
    local height=math.min(670,canvas.h-32)
    local contentH=math.max(100,height-162)
    maxScroll=math.max(0,516-contentH)
    scroll=math.max(0,math.min(maxScroll,scroll-InputValue("mousewheel")*48))
    UiPush();UiTranslate((canvas.w-width)/2,(canvas.h-height)/2);UiAlign("left top")
    UiWindow(width,height,true)
    pointerX,pointerY=UiGetMousePos()
    rect(0,0,width,height,.075,.075,.072)
    text(20,15,T("app"),26,width-40,false)
    text(20,49,T("options_title"),17,width-40,true)
    local contentY=82
    local oldX,oldY=pointerX,pointerY
    pointerX,pointerY=pointerX-20,pointerY-contentY+scroll
    clip={top=scroll,bottom=scroll+contentH}
    UiPush();UiTranslate(20,contentY);UiWindow(width-40,contentH,true,true);UiTranslate(0,-scroll)
    local w=width-40
    text(0,0,T("language"),17,w,false)
    local lang=GetString(OSS.root.."language")
    local half=(w-10)/2
    if button(0,28,half,T("english"),lang~="pt") then SetString(OSS.root.."language","en") end
    if button(half+10,28,half,T("portuguese"),lang=="pt") then SetString(OSS.root.."language","pt") end
    local shortcut=GetString(OSS.root.."shortcut")
    text(0,84,T("shortcut")..": "..(shortcut~="" and shortcut:upper() or "—"),17,w,false)
    text(0,112,capturing and T("capture") or T("options_hint"),14,w,true)
    if button(0,164,half,T("set_shortcut")) then capturing=true;message="";messageKey=nil end
    if button(half+10,164,half,T("clear"),false,shortcut=="") then
        SetString(OSS.root.."shortcut","");capturing=false;message="shortcut_cleared";messageKey=nil
    end
    local restore=OSS.autoRestore()
    if button(0,224,w,T("auto_restore")..": "..T(restore and "enabled" or "disabled"),restore) then
        SetBool(OSS.root.."auto_restore",not restore)
    end
    text(0,270,T("auto_restore_hint"),14,w,true)
    text(0,332,T("saved_skin"),17,w,false)
    UiPush();UiTranslate(0,360);UiWindow(w,30,true,true)
    text(0,0,GetString(OSS.root.."character")~="" and GetString(OSS.root.."character") or T("no_saved_skin"),14,w,true)
    UiPop()
    if button(0,402,w,T("clear_saved_skin"),false,GetString(OSS.root.."character")=="") then
        ClearKey(OSS.root.."character");message="saved_skin_cleared";messageKey=nil
    end
    text(0,448,T("clear_saved_skin_hint"),14,w,true)
    UiPop();clip=nil
    pointerX,pointerY=oldX,oldY
    if message~="" then text(20,height-72,messageKey and T(message,messageKey) or T(message),13,width-40,true) end
    text(20,height-34,T("version",OSS.version),13,width-190,true)
    if button(width-146,height-48,126,T("close")) then Menu() end
    UiPop()
end
