--- Modified monitor script for AE2 with pagination
--- Нажмите ПКМ по монитору для переключения страниц

mon = peripheral.find("monitor")
me = peripheral.find("meBridge") or peripheral.find("me_bridge")

if not me then
    error("ME Bridge не найден!")
end

-- Настройки пагинации
local CELLS_PER_PAGE = 20  -- Сколько ячеек показывать на одной странице
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
    drawBox(2, monX - 1, 3, monY - 10, "Cells (Page " .. currentPage .. "/" .. totalPages .. ")", colors.gray, colors.lightGray)
    drawBox(2, monX - 1, monY - 8, monY - 1, "Stats", colors.gray, colors.lightGray)
    addBars()
    
    -- Подсказка по управлению
    mon.setCursorPos(monX - 15, monY - 2)
    mon.setTextColor(colors.lightGray)
    mon.write("RMB for next page")
    mon.setTextColor(colors.white)
end

function addBars()
    local cells = me.getCells()
    
    if not cells or #cells == 0 then
        mon.setCursorPos(4, 5)
        mon.write("No cells found!")
        return
    end
    
    data.cells = #cells
    totalPages = math.ceil(data.cells / CELLS_PER_PAGE)
    
    -- Вычисляем какие ячейки показывать на текущей странице
    local startIdx = (currentPage - 1) * CELLS_PER_PAGE + 1
    local endIdx = math.min(startIdx + CELLS_PER_PAGE - 1, data.cells)
    
    -- Очищаем область для баров
    clear(3, monX - 3, 4, monY - 12)
    
    for i = startIdx, endIdx do
        local cell = cells[i]
        local pos = i - startIdx + 1  -- позиция на экране (1-20)
        local x = 3 * pos
        
        -- Получаем данные из ячейки
        local totalBytes = cell.bytes or cell.totalBytes or 0
        local usedBytes = cell.usedBytes or 0
        
        -- Пропускаем если нет данных
        if totalBytes == 0 then
            goto continue
        end
        
        -- Добавляем бар
        if bars and bars.add then
            bars.add(tostring(pos), "ver", totalBytes, usedBytes, 1 + x, 5, 1, monY - 16, colors.red, colors.green)
        end
        
        -- Подпись для ячейки (показываем реальный номер ячейки)
        mon.setCursorPos(x + 1, monY - 11)
        mon.write(string.format("#%d", i))
        
        data.totalBytes = data.totalBytes + totalBytes
        data.usedBytes = data.usedBytes + usedBytes
        
        ::continue::
    end
    
    -- Обновляем заголовок с номером страницы
    mon.setCursorPos(math.floor((monX/2)-(#label/2)), 1)
    mon.setBackgroundColor(colors.black)
    mon.write(label)
    mon.setCursorPos(2, 3)
    mon.setBackgroundColor(colors.gray)
    mon.write(" Cells (Page " .. currentPage .. "/" .. totalPages .. ") ")
    
    -- Отрисовываем бары
    if bars and bars.construct then
        bars.construct(mon)
    end
    if bars and bars.screen then
        bars.screen()
    end
end

-- Функция для обработки нажатий на монитор
function handleMonitorClick()
    while true do
        local event, side, x, y = os.pullEvent("monitor_touch")
        if side == "monitor" then
            if x == -1 then  -- ПКМ
                nextPage()
            else  -- ЛКМ
                if isUpdateButtonPressed(x, y) then
                    forceUpdate()
                end
            end
        end
    end
end

function forceUpdate()
    mon.setCursorPos(41, 38)
    mon.setTextColor(colors.white)
    mon.setBackgroundColor(colors.red)
    mon.write(" update ")
    sleep(0.5)
    prepare()  -- полное обновление экрана
end

function nextPage()
    local oldPage = currentPage
    currentPage = currentPage + 1
    if currentPage > totalPages then
        currentPage = 1  -- зацикливаем на первую страницу
    end
    
    if oldPage ~= currentPage then
        -- Перерисовываем экран
        mon.clear()
        prepare()
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
    
    data.cells = #newCells
    totalPages = math.ceil(data.cells / CELLS_PER_PAGE)
    
    -- Проверяем не вышли ли за границы страниц
    if currentPage > totalPages then
        currentPage = totalPages
    end
    if currentPage < 1 then
        currentPage = 1
    end
    
    if #newCells == 0 then
        clear(3, monX - 3, 4, monY - 12)
        mon.setCursorPos(4, 5)
        mon.write("No cells connected")
    else 
        -- Считаем общую статистику со всех ячеек
        for i = 1, #newCells do
            local cell = newCells[i]
            local totalBytes = cell.bytes or cell.totalBytes or 0
            local usedBytes = cell.usedBytes or 0
            
            if totalBytes > 0 then
                data.totalBytes = data.totalBytes + totalBytes
                data.usedBytes = data.usedBytes + usedBytes
            end
        end
        
        -- Перерисовываем только текущую страницу
        local startIdx = (currentPage - 1) * CELLS_PER_PAGE + 1
        local endIdx = math.min(startIdx + CELLS_PER_PAGE - 1, data.cells)
        
        for i = startIdx, endIdx do
            local cell = newCells[i]
            local pos = i - startIdx + 1
            
            local totalBytes = cell.bytes or cell.totalBytes or 0
            local usedBytes = cell.usedBytes or 0
            
            -- Обновляем бары
            if bars and bars.set then
                bars.set(tostring(pos), "cur", usedBytes)
                bars.set(tostring(pos), "max", totalBytes)
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
    
    -- Обновляем заголовок
    mon.setCursorPos(2, 3)
    mon.setBackgroundColor(colors.gray)
    mon.write(" Cells (Page " .. currentPage .. "/" .. totalPages .. ") ")
    mon.setBackgroundColor(colors.black)
end

-- Запускаем параллельно два процесса:
-- 1. Обновление статистики
-- 2. Обработка нажатий на монитор
prepare()

parallel.waitForAny(
    function()
        while true do
            updateStats()
            sleep(1)
        end
    end,
    handleMonitorClick
)