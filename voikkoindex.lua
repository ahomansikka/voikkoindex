-- Copyright (©) 2021-2026 Hannu Väisänen
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.


if not modules then modules = { } end modules ['voikkoindex'] = {
    version   = 0.2,
    comment   = "Käytetään Voikkoa muuttamaan indeksoitavat sanat perusmuotoon.",
    author    = "Hannu Väisänen",
    copyright = "Hannu Väisänen",
    license   = "See later."
}


Voikko = require "Voikko"

logfile = nil
--io.open ("voikkoindex.log", "w")

local utf8 = require 'lua-utf8'

userdata = userdata or {}
u = userdata


local extra_surname = {}
local extra_place_name = {}
local extra_word = {}

local extra_surname_count = {[1] = 1}
local extra_place_name_count = {[1] = 1}
local extra_word_count = {[1] = 1}

local surname_index = {}
local place_name_index = {}
local word_index = {}

local surname_index_count = {[1] = 1}
local place_name_index_count = {[1] = 1}
local word_index_count = {[1] = 1}

-- Aloitetaan voikkoindex.
--
function u.init_voikkoindex (langcode, path, logf)
    Voikko.init (langcode, path)
    logfile = io.open (logf, "w")
    logfile:write ("init_voikkoindex " .. langcode .. "\n")
end


-- Lopetetaan voikkoindex.
--
function u.terminate_voikkoindex()
      Voikko.terminate()
end


