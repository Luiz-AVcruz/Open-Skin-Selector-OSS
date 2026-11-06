-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.

if client then
local menuOpen = false
local tab = "skins"
local filter = "all"
local selectedId = ""
local scroll = 0
local maxScroll = 0
local capturingShortcut = false
local clickConsumed = false
local suppressPointer = false
local searchQuery = ""
local searchActive = false
local searchFocusRequest = false
local mouseX, mouseY = 0, 0
local window = {x=0, y=0, w=0, h=0}
local view = {x=0, y=0, w=0, h=0}
local contentClip = nil
local cardViewportY = 0
local pageScroll = 0
local lastCards = {}
local skinLayout = {}

local C = {
    back={0.075,0.075,0.072,0.98}, side={0.105,0.105,0.099,1},
    line={0.27,0.27,0.25,1}, surface={0.16,0.16,0.15,1}, hover={0.21,0.21,0.19,1},
    selected={0.24,0.22,0.16,1}, text={0.95,0.94,0.91,1}, muted={0.69,0.69,0.65,1},
    accent={0.96,0.78,0.37,1}, disabled={0.39,0.39,0.36,1}, success={0.59,0.80,0.61,1}
}

local function T(key, ...)
    return OSS.text(key, ...)
end

local function inside(x, y, w, h, px, py)
    return px >= x and py >= y and px < x+w and py < y+h
end

local function color(c)
    UiColor(c[1],c[2],c[3],c[4] or 1)
end

local function drawRect(x,y,w,h,c)
    if w <= 0 or h <= 0 then return end
    UiPush(); UiTranslate(x,y); color(c); UiRect(w,h); UiPop()
end

local function drawText(x,y,value,size,c,width,bold)
    value=tostring(value or "")
    UiPush(); UiTranslate(x,y); UiAlign("left top")
    UiFont(bold and "bold.ttf" or "regular.ttf",size)
    UiTextDisableWildcards(true); color(c or C.text)
    if width then UiWordWrap(width) end
    UiText(value); UiPop()
end

local function drawTextFit(x,y,value,size,c,width,bold)
    value=tostring(value or "")
    local font=bold and "bold.ttf" or "regular.ttf"
    UiFont(font,size);UiTextDisableWildcards(true)
    local text=value
    local measured=UiGetTextSize(text)
    local tw=type(measured)=="table" and measured[1] or measured
    if (tw or 0)>width then
        local symbols=UiGetSymbolsCount(value)
        local lo,hi,best=0,symbols,"..."
        while lo<=hi do
            local mid=math.floor((lo+hi)/2)
            local candidate=UiTextSymbolsSub(value,1,mid).."..."
            local sizeResult=UiGetTextSize(candidate)
            local candidateWidth=type(sizeResult)=="table" and sizeResult[1] or sizeResult
            if (candidateWidth or 0)<=width then best=candidate;lo=mid+1 else hi=mid-1 end
        end
        text=best
    end
    drawText(x,y,text,size,c,width,bold)
end

local function favoriteKey(id)
    local hex=id:gsub(".",function(byte) return string.format("%02x",string.byte(byte)) end)
    return OSS.root.."favorites."..hex
end

local function isFavorite(id)
    return GetBool(favoriteKey(id))
end

local function setFavorite(id,value)
    local key=favoriteKey(id)
    if value then SetBool(key,true) else ClearKey(key) end
end

local function searchNormalize(value)
    value=tostring(value or ""):lower()
    local fold={
        ["á"]="a",["à"]="a",["â"]="a",["ã"]="a",["ä"]="a",["Á"]="a",["À"]="a",["Â"]="a",["Ã"]="a",["Ä"]="a",
        ["é"]="e",["è"]="e",["ê"]="e",["ë"]="e",["É"]="e",["È"]="e",["Ê"]="e",["Ë"]="e",
        ["í"]="i",["ì"]="i",["î"]="i",["ï"]="i",["Í"]="i",["Ì"]="i",["Î"]="i",["Ï"]="i",
        ["ó"]="o",["ò"]="o",["ô"]="o",["õ"]="o",["ö"]="o",["Ó"]="o",["Ò"]="o",["Ô"]="o",["Õ"]="o",["Ö"]="o",
        ["ú"]="u",["ù"]="u",["û"]="u",["ü"]="u",["Ú"]="u",["Ù"]="u",["Û"]="u",["Ü"]="u",["ç"]="c",["Ç"]="c",
        ["ý"]="y",["ÿ"]="y"
    }
    for accent,plain in pairs(fold) do value=value:gsub(accent,plain) end
    return value
