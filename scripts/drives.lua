--- Modified monitor script for AE2 with navigation buttons
--- [ <= ] - предыдущая страница
--- [update] - принудительное обновление
--- [ => ] - следующая страница

mon = peripheral.find("monitor")
me = peripheral.find("meBridge") or peripheral.find("me_bridge")

if not me then
    error("ME Bridge не найден!")
end

if not mon then
    error("Monitor не найден!")
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

-- Функции для кнопок
function renderButtons()
    local startX = 30  -- начальная позиция для блока кнопок
    
    -- Кнопка "назад" [ <= ]
    mon.setCursorPos(startX, 38)
    mon.setTextColor(colors.black)
    mon.setBackgroundColor(colors.white)
    mon.write(" [ <= ] ")
    
    -- Кнопка "обновить" [update]
    mon.setCursorPos(startX + 9, 38)
    mon.write(" [update] ")
    
    -- Кнопка "вперед" [ => ]
    mon.setCursorPos(startX + 20, 38)
    mon.write(" [ => ] ")
    
    -- Возвращаем цвета
    mon.setTextColor(colors.white)
    mon.setBackgroundColor(colors.black)
end

function checkButtonPress(x, y)
    if y ~= 38 then return nil end  -- не в ряду кнопок
    
    local startX = 30
    
    -- Проверяем нажатие на [ <= ]
    if x >= startX and x <= startX + 8 then
        return "prev"
    end
    
    -- Проверяем нажатие на [update]
    if x >= startX + 9 and x <= startX + 18 then
        return "update"
    end
    
    -- Проверяем нажатие на [ => ]
    if x >= startX + 20 and x <= startX + 28 then
        return "next"
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
        currentPage = totalPages  -- зацикливаем на последнюю страницу
    end
    
    if oldPage ~= currentPage then
        refreshDisplay()
    end
end

function nextPage()
    local oldPage = currentPage
    currentPage = currentPage + 1
    if currentPage > totalPages then
        currentPage = 1  -- зацикливаем на первую страницу
    end
    
    if oldPage ~= currentPage then
        refreshDisplay()
    end
end

function forceUpdate()
    -- Подсвечиваем кнопку обновления
    local startX = 30
    mon.setCursorPos(startX + 9, 38)
    mon.setTextColor(colors.white)
    mon.setBackgroundColor(colors.red)
    mon.write(" [update] ")
    sleep(0.2)
    
    -- Полное обновление
    prepare()
end

function prepare()
    mon.clear()
    monX, monY = mon.getSize()
    if monX < 50 or monY < 40 then  -- увеличил требования из-за кнопок
        error("Monitor is too small, we need a size of 50x40 minimum.")
    end
    mon.setPaletteColor(colors.red, 0xba2525)
    mon.setBackgroundColor(colors.black)
    mon.setCursorPos(math.floor((monX/2)-(#label/2)), 1)
    mon.setTextScale(1)
    mon.write(label)
    mon.setCursorPos(1, 1)
    drawBox(2, monX - 1, 3, monY - 10, "Cells", colors.gray, colors.lightGray)
    drawBox(2, monX - 1, monY - 8, monY - 1, "Stats", colors.gray, colors.lightGray)
    
    -- Получаем данные и отображаем текущую страницу
    refreshDisplay()
    
    -- Рисуем кнопки
    renderButtons()
    
    mon.setTextColor(colors.white)
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
    clear(3, monX - 3, 4, monY - 12)
    
    -- Вычисляем какие ячейки показывать на текущей странице
    local startIdx = (currentPage - 1) * CELLS_PER_PAGE + 1
    local endIdx = math.min(startIdx + CELLS_PER_PAGE - 1, data.cells)
    
    -- Обновляем заголовок с номером страницы
    mon.setCursorPos(2, 3)
    mon.setBackgroundColor(colors.gray)
    mon.write(" Cells (Page " .. currentPage .. "/" .. totalPages .. ") ")
    mon.setBackgroundColor(colors.black)
    
    -- Сбрасываем счетчики
    data.totalBytes = 0
    data.usedBytes = 0
    
    -- Сначала посчитаем общую статистику со всех ячеек
    for i = 1, #cells do
        local cell = cells[i]
        local totalBytes = cell.bytes or cell.totalBytes or 0
        local usedBytes = cell.usedBytes or 0
        
        if totalBytes > 0 then
            data.totalBytes = data.totalBytes + totalBytes
            data.usedBytes = data.usedBytes + usedBytes
        end
    end
    
    -- Теперь отображаем только ячейки текущей страницы
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
        
        ::continue::
    end
    
    -- Отрисовываем бары
    if bars and bars.construct then
        bars.construct(mon)
    end
    if bars and bars.screen then
        bars.screen()
    end
    
    -- Обновляем статистику внизу
    updateStatsDisplay()
end

function handleMonitorClick()
    while true do
        local event, side, x, y = os.pullEvent("monitor_touch")
        if side == "monitor" then
            -- Проверяем нажатие на кнопки
            local button = checkButtonPress(x, y)
            if button then
                buttonPress(button)
            end
        end
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

function updateStatsDisplay()
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
end

function updateStats()
    local newCells = me.getCells()
    
    if not newCells then
        return
    end
    
    -- Сохраняем старые данные для проверки изменений
    local oldTotalBytes = data.totalBytes
    local oldUsedBytes = data.usedBytes
    
    -- Пересчитываем общую статистику
    data.totalBytes = 0
    data.usedBytes = 0
    
    for i = 1, #newCells do
        local cell = newCells[i]
        local totalBytes = cell.bytes or cell.totalBytes or 0
        local usedBytes = cell.usedBytes or 0
        
        if totalBytes > 0 then
            data.totalBytes = data.totalBytes + totalBytes
            data.usedBytes = data.usedBytes + usedBytes
        end
    end
    
    -- Проверяем не изменилось ли количество ячеек
    if data.cells ~= #newCells then
        data.cells = #newCells
        totalPages = math.ceil(data.cells / CELLS_PER_PAGE)
        
        -- Проверяем не вышли ли за границы страниц
        if currentPage > totalPages then
            currentPage = totalPages
        end
        if currentPage < 1 then
            currentPage = 1
        end
        
        -- Перерисовываем всё
        prepare()
        return
    end
    
    -- Обновляем данные для баров текущей страницы
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
    
    -- Если изменились значения, обновляем статистику внизу
    if oldTotalBytes ~= data.totalBytes or oldUsedBytes ~= data.usedBytes then
        updateStatsDisplay()
    end
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