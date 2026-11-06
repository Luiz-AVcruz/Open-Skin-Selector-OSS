-- The manager's options screen must load with no client/server/gameplay context.
local count=0
local function check(value,message) count=count+1;assert(value,message) end
local root="savegame.mod.openskinselector."
local storage={[root.."character"]="steam-42.Chell",[root.."favorites.61"]=true,
    ["savegame.tool.sledge.enabled"]=true}
local keys,pressedKey,wheel,mouse,canvas={},"",0,{x=-1,y=-1},{w=1280,h=800}
local xy={x=0,y=0};local stack={};local closes=0
local env=setmetatable({},{__index=function(_,key)
    if key=="client" or key=="server" or key=="shared" then return nil end
    if key=="GetLocalPlayer" or key=="SetPlayerCharacter" or key=="ServerCall" then
        error("Options accessed gameplay API: "..key)
    end
    return _G[key]
end})
env._G=env
function env.GetString(k) return storage[k] or "" end
function env.GetBool(k) return storage[k]==true end
function env.HasKey(k) return storage[k]~=nil end
function env.SetString(k,v) assert(k:sub(1,#root)==root);storage[k]=v end
env.SetBool=env.SetString
function env.ClearKey(k) assert(k==root.."character");storage[k]=nil end
function env.InputPressed(k)return keys[k] or false end
function env.InputLastPressedKey()return pressedKey end
function env.InputValue(k)return k=="mousewheel" and wheel or 0 end
function env.UiCanvasSize()return canvas end
function env.UiGetMousePos()return mouse.x-xy.x,mouse.y-xy.y end
function env.UiPush()stack[#stack+1]={x=xy.x,y=xy.y}end
function env.UiPop()xy=table.remove(stack)end
function env.UiTranslate(x,y)xy.x=xy.x+(x or 0);xy.y=xy.y+(y or 0)end
for _,name in ipairs({"UiAlign","UiFont","UiTextDisableWildcards","UiColor","UiWordWrap","UiText","UiRect","UiWindow"})do env[name]=function()end end
function env.Menu()closes=closes+1 end
local chunk=assert(loadfile(assert(arg[2],"Run via tools/check.py")));setfenv(chunk,env);chunk()
check(type(env.draw)=="function" and not env.client and not env.server,"classic options loaded without gameplay")
local function frame() env.draw();keys={};wheel=0;pressedKey="" end
local function click(x,y)
    local w,h=math.min(760,canvas.w-32),math.min(670,canvas.h-32)
    mouse={x=(canvas.w-w)/2+x,y=(canvas.h-h)/2+y};keys.lmb=true;frame()
end
frame();check(env.OSS.autoRestore(),"missing setting preserves automatic restoration by default")
-- Coordinates refer to the rendered panel, with content beginning at (20,82).
click(20+500,82+45)
check(storage[root.."language"]=="pt","main menu changes language")
click(20+120,82+180)
keys.any=true;pressedKey="f6";frame()
check(storage[root.."shortcut"]=="f6","main menu captures shortcut")
click(20+120,82+180);keys.esc=true;frame()
check(closes==0 and storage[root.."shortcut"]=="f6","Escape cancels capture before closing options")
click(20+120,82+180);keys.any=true;pressedKey="w";frame()
check(storage[root.."shortcut"]=="f6","movement key cannot replace shortcut")
click(20+500,82+180)
check(storage[root.."shortcut"]=="","main menu clears shortcut")
click(20+120,82+240)
check(storage[root.."auto_restore"]==false and not env.OSS.autoRestore(),"main menu disables next-entry restoration")
check(storage[root.."character"]=="steam-42.Chell" and storage[root.."favorites.61"],"disabling restoration preserves personal data")
click(20+120,82+420)
check(storage[root.."character"]==nil,"recovery clears only saved skin")
check(storage[root.."favorites.61"] and storage["savegame.tool.sledge.enabled"],"recovery preserves favorites and game progress")
keys.esc=true;frame();check(closes==1,"Escape returns to manager")
-- Small canvas: controls hidden below the viewport must not accept offscreen clicks.
canvas={w=640,h=480};storage[root.."auto_restore"]=true
click(20+120,82+420)
check(storage[root.."auto_restore"]==true,"offscreen controls cannot act")
wheel=-20;frame()
local totalScroll=516-(math.min(670,canvas.h-32)-162)
click(20+120,82+45-totalScroll)
check(storage[root.."language"]=="pt" and storage[root.."auto_restore"]==true,"clipping applies after scrolling")
storage[root.."character"]="steam-42.Chell"
click(20+120,82+420-totalScroll)
check(storage[root.."character"]==nil,"scroll reaches recovery on small canvas")
print("PASS options: "..count.." standalone menu assertions without a map")