end

local function clippedVisible(x,y,w,h)
    if not contentClip then return true end
    local c=contentClip
    local screenY=y-pageScroll
    return x+w>c.x and x<c.x+c.w and screenY+h>c.y and screenY<c.y+c.h
end

local function button(id,x,y,w,h,text,kind,disabled)
    if not clippedVisible(x,y,w,h) then return false end
    local screenY=y-pageScroll
    local hit = inside(x,screenY,w,h,mouseX,mouseY)
    if contentClip and not inside(contentClip.x,contentClip.y,contentClip.w,contentClip.h,mouseX,mouseY) then hit=false end
    local hover=hit and not disabled
    local clicked=hover and not clickConsumed and not suppressPointer and InputPressed("lmb")
    if clicked then clickConsumed=true end
    local fill=(kind=="active") and C.selected or ((hover or clicked) and C.hover or ((kind=="plain") and C.side or C.surface))
    drawRect(x,y,w,h,fill)
    if kind=="active" then drawRect(x,y,3,h,C.accent) end
    drawText(x+9,y+math.max(5,(h-20)/2),text,16,disabled and C.disabled or C.text,w-18)
    return clicked==true
end

local function currentState()
    if client.ossState then return client.ossState() end
    return {current="",saved="",status=client.ossStatus or "idle",detail=client.ossStatusDetail or ""}
end

