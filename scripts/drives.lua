--- Modified monitor script for AE2
--- Adapted for cell-based API

mon = peripheral.find("monitor")
me = peripheral.find("meBridge") or peripheral.find("me_bridge")

if not me then
    error("ME Bridge не найден!")
end

data = {
    cells = 0,
    totalBytes = 0,
    usedBytes = 0,
}

local label = "ME Cells"
local monX, monY

-- Загружаем bars.lua
local bars = dofile("/CC_AF_AE2/scripts/api/bars.lua")

function prepare()
    mon.clear()
    monX, monY = mon.getSize()
    if monX < 38 or monY < 25 then
        error("Monitor is too small, we need a size of 39x and 26y minimum.")
    end
    mon.setPaletteColor(colors.red, 0xba2525)
    mon.setBackgroundColor(colors.black)
    mon.setCursorPos(math.floor((monX/2)-(#label/2)), 1)
    mon.setTextScale(1)
    mon.write(label)
    mon.setCursorPos(1, 1)
    drawBox(2, monX - 1, 3, monY - 10, "Cells", colors.gray, colors.lightGray)
    drawBox(2, monX - 1, monY - 8, monY - 1, "Stats", colors.gray, colors.lightGray)
    addBars()
end

function addBars()
    local cells = me.getCells()
    
    if not cells or #cells == 0 then
        mon.setCursorPos(4, 5)
        mon.write("No cells found!")
        return
    end
    
    data.cells = #cells
    
    for i = 1, #cells do
        local cell = cells[i]
        local x = 3 * i
        
        -- Получаем данные из ячейки
        local totalBytes = cell.bytes or cell.totalBytes or 0
        local usedBytes = cell.usedBytes or 0
        
        -- Пропускаем если нет данных
        if totalBytes == 0 then
            goto continue
        end
        
        -- Добавляем бар (проверяем что bars существует)
        if bars and bars.add then
            bars.add(tostring(i), "ver", totalBytes, usedBytes, 1 + x, 5, 1, monY - 16, colors.red, colors.green)
        end
        
        -- Подпись для ячейки
        mon.setCursorPos(x + 1, monY - 11)
        mon.write(string.format("C%d", i))
        
        data.totalBytes = data.totalBytes + totalBytes
        data.usedBytes = data.usedBytes + usedBytes
        
        ::continue::
    end
    
    -- Проверяем что bars существует перед вызовом
    if bars and bars.construct then
        bars.construct(mon)
    end
    if bars and bars.screen then
        bars.screen()
    end
end

function drawBox(xMin, xMax, yMin, yMax, title, bcolor, tcolor)
    mon.setBackgroundColor(bcolor)
    for xPos = xMin, xMax, 1 do
        mon.setCursorPos(xPos, yMin)
        mon.write(" ")
    end
    for yPos = yMin, yMax, 1 do
        mon.setCursorPos(xMin, yPos)
        mon.write(" ")
        mon.setCursorPos(xMax, yPos)
        mon.write(" ")
    end
    for xPos = xMin, xMax, 1 do
        mon.setCursorPos(xPos, yMax)
        mon.write(" ")
    end
    mon.setCursorPos(xMin+2, yMin)
    mon.setBackgroundColor(colors.black)
    mon.setTextColor(tcolor)
    mon.write(" " .. title .. " ")
    mon.setTextColor(colors.white)
    mon.setBackgroundColor(colors.black)
end

function clear(xMin, xMax, yMin, yMax)
    mon.setBackgroundColor(colors.black)
    for xPos = xMin, xMax, 1 do
        for yPos = yMin, yMax, 1 do
            mon.setCursorPos(xPos, yPos)
            mon.write(" ")
        end
    end
end

function getUsage()
    if data.totalBytes == 0 then return 0 end
    return (data.usedBytes * 100) / data.totalBytes
end

function comma_value(n)
    if not n then return "0" end
    local left, num, right = string.match(tostring(n), '^([^%d]*%d)(%d*)(.-)$')
    if not left then return tostring(n) end
    return left .. (num:reverse():gsub('(%d%d%d)', '%1,'):reverse()) .. (right or "")
end

function roundToDecimal(num, decimalPlaces)
    if not num then return 0 end
    local mult = 10^(decimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

function updateStats()
    local newCells = me.getCells()
    
    data.totalBytes = 0
    data.usedBytes = 0
    
    if not newCells then
        data.cells = 0
        print("getCells() returned nil")
        return
    end
    
    if #newCells == 0 then
        clear(3, monX - 3, 4, monY - 12)
        mon.setCursorPos(4, 5)
        mon.write("No cells connected")
    else 
        for i = 1, #newCells do
            local cell = newCells[i]
            
            local totalBytes = cell.bytes or cell.totalBytes or 0
            local usedBytes = cell.usedBytes or 0
            
            if totalBytes > 0 then
                data.totalBytes = data.totalBytes + totalBytes
                data.usedBytes = data.usedBytes + usedBytes
            end
            
            -- Обновляем бары если они есть
            if bars and bars.set then
                bars.set(tostring(i), "cur", usedBytes)
                bars.set(tostring(i), "max", totalBytes)
            end
        end
        
        if bars and bars.screen then
            bars.screen()
        end
    end
    
    -- Обновляем статистику
    clear(3, monX - 3, monY - 5, monY - 2)
    
    mon.setCursorPos(4, monY - 6)
    mon.write("Cells: " .. data.cells)
    
    mon.setCursorPos(4, monY - 5)
    mon.write("Full: " .. roundToDecimal(getUsage(), 2) .. "%")
    
    mon.setCursorPos(4, monY - 4)
    mon.write("Bytes(Total|Used):")
    
    mon.setCursorPos(23, monY - 4)
    mon.write(comma_value(data.totalBytes) .. " | " .. comma_value(data.usedBytes))
    
    -- Проверяем изменение количества ячеек
    if data.cells ~= #newCells then
        clear(3, monX - 3, 4, monY - 12)
        mon.setCursorPos(4, 5)
        mon.write("Cell count changed... Rebooting")
        sleep(2)
        shell.run("reboot")
    end
end

-- Запуск
prepare()

while true do
    updateStats()
    sleep(1)
end