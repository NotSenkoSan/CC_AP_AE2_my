--- Modified monitor script for AE2 with right-side navigation buttons

mon = peripheral.find("monitor")
me = peripheral.find("meBridge") or peripheral.find("me_bridge")

if not me then
    error("ME Bridge не найден!")
end

if not mon then
    error("Monitor не найден!")
end

-- Настройки пагинации
local CELLS_PER_PAGE = 20
local currentPage = 1
local totalPages = 1

data = {
    cells = 0,
    totalBytes = 0,
    usedBytes = 0,
}

local label = "ME Cells"
local monX, monY

-- Загружаем bars.lua
local bars = dofile("/CC_AP_AE2/scripts/api/bars.lua")

-- Кнопки справа
function renderButtons()
    local btnX = monX - 12  -- позиция кнопок справа
    local startY = 10       -- начальная позиция по вертикали
    
    -- Рамка для кнопок
    mon.setBackgroundColor(colors.gray)
    for x = btnX - 1, monX - 2 do
        for y = startY - 1, startY + 5 do
            mon.setCursorPos(x, y)
            mon.write(" ")
        end
    end
    
    -- Заголовок
    mon.setCursorPos(btnX, startY - 1)
    mon.setBackgroundColor(colors.black)
    mon.setTextColor(colors.lightGray)
    mon.write(" Navigation ")
    
    -- Кнопка "Назад" [<=]
    mon.setCursorPos(btnX, startY)
    mon.setBackgroundColor(colors.white)
    mon.setTextColor(colors.black)
    mon.write("  [ <= ]  ")
    
    -- Информация о странице
    mon.setCursorPos(btnX, startY + 1)
    mon.setBackgroundColor(colors.black)
    mon.setTextColor(colors.white)
    mon.write(" Page " .. currentPage .. "/" .. totalPages .. " ")
    
    -- Кнопка "Вперед" [=>]
    mon.setCursorPos(btnX, startY + 2)
    mon.setBackgroundColor(colors.white)
    mon.setTextColor(colors.black)
    mon.write("  [ => ]  ")
    
    -- Разделитель
    mon.setCursorPos(btnX, startY + 3)
    mon.setBackgroundColor(colors.black)
    mon.setTextColor(colors.gray)
    mon.write("-----------")
    
    -- Кнопка "Обновить" [UPDATE]
    mon.setCursorPos(btnX, startY + 4)
    mon.setBackgroundColor(colors.white)
    mon.setTextColor(colors.black)
    mon.write(" [UPDATE] ")
    
    -- Возвращаем цвета
    mon.setTextColor(colors.white)
    mon.setBackgroundColor(colors.black)
end

function checkButtonPress(x, y)
    local btnX = monX - 12
    local startY = 10
    
    -- Проверяем что нажатие в области кнопок
    if x < btnX or x > monX - 2 then return nil end
    if y < startY - 1 or y > startY + 5 then return nil end
    
    -- Кнопка "Назад"
    if y == startY and x >= btnX and x <= btnX + 9 then
        return "prev"
    end
    
    -- Кнопка "Вперед"
    if y == startY + 2 and x >= btnX and x <= btnX + 9 then
        return "next"
    end
    
    -- Кнопка "Обновить"
    if y == startY + 4 and x >= btnX and x <= btnX + 9 then
        return "update"
    end
    
    return nil
end

function buttonPress(button)
    if button == "prev" then
        prevPage()
    elseif button == "update" then
        forceUpdate()
    elseif button == "next" then
        nextPage()
    end
end

function prevPage()
    local oldPage = currentPage
    currentPage = currentPage - 1
    if currentPage < 1 then
        currentPage = totalPages
    end
    
    if oldPage ~= currentPage then
        refreshDisplay()
        renderButtons()
    end
end

function nextPage()
    local oldPage = currentPage
    currentPage = currentPage + 1
    if currentPage > totalPages then
        currentPage = 1
    end
    
    if oldPage ~= currentPage then
        refreshDisplay()
        renderButtons()
    end
end

function forceUpdate()
    -- Подсвечиваем кнопку обновления
    local btnX = monX - 12
    local startY = 10
    
    mon.setCursorPos(btnX, startY + 4)
    mon.setBackgroundColor(colors.red)
    mon.setTextColor(colors.white)
    mon.write(" [UPDATE] ")
    sleep(0.2)
    
    prepare()
end

