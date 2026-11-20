-- Shows how long a batch takes through the year, from forecasts read from the real game. It runs the mod's
-- own code (the ten-minute weather record, a batch put in and brought up to now, its status), so it doubles as a check
-- that a change to that code keeps every number. Run from the mod folder: luajit tools/season_report.lua [climate.csv]
-- Each line of the file: world month offset tempMin tempMean tempMax humMin humMean humMax rainy snowy
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
H.useModPaths()
H.installClock(0)
H.installModData()
H.installEvents()
dofile("42/media/lua/shared/__MOD__.lua")
local M = __MOD__

local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
local STEPS_PER_HOUR = 6

local function readDays(path)
    local days = {}
    for line in io.lines(path) do
        local f = {}
        for column in line:gmatch("%S+") do table.insert(f, column) end
        -- Each month's forecast also holds the 10 days before it (offset below 0): skipped, so a month is 30 days.
        if #f >= 6 and tonumber(f[3]) >= 0 then
            table.insert(days, { world = tonumber(f[1]), offset = tonumber(f[3]), month = tonumber(f[2]), low = tonumber(f[4]), mean = tonumber(f[5]), high = tonumber(f[6]) })
        end
    end
    return days
end

-- The day's weather, coldest before dawn and warmest mid-afternoon.
local function temperatureAt(day, hour)
    local swing = math.cos((hour - 15) / 24 * 2 * math.pi)
    return swing >= 0 and day.mean + (day.high - day.mean) * swing or day.mean + (day.mean - day.low) * swing
end

local function station()
    local modData = {}
    return { getModData = function() return modData end }
end

-- The first sampled world's calendar year, settled (Weather.settledMeans).
local function settle(days)
    local year = {}
    for _, day in ipairs(days) do
        if day.world == days[1].world then table.insert(year, day) end
    end
    return require("TraditionalPreservationCore/Weather").settledMeans(year)
end

local days = readDays(arg[1] or "tools/climate_year.csv")
-- The ledger starts as a long-running save's would on 1 January.
M.getLedger().seasonTemperature, M.getLedger().groundTemperature = settle(days)(days[1].month, days[1].offset)

-- One batch per place, started on the first day of each month, plus one that goes down to the basement
-- halfway through its first day. Updated every in-game hour, as an open window would.
local runs = {}
local function startRuns(index)
    for _, place in ipairs({ "Open", "Sheltered", "Basement", "Moved" }) do
        local run = { station = station(), place = place, at = place == "Moved" and "Sheltered" or place, month = days[index].month, startHour = H.hours }
        M.put(run.station, 1, H.hours, run.at)
        table.insert(runs, run)
    end
end

local results, statuses = {}, {}
for index, day in ipairs(days) do
    if index == 1 or day.month ~= days[index - 1].month then startRuns(index) end
    for hour = 0, 23 do
        for step = 1, STEPS_PER_HOUR do
            H.setHours(H.hours + 1 / STEPS_PER_HOUR)
            M.advance(M.getLedger(), H.hours, temperatureAt(day, hour + step / STEPS_PER_HOUR))
        end
        for _, run in ipairs(runs) do
            if not run.finished then
                local record = M.update(run.station, H.hours, run.at)
                if run.place == "Moved" and H.hours - run.startHour >= 12 then run.at = "Basement" end
                local key = run.month .. run.place
                local batch = record.batches[1]
                if not statuses[key] and H.hours - run.startHour >= 24 then
                    local temperature = M.placeTemperature(M.getLedger(), run.at)
                    statuses[key] = M.status(batch, temperature)
                    statuses[key].temperature, statuses[key].place = temperature, run.at
                end
                if M.isDone(batch) then
                    run.finished = true
                    results[key] = results[key] or (H.hours - run.startHour) / 24
                end
            end
        end
    end
end

local function cell(month, place)
    local taken = results[month .. place]
    return taken and string.format("%.2f", taken) or ""
end

print(string.format("Days for one batch (%d hours at full speed), started on the first of the month", M.PROCESS_HOURS))
print("| Month | Outdoors | Indoors | Basement | Indoors, then basement |")
print("|---|---|---|---|---|")
for month = 1, 12 do
    print(string.format("| %s | %s | %s | %s | %s |", MONTHS[month],
        cell(month, "Open"), cell(month, "Sheltered"), cell(month, "Basement"), cell(month, "Moved")))
end

print("")
print("Info after one day: progress, hours left, temperature, rate")
for month = 1, 12 do
    for _, place in ipairs({ "Open", "Sheltered", "Basement", "Moved" }) do
        local s = statuses[month .. place]
        if s then
            print(string.format("%s %-9s %.6f %.6f %.6f %.6f %s", MONTHS[month], place, s.progress, s.hoursLeft, s.temperature, s.rate, s.place))
        end
    end
end

print("")
print("Ledger at the end")
local ledger = M.getLedger()
local keys = {}
for key in pairs(ledger) do table.insert(keys, key) end
table.sort(keys)
for _, key in ipairs(keys) do print(string.format("%-18s %.9f", key, ledger[key])) end