-- Palautetaan 'u':n ja 'v':n yhteisen alkuosan indeksi.
-- Isot ja pienet kirjaimet ovat samoja.
-- Esim. ('ABcd', 'abcdef') -> 3
--
local function common_prefix_index (u, v)
    local last = math.min (#u, #v)
    for i = 1, last do
        if utf8.ncasecmp (utf8.sub(u,i,i), utf8.sub(v,i,i)) ~= 0 then
            return i-1
        end
    end
    return last
end


-- Tehdään sanasta nätimpi. (-:
-- s: alkuperäinen sana.
-- t: perusmuoto
-- Palautetaan sana, jonka alkuosa on s:stä otettu s:n ja t:n
-- yhteinen alkuosa ja loppu t:n loppuosa.
-- Isot ja pienet kirjaimet ovat samoja.
-- Esim. ('Osuuskassoille', 'osuuskassa') -> Osuuskassa
--
local function beautify (s, t)
    if s == nil or t == nil then
        error ("beautify: s == nil or t == nil")
    end
    --logfile:write ("beautify a " .. s .. " " .. t .. "\n")
    local n = common_prefix_index (s, t)
    if n == 0 then
        return ""
    end
    --logfile:write ("beautify b " .. s .. " " .. t .. "\n")
    local x = utf8.sub (s, 1, n)
    local y = utf8.sub (t, n+1)
    local z = x .. y
    assert (z ~= nil)
    --logfile:write ("beautify " .. s .. " " .. t .. " " .. z .. "\n")
    return z
end


-- Muutetan sanan eka kirjain isoksi ja muut pieneksi.
-- Esim. taKaHIkiä -> Takahikiä
--
local function capitalize (word)
    local b = utf8.title(utf8.sub(word,1,1)) .. utf8.lower(utf8.sub(word,2))
    return b
end


-- Kuten capitalize() mutta huomioidaan yhdysviiva ääntiöiden välissä.
-- Siis esim. Lähi-itä, mutta Iso-Britannia.
--
local function capitalize_place_name (word)
    local n = utf8.find (word, "-", 1, true)
    if n == nil then
        return capitalize (word)
    else
        if utf8.sub(word,n-1,n-1) == utf8.sub(word,n+1,n+1) then
            --logfile:write ("CAP1 " .. word .. " " .. n .. " " .. utf8.sub(word,n-1,n-1) .. " " .. utf8.sub(word,n+1,n+1) .. "\n")
            return capitalize (word)
        else 
            --logfile:write ("CAP2 " .. word .. " " .. n .. " " .. "\n")
            return utf8.gsub (word, "(%a+)", capitalize)
        end
    end
end


-- Siistitään sanaa.
--
local function cleanup (s)
    logfile:write ("cleanup1 [" .. s .. "]\n")
    local t = utf8.gsub (s, "[\\][-]", "")  -- Poistetaan ehdollinen ta\-vu\-tus.
    t = utf8.gsub (t, "\"", "")             -- Poistetaan tavutusohje esim. linja"-autosta => linja-autosta.
    t = utf8.gsub (t, "\n", " ")            -- Muutetaan rivinvaihto tyhjeeksi.
    t = utf8.gsub (t, "\\emph%s*{", "")     -- Esim. "\emph{Virtanen}" => "Virtanen}" tai "\emph{Virtanen.}" => "Virtanen.}"
    t = utf8.gsub (t, "[.,;:]}", "")        -- Poistetaan \emph{}:n lopusta jäljelle jääneet merkkijonot ".}", ",}" tai ";}".
    t = utf8.gsub (t, "[{}]", "")           -- Poistetaan mahdollisesti jäljelle jääneet { ja }.
    return t
end


-- Jaetaan merkkijono 'word' sanoihin, joiden erottimena on säännöllinen lauseke 'regex'
-- ja palautetaan ne taulukkona.
-- Esim. split ("Tämä on esimerkki.", "%S+") => "Tämä" "on" "esimerkki."
--
local function split (word, regex)
    --logfile:write ("Split a " .. word .. "\n")
    local list = {}
    for w in utf8.gmatch (word, regex) do
        table.insert (list, w)
        --logfile:write ("Split b " .. w .. "\n")
    end
    return list
end



-- Ovatko kaikki taulukon result merkkijonot samoja, kun ei oteta huomioon kirjainkokoa?
-- Esim 'Kari' ja 'kari' ovat samoja.
--
local function all_same (result)
    for i = 2, #result, 1 do
      if utf8.ncasecmp (result[1],result[i]) ~= 0 then
          return false
      end
    end
    return true
end


-- Jos sanassa on kaksoispiste, palautetaan sanan alkuosa viimeiseen kaksoispisteseen asti.
-- Esim. jos s == "ABCDE:n" palautetaan "ABCDE". Jos sanassa ei ole kaksoispistettä,
-- palautetaan nil.
--
local function decolon (s)
  local n = utf8.match (s, ".*():")  -- Viimeisen kaksoispisteen indeksi.
  if n == nil then
    return nil
  else
    return utf8.sub (s, 1, n-1)
  end
end


-- Palautetaan vain yksi perusmuoto.
-- Esim. alusta -> 'alku alus alunen alusta alustaa' ei käy,
-- mutta isot ja pienet kirjaimet ovat samoja.
--
local function get_strict_result (word, result)
--    for i = 1, #result do logfile:write ("get_strict_result1 " .. result[i] .. "\n") end
    if #result == 0 then
--        logfile:write ("get_strict_result2 " .. word .. ": ei perusmuotoa A.\n")
        return nil
    elseif #result > 1 then
        if all_same (result) then
--            logfile:write ("get_strict_result3 " .. word .. ": perusmuoto: " .. result[1] .. " B.\n")
            return result[1]
        else
--            logfile:write ("get_strict_result4 " .. word .. ": useampi kuin yksi perusmuoto C.\n")
            error ("get_strict_result4 " .. word .. ": useampi kuin yksi perusmuoto C.\n")
            return nil
        end
    else
--        logfile:write ("get_strict_result5 " .. word .. ": perusmuoto: " .. result[1] .. ".\n")
        return result[1]
    end
end


---------------------------------------------------------------------------------


-- Etsitään sanan 'word' alkuosa taulukosta 'data'
-- ja palautetaan koko sana.
-- Jos ei löydy, palautetaan nil.
--
local function find_extra_word (word, data)
    if data == nil then return nil end

    --logfile:write ("find_extra_word a " .. word .. "\n")

    for k, v in ipairs (data) do
        --logfile:write ("find_extra_word b " .. word .. " " .. k .. " " .. v[1] .. " " .. v[2] .. "\n")

        local first, last = utf8.find (utf8.lower(word), utf8.lower(v[1]), 1, true)

        if first ~= nil then
            --logfile:write ("find_extra_word c " .. word .. " " .. v[2] .. " " .. first .. " " .. last .. "\n")
            if first == 1 then
                return v[2]
            end
        end
    end
    --logfile:write ("find_extra_word d " .. word .. " nil\n")
    return nil
end


local function find_index (word, data)
    if data == nil then return nil end

--logfile:write ("find_index a " .. word .. "\n")

    for k, v in ipairs (data) do

--logfile:write ("find_index b " .. word .. " " .. k .. "\n")

        local ww = utf8.lower (word)
        local vv = utf8.lower (v[1]);
        local first, last = utf8.find (ww, vv, 1, true)

--if first ~= nil then logfile:write ("find_index c " .. word .. " " .. first .. " " .. last .. " " .. utf8.len(word) .. " " .. v[1] .. " " .. v[2] .. "\n") end
        if (first ~= nil) and (last == utf8.len(ww)) then
--logfile:write ("find_index d " .. word .. " " .. v[2] .. "\n")
            return v[2]
        end
    end
--logfile:write ("find_index e " .. word .. "\n")
    return nil
end


-- Onko 'word' taulukossa 'extra_word'?
-- Jos on, palautetaan taulukon sana (perusmuoto), muuten palautetaan nil.
--
local function get_extra_word (word, index, extra_word)
--logfile:write ("get_extra_word a " .. word .. "\n")
    local w = find_extra_word (word, extra_word)

    if w ~= nil then
        --logfile:write ("get_extra_word b " .. w .. "\n")
        local u = find_index (w, index)
        if u ~= nil then
            --logfile:write ("get_extra_word c " .. w .. " " .. u .. "\n")
            return u
        end
        --logfile:write ("get_extra_word d " .. w .. "\n")
        return w
    end
    --logfile:write ("get_extra_word e " .. word .. "\n")
    return nil
end


-- Jos 'word' löytyy taulukosta 'index', palautetaan 'index[word]',
-- muuten palautetaan 'wird'.
--
local function find_index_or_original (word, index)
    local u = find_index (word, index)
    if u ~= nil then
        return u
    else
        return word
    end
end

---------------------------------------------------------------------------------


-- Alustetaan taulukot.

local function set_extra (word, extra, count)
    local separator = "|"
--    logfile:write ("set_extra a " .. word .. " " .. count[1] .. "\n")
    local n = utf8.find (word, separator, 1, true)
    if n == nil then
--        logfile:write ("set_extra b " .. word .. " " .. word .. " " .. count[1] .. "\n")
        extra[count[1]] = {word, word}
    else
--        logfile:write ("set_extra c " .. utf8.sub(word,1,n-1) .. " " ..  utf8.gsub (word, separator, "") .. "\n")
        extra[count[1]] = {utf8.sub(word,1,n-1), utf8.gsub (word, separator, "")}
    end
    count[1] = count[1] + 1
end

function u.set_extra_surname (surname)
    set_extra (surname, extra_surname, extra_surname_count)
end

function u.set_extra_place_name (place_name)
    set_extra (place_name, extra_place_name, extra_place_name_count)
end

function u.set_extra_word (word)
    set_extra (word, extra_word, extra_word_count)
end

---------------------------------------------------------------------------------

local function set_index (singular, plural, index, count)
--  logfile:write ("set_index " .. singular .. " " .. plural .. " " .. count[1] .. "\n")
  index[count[1]] = {singular, plural}
  count[1] = count[1] + 1
end

function u.set_surname_index (singular, plural)
  set_index (singular, plural, surname_index, surname_index_count)
end

function u.set_place_name_index (singular, plural)
  set_index (singular, plural, place_name_index, place_name_index_count)
end

function u.set_word_index (singular, plural)
  set_index (singular, plural, word_index, word_index_count)
end


----------------------------------------------------------------------


-- Tavallinen perusmuoto.
--
local function get_baseform (word, f)
    logfile:write ("get_baseform " .. word .. "\n")
    local analysis = Voikko.analyse_word (word)
    local result = Voikko.get_analysis_result (analysis, f, "BASEFORM")
--Voikko.print_table (result)
    return get_strict_result (word, result)
end


-- Jos 'word' on taulukossa extra_word, palautetaan sen perusmuoto taulukosta,
-- muuten palautetaan get_baseform (word, f)
--
local function get_extra_word_or_baseform (word, f, index, extra)
    p = get_extra_word (word, index, extra)
    if p ~= nil then
        return p
    end
    return get_baseform (word, f)
end


local function get_extra_word_or_baseform_or_plural (word, f, index, extra_word)
    p = get_extra_word_or_baseform (word, f, index, extra_word)
    if p == nil then
        error (word .. ": ei perusmuotoa.")
    end
    local q = find_index (p, index)
    if q ~= nil then
         return q
    else
        return p
    end
end


-- Perusmuoto monikossa.
-- Esim. ei Karpaatti vaan Karpaatit.
--
local function get_baseform_plural (word, f, index)
    local bf = get_baseform (word, f)
    if bf == nil then
        return nil
    end
    local result = find_index (bf, index)
    if result ~= nil then
        return result
    else
        return bf
    end
end

----------------------------------------------------------------------

local function get_surname (word)
    function f(a)
      return a["CLASS"] == "sukunimi"
    end
    function g(a)
      return a["CLASS"] == "sukunimi" or a["CLASS"] == "paikannimi" or a["CLASS"] == "etunimi"
    end
    function h(a)
      return a["CLASS"] == "sukunimi" or a["CLASS"] == "nimisana" or a["CLASS"] == "nimisana_laatusana"
    end
    logfile:write ("get_surname a " .. word .. "\n")
    local w = cleanup (word)
    logfile:write ("get_surname b " .. w .. "\n")

    local p = get_extra_word_or_baseform (w, f, surname_index, extra_surname)
    if p == nil then
        p = get_extra_word_or_baseform (w, g, surname_index, extra_surname)
        if p == nil then
            p = get_extra_word_or_baseform (w, h, surname_index, extra_surname)
        end
    end

    if p ~= nil then
        p = utf8.gsub (p, "(%a+)", capitalize)
        logfile:write ("get_surname c " .. p .. "\n")
        return p
    end
    return nil
end


function u.print_surname (word)
    local baseform = get_surname (word)
    if baseform ~= nil then
        tex.sprint (baseform)
    else
        error (word .. ": ei perusmuotoa.")
    end
end


----------------------------------------------------------------------


local function get_place_name (word)
    logfile:write ("get_place_name a " .. word .. "\n")
    function f(a)
        return a["CLASS"] == "paikannimi"
    end
    function g(a)
        return a["POSSIBLE_GEOGRAPHICAL_NAME"] == "true"
    end
    function h(a)
         return a["CLASS"] == "nimisana"   or a["CLASS"] == "nimi" or a["CLASS"] == "etunimi"
    end
    local w = cleanup (word)
    logfile:write ("get_place_name b " .. w .. "\n")

    local list = split (w, "%S+")

    local p = get_extra_word_or_baseform (list[#list], f, place_name_index, extra_place_name)
    if p == nil then
        p = get_extra_word_or_baseform (list[#list], g, place_name_index, extra_place_name)
        if p == nil then
            p = get_extra_word_or_baseform (list[#list], h, place_name_index, extra_place_name)
            if p == nil then
                error (word .. ": ei perusmuotoa.")
            end
        end
    end

    if #list == 1 then
        local u = find_index_or_original (p, place_name_index)
        --logfile:write ("a " .. p .. " " .. u .. "\n")
        local v = capitalize_place_name (u)
        --logfile:write ("b " .. p .. " " .. v .. "\n")
        return v
    else
        local u = table.concat(list," ",1,#list-1) .. " " .. beautify (list[#list], p)
        return u
    end
end


function u.print_place_name (word)
    local baseform = get_place_name (word)
    --logfile:write ("c " .. word .. " " .. baseform .. "\n")
    if baseform ~= nil then
        --logfile:write ("d " .. word .. " " .. baseform .. "\n")
        tex.sprint (baseform)
    else
        error (word .. ": ei perusmuotoa.")
    end
end


----------------------------------------------------------------------


local function get_word (word)
    --logfile:write ("get_word a " .. word .. "\n")
    function f(a)
        return a["CLASS"] == "nimisana" or a["CLASS"] == "nimisana_laatusana" or a["CLASS"] == "lyhenne"
    end
    function g(a)
        return a["CLASS"] == "laatusana"
    end
    local w = cleanup (word)
    --logfile:write ("get_word b " .. w .. "\n")

    local list = split (w, "%S+")

    -- Lyhenteet, joissa on kaksoispiste, esim. '\VXS{AAA:n}'.
    if #list == 1 then
        local u = decolon (list[#list])
        if u ~= nil then
            return u
        end
    end

    local p = get_extra_word_or_baseform (list[#list], f, word_index, extra_word)
    if p == nil then
        p = get_extra_word_or_baseform (list[#list], g, word_index, extra_word)
        if p == nil then
            error (word .. ": ei perusmuotoa.")
        end
    end

    if #list == 1 then
        --logfile:write ("get_word c " .. w .. "\n")
        return beautify (list[#list], find_index_or_original (p, word_index))
    else
        local u = table.concat(list," ",1,#list-1) .. " " .. beautify (list[#list], p)
        --logfile:write ("get_word e " .. u .. "\n")
        return u
    end
    return nil
end


function u.print_word (word)
    local baseform = get_word (word)
    if baseform ~= nil then
        tex.sprint (baseform)
    else
        error (word .. ": ei perusmuotoa.")
    end
end


----------------------------------------------------------------------

local function iterator (word, format)
    local i = 0
    local size = #word
    return function()
        i = i + 1
        if i <= size then
            return word[i], format[i]
        end
    end
end


local function get_bf_value (word, index, extra, klass)
    local function f1(a) return a["CLASS"] == "nimisana"  or a["CLASS"] == "nimisana_laatusana" end
    local function f2(a) return a["CLASS"] == "laatusana" or a["CLASS"] == "nimisana_laatusana" end
    local function f3(a) return a["CLASS"] == "nimisana"  or a["CLASS"] == "laatusana" or
                                a["CLASS"] == "nimisana_laatusana" or
                                a["CLASS"] == "lukusana" or
                                a["CLASS"] == "nimi" or
                                a["CLASS"] == "lyhenne" end
    if klass == "N" then
        return get_extra_word_or_baseform (word, f1, index, extra)
    elseif klass == "L" then
        return get_extra_word_or_baseform (word, f2, index, extra)
    else
        return get_extra_word_or_baseform (word, f3, index, extra)
    end
end


local function get_bf (word, format)
    if format == "=" then
        -- Jos sanaa ei formatoida, sitä ei muuteta perusmuotoonkaan.
        return word
    elseif utf8.sub (format, 1, 1) == "p" then
        return get_place_name (word)
    else
        local p = get_bf_value (word, word_index, extra_word, utf8.sub(format,#format))
        if p == nil then
            p = get_surname (word)
        end
        if p == nil then
            p = get_place_name (word)
        end
        return p
    end
end


local function xprint_formatted (word, format, after, n)
    logfile:write ("print_formatted A [" .. word .. "] [" .. format .. "] [" .. after .. "] [" .. n .. "]\n")
    local uu = cleanup (word)
    local wo = split (uu,  "(%S+)")
    local fo = split (format, "([^,]+)")
    if n > 0 and n ~= #wo then
        error ("Parametrissa 'word' pitää olla " .. n .. " sanaa. On " .. #wo .. " sanaa.")
    end
    if #wo ~= #fo then
        error ("Sanoja ja muotoilukoodeja ei ole yhtä monta.")
    end

    local list = {}
    local text = {}

    for w, f in iterator (wo, fo) do
        local baseform = get_bf (w, f)
        local g = utf8.sub (f, #f)
        if g == "N" or g == "L" then
            g = utf8.sub (f, #f-1, #f-1)
        end
        if utf8.sub (f, 1, 1) == "p" then
            table.insert (text, w .. "\\vxp{" .. baseform .. "}")
        else
            table.insert (text, w)
        end
            if g == "=" then table.insert (list, cleanup (w))
        elseif g == "s" then table.insert (list, beautify (w, baseform))
        elseif g == "a" then table.insert (list, utf8.lower (baseform))
        elseif g == "i" then table.insert (list, capitalize (baseform))
        elseif g == "y" then table.insert (list, utf8.upper (baseform))
        else
            error ("Väärä muotoilukoodi '" .. g .. "'.")
        end
    end
    local orig   = table.concat (text, " ")
    local result = table.concat (list, " ")

    if after == "-NoValue-" then
        return (orig .. "\\sindex[sanat]{" .. result .. "}")
    else
        return (orig .. after .. "\\sindex[sanat]{" .. result .. "}")
    end
end


function u.print_formatted (word, format, after, n)
    tex.sprint (xprint_formatted (word, format, after, n))
end


-- Merkkijonon kaikki kirjaimet pienellä.
--
function u.print_word_lowercase (word)
    local baseform = get_word (word)
    local b = utf8.lower (baseform)
    tex.sprint (b)
end


-- Merkkijonon kaikki kirjaimet isolla.
--
function u.print_word_uppercase (word)
    local baseform = get_word (word)
    local b = utf8.upper(baseform)
    logfile:write ("print_word_uppercase " .. word .. " " .. baseform .. " " .. b .. "\n")
    tex.sprint (b)
end


-- Perusmuodossa eka kirjain isolla, muut pienellä, esim: sUoMelle -> Suomi
--
function u.print_word_capitalize (word)
    local baseform = get_word (word)
    local b = capitalize (baseform)
    logfile:write ("print_word_capitalize " .. word .. " " .. baseform .. " " .. b .. "\n")
    tex.sprint (b)
end


function u.print_x (word, format, noword, after)
    local s = xprint_formatted (word, format, after, 0)
    s = utf8.gsub (s, "}$", " " .. noword .. "}") 
    tex.sprint (s)
end

----------------------------------------------------------------------


return u
