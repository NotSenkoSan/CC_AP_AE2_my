mon = peripheral.find("monitor")
me = peripheral.find("meBridge") or peripheral.find("me_bridge")

-- Проверяем подключение
if not me then
    error("ME Bridge не найден!")
end

data = {
    drives = 0,
    totalBytes = 0,
    usedBytes = 0,
    totalCells = 0,
}

local label = "ME Drives"
local monX, monY

-- Загружаем API для баров
os.loadAPI("scripts/api/bars.lua")

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
    drawBox(2, monX - 1, 3, monY - 10, "Drives", colors.gray, colors.lightGray)
    drawBox(2, monX - 1, monY - 8, monY - 1, "Stats", colors.gray, colors.lightGray)
    addBars()
end

function addBars()
    local drives = me.getDrives()
    
    if not drives or #drives == 0 then
        mon.setCursorPos(4, 5)
        mon.write("No drives found!")
        return
    end
    
    data.drives = #drives
    
    for i = 1, #drives do
        local drive = drives[i]
        local x = 3 * i
        
        -- Получаем информацию о диске
        local totalBytes = 0
        local usedBytes = 0
        
        -- В новых версиях AE2 структура данных может отличаться
        if drive.totalBytes and drive.usedBytes then
            totalBytes = drive.totalBytes
            usedBytes = drive.usedBytes
        elseif drive.bytesMax and drive.bytesUsed then
            totalBytes = drive.bytesMax
            usedBytes = drive.bytesUsed
        elseif drive.maxBytes and drive.usedBytes then
            totalBytes = drive.maxBytes
            usedBytes = drive.usedBytes
        else
            -- Если не можем определить, пропускаем
            print("Unknown drive structure:", textutils.serialize(drive))
            goto continue
        end
        
        bars.add(tostring(i), "ver", totalBytes, usedBytes, 1 + x, 5, 1, monY - 16, colors.red, colors.green)
        
        -- Подпись для диска
        mon.setCursorPos(x + 1, monY - 11)
        mon.write(string.format("D%d", i))
        
        data.totalBytes = data.totalBytes + totalBytes
        data.usedBytes = data.usedBytes + usedBytes
        
        -- Получаем количество ячеек (если доступно)
        if drive.cells and type(drive.cells) == "table" then
            data.totalCells = data.totalCells + #drive.cells
        end
        
        ::continue::
    end
    
    bars.construct(mon)
    bars.screen()
end

function drawBox(xMin, xMax, yMin, yMax, title, bcolor, tcolor)
    mon.setBackgroundColor(bcolor)
    
    -- Верхняя граница
    for xPos = xMin, xMax do
        mon.setCursorPos(xPos, yMin)
        mon.write(" ")
    end
    
    -- Нижняя граница
    for xPos = xMin, xMax do
        mon.setCursorPos(xPos, yMax)
        mon.write(" ")
    end
    
    -- Левая и правая границы
    for yPos = yMin, yMax do
        mon.setCursorPos(xMin, yPos)
        mon.write(" ")
        mon.setCursorPos(xMax, yPos)
        mon.write(" ")
    end
    
    -- Заголовок
    mon.setCursorPos(xMin + 2, yMin)
    mon.setBackgroundColor(colors.black)
    mon.setTextColor(tcolor)
    mon.write(" " .. title .. " ")
    mon.setTextColor(colors.white)
    mon.setBackgroundColor(colors.black)
end

function clear(xMin, xMax, yMin, yMax)
    mon.setBackgroundColor(colors.black)
    for xPos = xMin, xMax do
        for yPos = yMin, yMax do
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
    local newDrives = me.getDrives()
    
    -- Сбрасываем данные
    data.totalBytes = 0
    data.usedBytes = 0
    data.totalCells = 0
    
    if not newDrives then
        data.drives = 0
        print("getDrives() returned nil")
        return
    end
    
    if #newDrives == 0 then
        clear(3, monX - 3, 4, monY - 12)
        mon.setCursorPos(4, 5)
        mon.write("No drives connected")
    else 
        for i = 1, #newDrives do
            local drive = newDrives[i]
            
            -- Определяем правильные поля для данных
            local totalBytes = 0
            local usedBytes = 0
            
            if drive.totalBytes and drive.usedBytes then
                totalBytes = drive.totalBytes
                usedBytes = drive.usedBytes
            elseif drive.bytesMax and drive.bytesUsed then
                totalBytes = drive.bytesMax
                usedBytes = drive.bytesUsed
            elseif drive.maxBytes and drive.usedBytes then
                totalBytes = drive.maxBytes
                usedBytes = drive.usedBytes
            else
                -- Выводим структуру для отладки
                print("Drive " .. i .. " structure:", textutils.serialize(drive))
                goto skip_drive
            end
            
            data.totalBytes = data.totalBytes + totalBytes
            data.usedBytes = data.usedBytes + usedBytes
            
            if drive.cells and type(drive.cells) == "table" then
                data.totalCells = data.totalCells + #drive.cells
            end
            
            -- Обновляем бары (если они существуют)
            if bars.set then
                bars.set(tostring(i), "cur", usedBytes)
                bars.set(tostring(i), "max", totalBytes)
            end
            
            ::skip_drive::
        end
        
        if bars.screen then
            bars.screen()
        end
    end
    
    -- Обновляем статистику на мониторе
    clear(3, monX - 3, monY - 5, monY - 2)
    
    mon.setCursorPos(4, monY - 6)
    mon.write("Drives: " .. data.drives)
    
    mon.setCursorPos(4, monY - 5)
    mon.write("Full: " .. roundToDecimal(getUsage(), 2) .. "%")
    
    mon.setCursorPos(4, monY - 4)
    mon.write("Cells: " .. data.totalCells)
    
    mon.setCursorPos(4, monY - 3)
    mon.write("Bytes(Total|Used):")
    
    mon.setCursorPos(23, monY - 3)
    mon.write(comma_value(data.totalBytes) .. " | " .. comma_value(data.usedBytes))
    
    -- Проверяем изменение количества дисков
    if data.drives ~= #newDrives then
        clear(3, monX - 3, 4, monY - 12)
        mon.setCursorPos(4, 5)
        mon.write("Drive count changed... Rebooting")
        sleep(2)
        shell.run("reboot")
    end
end

-- Основной цикл
prepare()

while true do
    updateStats()
    sleep(1) -- Увеличил интервал для уменьшения нагрузки
    
end