function prepare()
    mon.clear()
    monX, monY = mon.getSize()
    
    mon.setPaletteColor(colors.red, 0xba2525)
    mon.setBackgroundColor(colors.black)
    mon.setCursorPos(math.floor((monX/2)-(#label/2)), 1)
    mon.setTextScale(1)
    mon.write(label)
    
    -- Рисуем рамку для ячеек (с учетом места для кнопок справа)
    drawBox(2, monX - 14, 3, monY - 5, "Cells", colors.gray, colors.lightGray)
    
    refreshDisplay()
    renderButtons()
end

function refreshDisplay()
    local cells = me.getCells()
    
    if not cells or #cells == 0 then
        mon.setCursorPos(4, 5)
        mon.write("No cells found!")
        return
    end
    
    data.cells = #cells
    totalPages = math.ceil(data.cells / CELLS_PER_PAGE)
    
    -- Очищаем область для баров
    clear(3, monX - 15, 4, monY - 6)
    
    local startIdx = (currentPage - 1) * CELLS_PER_PAGE + 1
    local endIdx = math.min(startIdx + CELLS_PER_PAGE - 1, data.cells)
    
    -- Обновляем заголовок
    mon.setCursorPos(2, 3)
    mon.setBackgroundColor(colors.gray)
    mon.write(" Cells " .. startIdx .. "-" .. endIdx .. "/" .. data.cells .. " ")
    mon.setBackgroundColor(colors.black)
    
    -- Считаем общую статистику
    data.totalBytes = 0
    data.usedBytes = 0
    
    for i = 1, #cells do
        local cell = cells[i]
        local totalBytes = cell.bytes or cell.totalBytes or 0
        local usedBytes = cell.usedBytes or 0
        
        if totalBytes > 0 then
            data.totalBytes = data.totalBytes + totalBytes
            data.usedBytes = data.usedBytes + usedBytes
        end
    end
    
    -- Отображаем ячейки текущей страницы
    for i = startIdx, endIdx do
        local cell = cells[i]
        local pos = i - startIdx + 1
        local x = 3 * pos
        
        local totalBytes = cell.bytes or cell.totalBytes or 0
        local usedBytes = cell.usedBytes or 0
        
        if totalBytes > 0 and bars and bars.add then
            bars.add(tostring(pos), "ver", totalBytes, usedBytes, 1 + x, 5, 1, monY - 12, colors.red, colors.green)
            
            mon.setCursorPos(x + 1, monY - 7)
            mon.write(string.format("%d", i))
        end
    end
    
    if bars and bars.construct then
        bars.construct(mon)
    end
    if bars and bars.screen then
        bars.screen()
    end
    
    updateStatsDisplay()
end

function handleMonitorClick()
    while true do
        local event, side, x, y = os.pullEvent("monitor_touch")
        if side == "monitor" then
            local button = checkButtonPress(x, y)
            if button then
                buttonPress(button)
            end
        end
    end
end

function drawBox(xMin, xMax, yMin, yMax, title, bcolor, tcolor)
    mon.setBackgroundColor(bcolor)
    for xPos = xMin, xMax do
        mon.setCursorPos(xPos, yMin)
        mon.write(" ")
    end
    for yPos = yMin, yMax do
        mon.setCursorPos(xMin, yPos)
        mon.write(" ")
        mon.setCursorPos(xMax, yPos)
        mon.write(" ")
    end
    for xPos = xMin, xMax do
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
    for xPos = xMin, xMax do
        for yPos = yMin, yMax do
            mon.setCursorPos(xPos, yPos)
            mon.write(" ")
        end
    end
end

function updateStatsDisplay()
    clear(3, monX - 15, monY - 4, monY - 2)
    
    mon.setCursorPos(4, monY - 3)
    mon.write(string.format("Total: %s/%s (%d%%)",
        comma_value(data.usedBytes),
        comma_value(data.totalBytes),
        roundToDecimal(getUsage(), 1)))
end

function getUsage()
    if data.totalBytes == 0 then return 0 end
    return (data.usedBytes * 100) / data.totalBytes
end

function comma_value(n)
    if not n then return "0" end
    local s = tostring(n)
    local k = 3
    while k < #s do
        s = s:sub(1, -k-1) .. "," .. s:sub(-k)
        k = k + 4
    end
    return s
end

function roundToDecimal(num, places)
    local mult = 10^(places or 0)
    return math.floor(num * mult + 0.5) / mult
end

function updateStats()
    local newCells = me.getCells()
    if not newCells then return end
    
    local oldTotal = data.totalBytes
    local oldUsed = data.usedBytes
    
    data.totalBytes = 0
    data.usedBytes = 0
    
    for i = 1, #newCells do
        local cell = newCells[i]
        data.totalBytes = data.totalBytes + (cell.bytes or cell.totalBytes or 0)
        data.usedBytes = data.usedBytes + (cell.usedBytes or 0)
    end
    
    if oldTotal ~= data.totalBytes or oldUsed ~= data.usedBytes then
        refreshDisplay()
        renderButtons()
    end
    
    if data.cells ~= #newCells then
        prepare()
    end
end

-- Запуск
prepare()

parallel.waitForAny(
    function()
        while true do
            updateStats()
            sleep(2)
        end
    end,
    handleMonitorClick
)