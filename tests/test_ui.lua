-- Offline interaction contract for the Open Skin Selector client UI.
local function check(condition,message)
    if not condition then error(message or "assertion failed",2) end
end

local keys={}
local canvasMouse={x=0,y=0}
local transform={x=0,y=0}
local transformStack={}
local lastKey=""
local wheel=0
local nativeInput={active=false,nextValue=nil,focusRequests=0}
local registry={}
local drawnTexts={}
local openPause=false
local appCalls={select=0,follow=0,refresh=0}
local state={current="sven_lagom",saved="sven_lagom",status="idle",detail=""}

OSS={version="1.0.0",root="savegame.mod.openskinselector.",catalog={},byId={}}
dofile("mod/scripts/common.lua")
client={}
function GetString(key) return registry[key] or "" end
function SetString(key,value) registry[key]=value end
function GetBool(key) return registry[key]==true end
function HasKey(key) return registry[key]~=nil end
function SetBool(key,value) registry[key]=value==true end
function ClearKey(key) registry[key]=nil end
function InputPressed(key) return keys[key]==true end
function InputValue(key) if key=="mousewheel" then return wheel end return 0 end
function InputLastPressedKey() return lastKey end
function PauseMenuButton() local v=openPause;openPause=false;return v end
local canvas={w=1280,h=720}
function UiCanvasSize() return canvas end
function UiGetMousePos() return canvasMouse.x-transform.x,canvasMouse.y-transform.y end
function HasFile() return false end
function UiColor() end
function UiPush() transformStack[#transformStack+1]={x=transform.x,y=transform.y} end
function UiPop() local previous=table.remove(transformStack);transform.x,transform.y=previous.x,previous.y end
function UiTranslate(x,y) transform.x=transform.x+(x or 0);transform.y=transform.y+(y or 0) end
function UiRect() end
function UiAlign() end
function UiFont() end
function UiTextDisableWildcards() end
function UiWordWrap() end
function UiText(value) drawnTexts[#drawnTexts+1]=value end
function UiGetTextSize(value) return #tostring(value)*8,16 end
function UiGetSymbolsCount(value)
    local _,count=tostring(value):gsub("[^%128-%191]","")
    return count
end
function UiTextSymbolsSub(value,start,count)
    local starts={}
    for i=1,#value do
        local byte=value:byte(i)
        if byte<128 or byte>=192 then starts[#starts+1]=i end
    end
    if count<=0 or not starts[start] then return "" end
    local last=starts[start+count] and starts[start+count]-1 or #value
    return value:sub(starts[start],last)
end
function UiTextInput(value,width,height,focus,hideCursor)
    if focus then nativeInput.active=true;nativeInput.focusRequests=nativeInput.focusRequests+1 end
    local result=nativeInput.nextValue
    nativeInput.nextValue=nil
    return result or value,nativeInput.active
end
function UiWindow() end
function UiMakeInteractive() end
function UiImage() end
function UiGetImageSize() return 128,128 end
function UiScale() end

function client.ossState() return state end
function client.ossRefreshCatalog() appCalls.refresh=appCalls.refresh+1 end
function client.ossSelect(id) appCalls.select=appCalls.select+1;appCalls.lastId=id;return true end
function client.ossFollowGame() appCalls.follow=appCalls.follow+1 end

OSS.catalog={
    {id="sven_lagom",name="Sven",description="Default body",origin="game",available=true,hidden=false},
    {id="mod.miku",name="Miku",description="A mod character",origin="mod",available=true,hidden=false},
    {id="locked",name="Locked",description="Unavailable",origin="game",available=false,hidden=false},
    {id="unlockable",name="Unlockable",description="Available but hidden until unlocked",origin="game",available=true,hidden=true},
    {id="secret",name="Hidden",description="Hidden character",origin="game",available=false,hidden=true},
    {id="mod.cafe",name="Café Especial 100%",description="Acentuação e busca literal",origin="mod",available=true,hidden=false},
    {id="mod.long",name="Kurosaki Koyuki (Bunnysuit) original extra long title",description="Long name",origin="mod",available=true,hidden=false},
}
for _,item in ipairs(OSS.catalog) do OSS.byId[item.id]=item end

dofile("mod/scripts/strings.lua")
dofile("mod/scripts/ui.lua")

local function drawAtCanvas(x,y)
    canvasMouse.x,canvasMouse.y=x,y
    client.ossMenuDraw()
    keys.lmb=nil
end

local function atView(x,y)
    local s=OSS.UI.state()
    return s.window.x+s.view.x+x,s.window.y+s.view.y+y
end

local function pressCanvas(x,y)
    keys.lmb=true;drawAtCanvas(x,y)
end

local function pressView(x,y)
    local cx,cy=atView(x,y)
    pressCanvas(cx,cy)
end

local function card(id)
    for _,item in ipairs(OSS.UI.state().cards) do if item.id==id then return item end end
end

local function clickCard(id)
    local item=card(id)
    check(item~=nil,"skin card exists: "..id)
    local layout=OSS.UI.state().skinLayout
    pressView(item.x+110,layout.listY+item.y+25)
end

local function clickFavorite(id)
    local item=card(id)
    check(item~=nil,"favorite card exists: "..id)
    local layout=OSS.UI.state().skinLayout
    pressView(item.x+item.w-24,layout.listY+item.y+26)
end

local function isFavoriteForTest(id)
    local hex=id:gsub(".",function(byte) return string.format("%02x",string.byte(byte)) end)
    return GetBool(OSS.root.."favorites."..hex)
end

client.ossMenuTick(0)
openPause=true
client.ossMenuTick(0)
check(OSS.UI.state().open,"pause-menu button opens the selector")
check(appCalls.refresh==1,"opening refreshes the local catalog")
drawAtCanvas(180,60) -- Consume the open frame so its original click cannot select a tile.

clickCard("mod.miku")
check(OSS.UI.state().selected=="mod.miku","click across the skin tile selects it")
check(appCalls.select==0,"choosing a tile does not apply immediately")

-- Filtering must not silently replace an unapplied choice.
pressView(310,15)
check(OSS.UI.state().filter=="game","the game filter changes the visible list")
check(OSS.UI.state().selected=="mod.miku","filtering preserves the pending selection")
pressView(12,15)
check(OSS.UI.state().filter=="all","the all filter restores the full list")

-- Apply lives in the footer outside the clipped content view.
local applyX,applyY=OSS.UI.state().window.x+940-18-63,OSS.UI.state().window.y+619-48+17
pressCanvas(applyX,applyY)
check(appCalls.select==1 and appCalls.lastId=="mod.miku","Apply commits the selected skin")
check(not OSS.UI.state().open,"successful apply closes the panel")

-- Selection is only a draft until Apply; Escape drops the draft.
openPause=true;client.ossMenuTick(0);drawAtCanvas(180,60)
clickCard("mod.miku")
check(OSS.UI.state().selected=="mod.miku","draft selection can be made after reopening")
keys.esc=true;client.ossMenuTick(0);keys.esc=nil
check(not OSS.UI.state().open,"Escape closes the selector")
check(appCalls.select==1,"Escape discards the draft without changing the saved skin")

-- Unlocked characters may stay hidden in the registry while still being selectable.
openPause=true;client.ossMenuTick(0);drawAtCanvas(180,60)
clickCard("unlockable")
check(OSS.UI.state().selected=="unlockable","an available hidden registry character is listed")
keys.esc=true;client.ossMenuTick(0);keys.esc=nil

-- Narrow layout stays within the canvas and still responds to tile selection.
canvas={w=640,h=480}
openPause=true;client.ossMenuTick(0);drawAtCanvas(20,20)
local small=OSS.UI.state()
check(small.window.x>=0 and small.window.y>=0,"narrow panel is centered within canvas")
check(small.window.w<=640 and small.window.h<=480,"narrow panel does not exceed canvas")
check(small.view.w>0 and small.view.h>0,"narrow panel keeps a usable viewport")

-- Settings controls share the transformed pointer coordinates and remain scrollable.
local narrowTabX=small.window.x+16+(small.window.w-32-10)/3+5+(small.window.w-32-10)/6
local narrowTabY=small.window.y+52+5+17
pressCanvas(narrowTabX,narrowTabY)
check(OSS.UI.state().tab=="settings","narrow Settings tab responds at canvas coordinates")
drawAtCanvas(narrowTabX,narrowTabY)
local settings=OSS.UI.state()
local clearX,clearY=settings.window.x+settings.view.x+243,settings.window.y+settings.view.y+269
pressCanvas(clearX,clearY)
check(not OSS.UI.state().capturingShortcut,"a shortcut control outside the viewport cannot be clicked")
wheel=-5;client.ossMenuTick(0);wheel=0;drawAtCanvas(narrowTabX,narrowTabY)
settings=OSS.UI.state()
check(settings.scroll>0,"Settings content scrolls when it exceeds the narrow viewport")

canvas={w=1280,h=720}
drawAtCanvas(400,300)
settings=OSS.UI.state()
local wideTabX=settings.window.x+35
local wideTabY=settings.window.y+52+18+46+19
pressCanvas(wideTabX,wideTabY)
check(OSS.UI.state().tab=="settings","wide Settings tab responds in panel coordinates")
drawAtCanvas(wideTabX,wideTabY)
settings=OSS.UI.state()
check(OSS.text("app")=="Open Skin Selector","English is the default")
pressView(245,111)
check(OSS.text("apply")=="Aplicar","Portuguese can be set through the UI")
pressView(75,111)
check(OSS.text("apply")=="Apply","English can be restored through the UI")

pressView(87,269)
check(OSS.UI.state().capturingShortcut,"Set shortcut begins key capture")
lastKey="f6";client.ossMenuTick(0);lastKey=""
check(GetString(OSS.root.."shortcut")=="f6","captured key is saved")
pressView(87,269)
keys.any=true;client.ossMenuTick(0);keys.any=nil
check(OSS.UI.state().capturingShortcut,"empty aggregate event does not cancel binding")
lastKey="lmb";client.ossMenuTick(0);lastKey=""
check(OSS.UI.state().capturingShortcut,"mouse does not cancel binding")
lastKey="w";client.ossMenuTick(0);lastKey=""
check(OSS.UI.state().capturingShortcut and OSS.UI.state().shortcutFeedback:find("W",1,true),"rejected key is reported while capture remains active")
keys.f7=true;lastKey="lmb";client.ossMenuTick(0);keys.f7=nil;lastKey=""
check(GetString(OSS.root.."shortcut")=="f7","specific key delivery captures when last-input channel reports mouse")
pressView(87,269)
lastKey="f6";drawAtCanvas(500,250);lastKey=""
check(GetString(OSS.root.."shortcut")=="f6" and not OSS.UI.state().capturingShortcut,"draw-phase keyboard delivery can finish binding")
pressView(87,269)
lastKey="esc";keys.any=true;client.ossMenuTick(0);keys.any=nil;lastKey=""
check(GetString(OSS.root.."shortcut")=="f6" and not OSS.UI.state().capturingShortcut,"Escape cancels shortcut capture")
pressView(243,269)
check(GetString(OSS.root.."shortcut")=="","Clear removes the configured shortcut")
SetString(OSS.root.."language","pt")
check(OSS.text("release_failed")=="Preferência removida, mas o personagem anterior não foi restaurado. Use Seguir seleção do jogo novamente ou recarregue o mapa.","release failure explains that the preference was already cleared")
keys.esc=true;client.ossMenuTick(0);keys.esc=nil

-- A failed prior attempt can be explicitly retried even when it matches saved preference.
canvas={w=1280,h=720}
state.status="apply_failed"
openPause=true;client.ossMenuTick(0);drawAtCanvas(180,60)
local retryX,retryY=OSS.UI.state().window.x+940-18-63,OSS.UI.state().window.y+619-48+17
pressCanvas(retryX,retryY)
check(appCalls.select==2 and appCalls.lastId=="sven_lagom","Apply retries the saved skin after a reported failure")

-- Recovery remains available while the session has an unresolved request.
state.status="waiting_session"
openPause=true;client.ossMenuTick(0);drawAtCanvas(180,60)
local followX,followY=OSS.UI.state().window.x+OSS.UI.state().view.x+120,OSS.UI.state().window.y+619-48+17
pressCanvas(followX,followY)
check(appCalls.follow==1,"Follow game remains available while waiting for session ACK")

-- The native text input owns typing, paste and focus; the UI only consumes its returned value.
state.status="idle"
openPause=true;client.ossMenuTick(0);drawAtCanvas(180,60)
local skin=OSS.UI.state()
pressView(skin.skinLayout.searchW/2,skin.skinLayout.searchY+15)
check(nativeInput.active and OSS.UI.state().searchActive,"clicking the search field requests native focus")
check(nativeInput.focusRequests>0,"focus request is pulsed for one native input draw")
nativeInput.nextValue="CAFÉ"
drawAtCanvas(500,250)
check(OSS.UI.state().query=="CAFÉ","native text input updates the transient query")
check(#OSS.UI.state().visibleIds==1 and OSS.UI.state().visibleIds[1]=="mod.cafe","search is case and accent insensitive")

nativeInput.nextValue="100%"
drawAtCanvas(500,250)
check(#OSS.UI.state().visibleIds==1 and OSS.UI.state().visibleIds[1]=="mod.cafe","percent is matched literally")

skin=OSS.UI.state()
local filterW=(skin.view.w-18)/4
pressView(2*(filterW+6)+12,15)
check(OSS.UI.state().filter=="mods" and #OSS.UI.state().visibleIds==1,"search combines with the current origin filter")
local favoriteSelectBefore=OSS.UI.state().selected
local applyBefore=appCalls.select
clickFavorite("mod.cafe")
check(appCalls.select==applyBefore and OSS.UI.state().selected==favoriteSelectBefore,"favoriting never selects or applies a skin")

skin=OSS.UI.state()
pressView(3*(filterW+6)+12,15)
check(OSS.UI.state().filter=="favorites" and #OSS.UI.state().visibleIds==1,"Favorites filter combines with the query")
pressView(skin.skinLayout.clearX+19,skin.skinLayout.searchY+15)
check(OSS.UI.state().query=="" and #OSS.UI.state().visibleIds==1,"clear removes query while retaining the Favorites filter")

pressView(12,15)
check(OSS.UI.state().filter=="all","All filter returns from Favorites")
drawAtCanvas(500,250)
local previousSelection=OSS.UI.state().selected
local selectCount=appCalls.select
clickFavorite("locked")
check(isFavoriteForTest("locked"),"locked but visible skin can be favorited")
check(OSS.UI.state().selected==previousSelection and appCalls.select==selectCount,"favorite action does not select a row")
pressView(3*(filterW+6)+12,15)
check(#OSS.UI.state().visibleIds==2,"Favorites includes available and locked entries")
drawAtCanvas(500,250)

-- Long names are truncated in list rows while the details area keeps the full title.
pressView(12,15)
drawAtCanvas(500,250)
drawnTexts={}
clickCard("mod.long")
local rowTruncated=false
for _,value in ipairs(drawnTexts) do
    if value:find("Kurosaki Koyuki",1,true) and value~="Kurosaki Koyuki (Bunnysuit) original extra long title" then rowTruncated=true end
end
check(rowTruncated,"long skin title is shortened within the list row")
drawnTexts={}
drawAtCanvas(500,250)
local fullTitleCount=0
for _,value in ipairs(drawnTexts) do if value=="Kurosaki Koyuki (Bunnysuit) original extra long title" then fullTitleCount=fullTitleCount+1 end end
check(fullTitleCount==1,"long skin title is clipped in the list and complete in details")

-- Favorites survive a new Lua UI context, including skins temporarily absent from the catalog.
local registryBefore={}
for key,value in pairs(registry) do registryBefore[key]=value end
pressView(0,0) -- No data-changing action; keep the frame sequence deterministic.
keys.esc=true;client.ossMenuTick(0);keys.esc=nil
local savedCatalog=OSS.catalog
local withoutLocked={}
for _,item in ipairs(savedCatalog) do if item.id~="locked" then withoutLocked[#withoutLocked+1]=item end end
OSS.catalog=withoutLocked
dofile("mod/scripts/ui.lua")
openPause=true;client.ossMenuTick(0);drawAtCanvas(180,60)
skin=OSS.UI.state();filterW=(skin.view.w-18)/4
pressView(3*(filterW+6)+12,15)
local absentIds=OSS.UI.state().visibleIds
check(isFavoriteForTest("locked") and #absentIds==1 and absentIds[1]=="mod.cafe","missing favorite remains stored but is not rendered")
OSS.catalog=savedCatalog
drawAtCanvas(500,250)
check(#OSS.UI.state().visibleIds>=2,"returning favorite reappears without rewriting its setting")
for key,value in pairs(registryBefore) do check(registry[key]==value,"favorites do not alter unrelated setting "..key) end

local selectionBeforeRemoval=OSS.UI.state().selected
local appliedBeforeRemoval=appCalls.select
clickFavorite("locked")
drawAtCanvas(500,250)
check(not isFavoriteForTest("locked") and isFavoriteForTest("mod.cafe"),"removing one favorite preserves the others")
check(#OSS.UI.state().visibleIds==1,"removed favorite leaves the Favorites filter")
check(OSS.UI.state().selected==selectionBeforeRemoval and appCalls.select==appliedBeforeRemoval,"unfavoriting never selects or applies a skin")

-- Layout keeps content, status and footer separate across the requested canvases.
for _,size in ipairs({{640,480},{1024,768},{1920,1080},{1440,900}}) do
    canvas={w=size[1],h=size[2]}
    drawAtCanvas(size[1]/2,size[2]/2)
    skin=OSS.UI.state()
    local layout=skin.skinLayout
    check(layout.listY+layout.listH<=layout.bodyBottom,"skin list ends before the status region")
    check(layout.detailY+layout.detailH<=layout.bodyBottom,"skin details end before the status region")
    check(layout.bodyBottom<layout.statusY and layout.statusY<skin.view.h,"status has a reserved line outside content")
    check(skin.footer.followX==skin.view.x and skin.footer.applyRight==skin.view.x+skin.view.w,"footer aligns with content instead of sidebar")
end

-- A long display name remains intact in details and is shortened in its row.
local longItem=card("mod.long")
check(longItem==nil,"Favorites excludes skins that were not marked as favorite")

print("PASS: Open Skin Selector UI interactions and narrow layout")