local function visibleCatalog()
    local result={}
    for _,item in ipairs(OSS.catalog or {}) do
        local accepted=filter=="all" or (filter=="game" and item.origin=="game")
            or (filter=="mods" and item.origin=="mod") or (filter=="favorites" and isFavorite(item.id))
        if accepted and searchQuery~="" then
            accepted=searchNormalize(item.name or item.id):find(searchNormalize(searchQuery),1,true)~=nil
        end
        if accepted and (not item.hidden or item.available==true) then result[#result+1]=item end
    end
    table.sort(result,function(a,b)
        local an=searchNormalize(a.name or a.id)
        local bn=searchNormalize(b.name or b.id)
        if an~=bn then return an<bn end
        return tostring(a.id)<tostring(b.id)
    end)
    return result
end

local function getSelected(list)
    for _,item in ipairs(list) do if item.id==selectedId then return item end end
    if selectedId=="" and #list>0 then selectedId=list[1].id;return list[1] end
end

local function buttonGrid(x,y,w,h,items,value,active)
    return button("filter_"..value,x,y,w,h,items,active and "active" or "plain",false)
end

local function statusLine(state,x,y,w)
    local key=state.status or "idle"
    local messageKey=({saved="saved_status",unavailable="status_unavailable",applied="status_applied",
        following_game="status_following_game"})[key] or key
    local message=T(messageKey)
    if state.detail and state.detail~="" then message=message.."  ·  "..state.detail end
    local c=(key=="apply_failed" or key=="release_failed" or key=="session_timeout" or key=="unavailable" or key=="rejected") and C.accent or C.muted
    drawTextFit(x,y,message,14,c,w,false)
end

local function drawSkinCard(item,x,y,w,h,state)
    lastCards[#lastCards+1]={id=item.id,x=0,y=y,w=w,h=h}
    local isSelected=item.id==selectedId
    local isCurrent=item.id==state.current
    local isSaved=item.id==state.saved
    local enabled=item.available~=false
    local kind=isSelected and "active" or "normal"
    local hitY=mouseY-cardViewportY+scroll
    local hover=inside(x,y,w,h,mouseX,hitY) and enabled
    if contentClip and not inside(contentClip.x,contentClip.y,contentClip.w,contentClip.h,mouseX,mouseY) then hover=false end
    local fill=kind=="active" and C.selected or (hover and C.hover or C.surface)
    drawRect(x,y,w,h,fill)
    if isSelected then drawRect(x,y,3,h,C.accent) end

    local imageSize=48
    local preview=tostring(item.preview or "")
    if preview~="" and HasFile(preview) then
        local iw,ih=UiGetImageSize(preview)
        if iw and ih and iw>0 and ih>0 then
            local scale=math.min(imageSize/iw,imageSize/ih)
            UiPush();UiTranslate(x+8+(imageSize-iw*scale)/2,y+8+(imageSize-ih*scale)/2);UiScale(scale,scale)
            UiImage(preview);UiPop()
        end
    else
        drawRect(x+8,y+8,imageSize,imageSize,C.side)
        drawText(x+14,y+22,"•",18,C.muted,imageSize-12,true)
    end

    local tx=x+imageSize+18
    local tw=w-imageSize-28
    local favW=64
    local textW=math.max(8,tw-favW-6)
    drawTextFit(tx,y+8,item.name or item.id,16,enabled and C.text or C.disabled,textW,true)
    local tags={}
    if isCurrent then tags[#tags+1]=T("current_label") end
    if isSaved then tags[#tags+1]=T("saved_label") end
    if not enabled then tags[#tags+1]=T("unavailable_label") end
    if #tags==0 then tags[1]=item.origin=="game" and T("origin_game") or T("origin_mod") end
    drawTextFit(tx,y+32,table.concat(tags," · "),12,C.muted,textW,false)

    local favX=x+w-favW-4
    local favorite=isFavorite(item.id)
    local favLabel=favorite and T("favorite_saved_short") or T("favorite_add_short")
    if button("favorite_"..favoriteKey(item.id),favX,y+11,favW,30,favLabel,favorite and "active" or "plain",false) then
        setFavorite(item.id,not favorite)
        return
    end
    local clicked=hover and not inside(favX,y+11,favW,30,mouseX,hitY)
        and not clickConsumed and not suppressPointer and InputPressed("lmb")
    if clicked then selectedId=item.id;clickConsumed=true end
end

local function drawSelectedDetailsContent(item,state,x,y,w,h)
    drawRect(x,y,w,h,C.side)
    drawRect(x,y,3,h,C.accent)
    if not item then
        drawText(x+16,y+16,T("choose"),17,C.muted,w-32)
        return false
    end
    if h<150 then
        drawTextFit(x+12,y+7,item.name or item.id,15,C.text,w-24,true)
        local origin=item.origin=="game" and T("origin_game") or T("origin_mod")
        local mark=item.id==state.current and T("current_label") or (item.id==state.saved and T("saved_label") or T("selected"))
        drawTextFit(x+12,y+29,origin.." · "..mark,12,C.muted,w-24,false)
        local description=tostring(item.description or "")
        if description~="" and h>=70 then drawTextFit(x+12,y+47,description,12,C.muted,w-24,false) end
        return item.available~=false
    end
    drawText(x+16,y+14,T("details"),14,C.muted,w-32,true)
    local image=item.preview or ""
    local imageH=math.min(150,math.max(72,h*.30))
    if image~="" and HasFile(image) and w>200 then
        local iw,ih=UiGetImageSize(image)
        if iw and ih and iw>0 and ih>0 then
            local scale=math.min((w-32)/iw,imageH/ih)
            UiPush();UiTranslate(x+16+((w-32)-iw*scale)/2,y+40+(imageH-ih*scale)/2);UiScale(scale,scale)
            UiImage(image);UiPop()
        end
    end
    local nameY=y+40+imageH+8
    drawText(x+16,nameY,item.name or item.id,20,C.text,w-32,true)
    local origin=item.origin=="game" and T("origin_game") or T("origin_mod")
    local available=item.available~=false and T("available") or T("unavailable_label")
    drawText(x+16,nameY+30,origin.." · "..available,14,C.muted,w-32)
    local desc=tostring(item.description or "")
    if desc=="" then desc=T("no_description") end
    UiPush();UiTranslate(x+16,nameY+56);UiAlign("left top");UiFont("regular.ttf",15)
    UiTextDisableWildcards(true);UiWordWrap(w-32);color(C.text);UiWindow(w-32,math.max(32,h-(nameY-y)-72),true,true)
    UiText(desc);UiPop()

    local stateLabel
    if item.id==state.current then stateLabel=T("current_label")
    elseif item.id==state.saved then stateLabel=T("saved_label")
    else stateLabel=T("selected") end
    drawText(x+16,y+h-45,stateLabel,14,item.id==state.current and C.success or C.accent,w-32,true)
    return item.available~=false
end

local function drawSelectedDetails(item,state,x,y,w,h)
    if w<=0 or h<=0 then return false end
    UiPush();UiTranslate(x,y);UiWindow(w,h,true,true)
    local available=drawSelectedDetailsContent(item,state,0,0,w,h)
    UiPop()
    return available
end

local function drawSkins(state)
    lastCards={}
    local list=visibleCatalog()
    local item=getSelected(list)
    local narrow=view.w<620
    local filtersY=0
    local filterGap=6
    local fw=(view.w-filterGap*3)/4
    local filterOptions={{"all",T("all")},{"game",T("game")},{"mods",T("mods")},{"favorites",T("favorites")}}
    for i,option in ipairs(filterOptions) do
        local x=(i-1)*(fw+filterGap)
        if buttonGrid(x,filtersY,fw,30,option[2],option[1],filter==option[1]) then filter=option[1];scroll=0 end
    end

    local searchY=36
    local clearW=38
    local searchW=view.w-clearW-6
    drawRect(0,searchY,searchW,30,C.surface)
    local fieldHit=inside(0,searchY,searchW,30,mouseX,mouseY)
    if fieldHit and InputPressed("lmb") and not clickConsumed then searchFocusRequest=true;clickConsumed=true end
    UiPush();UiTranslate(8,searchY+4);UiFont("regular.ttf",16);UiAlign("left top");UiTextDisableWildcards(true)
    UiColor(1,1,1,1)
    local value,active=UiTextInput(searchQuery,searchW-16,22,searchFocusRequest,false)
    searchFocusRequest=false
    if value~=nil and value~=searchQuery then searchQuery=value;scroll=0 end
    searchActive=active==true
    UiPop()
    if searchQuery=="" and not searchActive then drawText(10,searchY+7,T("search_placeholder"),14,C.muted,searchW-20) end
    if button("clear_search",searchW+6,searchY,clearW,30,"X","plain",searchQuery=="") then
        searchQuery="";scroll=0
    end

    local bodyY=74
    local listW=narrow and view.w or math.min(340,math.max(220,view.w*.42))
    local gap=narrow and 0 or 14
    local detailW=view.w-listW-gap
    local statusY=view.h-32
    local bodyBottom=statusY-16
    local availableBody=math.max(0,bodyBottom-bodyY)
    local listH
    if narrow then
        local detailReserve=math.min(46,availableBody)
        listH=math.min(#list*58,math.max(0,availableBody-detailReserve-8))
    else listH=availableBody end
    local viewportY=bodyY
    cardViewportY=viewportY
    local cellH=58
    local contentHeight=#list*cellH
    local listMax=math.max(0,contentHeight-listH)
    scroll=math.max(0,math.min(scroll,listMax))
    contentClip={x=0,y=viewportY,w=listW,h=listH}
    local oldPageScroll=pageScroll
    pageScroll=scroll-viewportY
    UiPush();UiTranslate(0,viewportY);UiWindow(listW,listH,true,true);UiTranslate(0,-scroll)
    for i,entry in ipairs(list) do
        drawSkinCard(entry,0,(i-1)*cellH,listW,cellH-5,state)
    end
    UiPop();contentClip=nil;pageScroll=oldPageScroll
    if #list==0 then drawText(0,viewportY+10,T("no_skins"),16,C.muted,listW) end

    local detailY,detailH
    if narrow then
        detailY=viewportY+listH+8
        detailH=math.max(0,bodyBottom-detailY)
        drawSelectedDetails(item,state,0,detailY,view.w,detailH)
        maxScroll=listMax
    else
        detailY=bodyY
        detailH=bodyBottom-bodyY
        drawSelectedDetails(item,state,listW+gap,bodyY,detailW,bodyBottom-bodyY)
        maxScroll=listMax
    end

    statusLine(state,0,statusY,view.w)

    skinLayout={statusY=statusY,bodyY=bodyY,bodyBottom=bodyBottom,listY=viewportY,listH=listH,
        detailY=detailY,detailH=detailH,
        searchY=searchY,searchW=searchW,searchH=34,clearX=searchW+6,filterCount=#filterOptions}

end

local function drawSkinFooter()
    local state=currentState()
    local item=getSelected(visibleCatalog())
    local retryStatus=state.status=="apply_failed" or state.status=="session_timeout" or state.status=="rejected"
    local canApply=item~=nil and item.available~=false and (item.id~=state.saved or retryStatus)
    local footerY=window.h-48
    if button("follow_game",view.x,footerY,math.min(240,view.w*.42),34,T("following_game"),"plain",false) then
        client.ossFollowGame();menuOpen=false;selectedId="";searchQuery="";searchActive=false;searchFocusRequest=false
    end
    local applyW=126
    if button("apply",view.x+view.w-applyW,footerY,applyW,34,T("apply"),"active",not canApply) then
        if client.ossSelect(item.id) then menuOpen=false;selectedId="";searchQuery="";searchActive=false;searchFocusRequest=false end
    end
end

local function drawSettings()
    local w=view.w
    drawText(0,0,T("settings_title"),24,C.text,w,true)
    drawRect(0,38,w,1,C.line)
    drawText(0,62,T("language"),16,C.text,w,true)
    local lang=GetString(OSS.root.."language");if lang~="pt" then lang="en" end
    local bw=150
    if button("language_en",0,92,bw,38,T("english"),lang=="en" and "active" or "plain",false) then SetString(OSS.root.."language","en") end
    if button("language_pt",bw+8,92,bw+25,38,T("portuguese"),lang=="pt" and "active" or "plain",false) then SetString(OSS.root.."language","pt") end
    drawText(0,158,T("shortcut"),16,C.text,w,true)
    local shortcut=GetString(OSS.root.."shortcut")
    drawText(0,190,shortcut=="" and "—" or string.upper(shortcut),15,C.muted,180)
    if capturingShortcut then drawText(0,218,T("capture"),14,C.accent,w) end
    if button("set_shortcut",0,250,175,38,T("set_shortcut"),"plain",false) then capturingShortcut=true end
    if button("clear_shortcut",183,250,120,38,T("clear"),"plain",shortcut=="") then
        SetString(OSS.root.."shortcut","");capturingShortcut=false
    end
    local restore=OSS.autoRestore()
    if button("auto_restore",0,312,math.min(w,430),38,T("auto_restore")..": "..T(restore and "enabled" or "disabled"),restore and "active" or "plain",false) then
        SetBool(OSS.root.."auto_restore",not restore)
    end
    drawText(0,364,T("auto_restore_hint"),14,C.muted,w)
    return 414
end

local function drawAbout()
    local y=0
    drawText(0,y,T("about_title"),24,C.text,view.w,true);y=y+44
    drawRect(0,y,view.w,1,C.line);y=y+18
    local rows={T("version",OSS.version),T("author"),T("license"),T("permission"),T("source"),T("workshop"),T("app_about")}
    for _,row in ipairs(rows) do
        drawText(0,y,row,16,C.text,view.w);y=y+34
    end
    return y
end

local function drawMenu()
    pageScroll=0
    local canvas=UiCanvasSize()
    local W=math.min(940,math.max(350,canvas.w*.88))
    local H=math.min(650,math.max(240,canvas.h*.86))
    local ox=(canvas.w-W)/2;local oy=(canvas.h-H)/2
    window={x=ox,y=oy,w=W,h=H}
    local narrow=W<740
    local side=narrow and 0 or 132
    local header=52
    local navH=narrow and 44 or 0
    UiPush();UiTranslate(ox,oy);UiAlign("left top");UiWindow(W,H,true)
    mouseX,mouseY=UiGetMousePos()
    drawRect(0,0,W,H,C.back);drawRect(0,0,W,header,C.side);drawRect(0,header-1,W,1,C.line)
    drawRect(17,15,4,22,C.accent);drawText(29,14,T("app"),20,C.text,W-165,true)
    if button("close",W-104,10,88,32,T("close"),"plain",false) then
        menuOpen=false;capturingShortcut=false;selectedId="";searchQuery="";searchActive=false;searchFocusRequest=false
    end

    if not narrow then
        drawRect(0,header,side,H-header,C.side);drawRect(side,header,1,H-header,C.line)
        local tabs={{"skins",T("skins")},{"settings",T("settings")},{"about",T("about")}}
        for i,t in ipairs(tabs) do
            local yy=header+18+(i-1)*46
            if button("tab_"..t[1],12,yy,side-24,38,t[2],tab==t[1] and "active" or "plain",false) then
                if tab~="skins" or t[1]~="skins" then searchActive=false;searchFocusRequest=false end
                tab=t[1];scroll=0;maxScroll=0
            end
        end
        drawText(18,H-29,T("version",OSS.version),12,C.muted,side-32)
    else
        local tabs={{"skins",T("skins")},{"settings",T("settings")},{"about",T("about")}}
        local gap=5;local bw=(W-32-gap*2)/3
        for i,t in ipairs(tabs) do
            if button("tab_"..t[1],16+(i-1)*(bw+gap),header+5,bw,34,t[2],tab==t[1] and "active" or "plain",false) then
                if tab~="skins" or t[1]~="skins" then searchActive=false;searchFocusRequest=false end
                tab=t[1];scroll=0;maxScroll=0
            end
        end
    end

    view={x=side+18,y=header+navH+15,w=W-side-36,h=H-header-navH-85}
    if view.h<100 then view.h=100 end
    local panelMouseX,panelMouseY=mouseX,mouseY
    mouseX,mouseY=panelMouseX-view.x,panelMouseY-view.y
    UiPush();UiTranslate(view.x,view.y);UiWindow(view.w,view.h,true,true)
    local pageHeight=0
    if tab=="skins" then
        pageScroll=0;drawSkins(currentState())
    else
        pageScroll=scroll
        contentClip={x=0,y=0,w=view.w,h=view.h}
        UiPush();UiTranslate(0,-scroll)
        if tab=="settings" then pageHeight=drawSettings() else pageHeight=drawAbout() end
        UiPop();contentClip=nil
        maxScroll=math.max(0,pageHeight-view.h)
        scroll=math.max(0,math.min(scroll,maxScroll))
    end
    UiPop()
    mouseX,mouseY=panelMouseX,panelMouseY
    if tab=="skins" then drawSkinFooter() end
    UiPop()
end

function client.ossMenuTick(dt)
    if GetString(OSS.root.."language")=="" then SetString(OSS.root.."language","en") end
    if not menuOpen then
        if PauseMenuButton(T("pause"),"bottom_bar") then
            menuOpen=true;tab="skins";scroll=0
            searchQuery="";searchActive=false;searchFocusRequest=false
            client.ossRefreshCatalog()
            local state=currentState()
            selectedId=state.saved~="" and state.saved or (state.current or "")
            suppressPointer=true
        end
        local shortcut=GetString(OSS.root.."shortcut")
        if shortcut~="" and InputPressed(shortcut) then
            menuOpen=not menuOpen;tab="skins";scroll=0;suppressPointer=true
            if menuOpen then
                searchQuery="";searchActive=false;searchFocusRequest=false
                client.ossRefreshCatalog()
                local state=currentState()
                selectedId=state.saved~="" and state.saved or (state.current or "")
            else selectedId="" end
        end
        return
    end

    if capturingShortcut and InputPressed("any") then
        local key=string.lower(InputLastPressedKey() or "")
        if key=="esc" then capturingShortcut=false
        elseif OSS.validShortcut(key) then
            SetString(OSS.root.."shortcut",key);client.ossStatus="shortcut_saved"
            capturingShortcut=false
        else client.ossStatus="invalid_key";capturingShortcut=false end
    elseif InputPressed("esc") then
        if capturingShortcut then capturingShortcut=false
        else menuOpen=false;selectedId="";searchQuery="";searchActive=false;searchFocusRequest=false end
    end

    if not capturingShortcut then
        local dy=InputValue("mousewheel") or 0
        if dy~=0 then scroll=math.max(0,math.min(maxScroll,scroll-dy*48)) end
    end
end

function client.ossMenuDraw()
    clickConsumed=false
    if menuOpen then UiMakeInteractive();drawMenu() end
    suppressPointer=false
end

OSS.UI={state=function()
    local visibleIds={}
    for _,item in ipairs(visibleCatalog()) do visibleIds[#visibleIds+1]=item.id end
    return {open=menuOpen,tab=tab,filter=filter,selected=selectedId,scroll=scroll,maxScroll=maxScroll,
        capturingShortcut=capturingShortcut,window={x=window.x,y=window.y,w=window.w,h=window.h},
        view={x=view.x,y=view.y,w=view.w,h=view.h},query=searchQuery,searchActive=searchActive,
        cards=lastCards,visibleIds=visibleIds,skinLayout=skinLayout,
        footer={followX=view.x,applyRight=view.x+view.w},nativeFocusRequest=searchFocusRequest}
end}
end -- client context
