-- Copyright (©) 2021 Hannu Väisänen
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
    version   = 0.1,
    comment   = "Käytetään Voikkoa muuttamaan indeksoitavat sanat perusmuotoon.",
    author    = "Hannu Väisänen",
    copyright = "Hannu Väisänen",
    license   = "See later."
}


Voikko = require "Voikko"

logfile = nil
io.open ("voikkoindex.log", "w")

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

-- Muuta sanan eka kirjain isoksi ja muut pieneksi.
--
local function capitalize (word)
  local b = utf8.title(utf8.sub(word,1,1)) .. utf8.lower(utf8.sub(word,2))
  return b
end


local function find_extra_word (word, data)
  if data == nil then return nil end

--  logfile:write ("find_extra_word a " .. word .. "\n")

  for k, v in ipairs (data) do
--    logfile:write ("find_extra_word b " .. word .. " " .. k .. " " .. v[1] .. " " .. v[2] .. "\n")

    local first, last = utf8.find (utf8.lower(word), utf8.lower(v[1]), 1, true)

    if first ~= nil then
--      logfile:write ("find_extra_word c " .. word .. " " .. v[2] .. " " .. first .. " " .. last .. "\n")
      return v[2]
    end
  end
--  logfile:write ("find_extra_word d " .. word .. " nil\n")
  return nil
end


local function find_index (word, data)
  if data == nil then return nil end

--logfile:write ("find_index a " .. word .. "\n")

 for k, v in ipairs (data) do

--logfile:write ("find_index b " .. word .. " " .. k .. "\n")

    local first, last = utf8.find (word, v[1], 1, true)
--if first ~= nil then logfile:write ("find_index c " .. word .. " " .. first .. " " .. last .. " " .. utf8.len(word) .. " " .. v[1] .. " " .. v[2] .. "\n") end
    if (first ~= nil) and (last == utf8.len(word)) then
--logfile:write ("find_index d " .. word .. " " .. v[2] .. "\n")
      return v[2]
    end
  end
--logfile:write ("find_index e " .. word .. "\n")
  return nil
end


local function cleanup (s)
  logfile:write ("cleanup1 [" .. s .. "]\n")
  --                      Ehdollinen ta\-vutus tulee tällaiseksi!
--local t = utf8.gsub (s, "\\protect \\discretionary {\\char \\hyphenchar \\font }{}{}", "\\-")
  local t = utf8.gsub (s, "\\protect [\\][-]", "")
--  logfile:write ("cleanup2 [" .. s .. "]\n")
  t = utf8.gsub (t, "\"", "")
  t = utf8.gsub (t, "\\protect \\emph  {", "")
  t = utf8.gsub (t, "\n", " ")
  t = utf8.gsub (t, "\\emph{", "")
  t = utf8.gsub (t, "[,.]}", "")
  t = utf8.gsub (t, "}", "")
  return t
end


-- Jaetaan merkkijono 'word' sanoihin, joiden erottimena on säännöllinen lauseke 'regex'
-- ja palautetaan ne taulukkona.
-- Esim. split ("Tämä on esimerkki.", "%S+") => "Tämä" "on" "esimerkki."
--
function split (word, regex)
  --logfile:write ("Split a " .. word .. "\n")
  local list = {}
  for w in utf8.gmatch (word, regex) do
    table.insert (list, w)
    --logfile:write ("Split b " .. w .. "\n")
  end
  return list
end

----------------------------------------------------------------------

-- Oletetaan, että funktiota cleanup(word) on kutsuttu ennen tämän funktion kutsumista.
--
local function find_baseform (word, index, extra_word, f)
  logfile:write ("find_baseform a " .. word .. "\n")

  if f ~= nil then
    local b1 = u.get_baseform2 (word, f)
    if b1 ~= nil then
      logfile:write ("find_baseform b " .. b1 .. "\n")
      local result = find_index (b1, index)
      if result ~= nil then
        logfile:write ("find_baseform c " .. result .. "\n")
        return result
      else
        return b1
      end
    end
  end

  local b2 = u.get_baseform (word)
  if b2 ~= nil then
    logfile:write ("find_baseform d " .. b2 .. "\n")
    local result = find_index (b2, index)
    if result ~= nil then
      logfile:write ("find_baseform e " .. result .. "\n")
      return result
    else
      return b2
    end
  end

  logfile:write ("find_baseform f " .. word .. "\n")

  local w = find_extra_word (word, extra_word)
  if w ~= nil then
    local u = find_index (w, index)
    if u ~= nil then
      logfile:write ("find_baseform g " .. w .. " " .. u .. "\n")
      return u
    end
    logfile:write ("find_baseform h " .. w .. "\n")
    return w
  end

  logfile:write ("find_baseform ö " .. word .. ": ei perusmuotoa.\n")
  return nil
end

----------------------------------------------------------------------


function u.init_voikkoindex (langcode, path, logf)
  Voikko.init (langcode, path)
  logfile = io.open (logf, "w")
end


function u.terminate_voikkoindex()
  Voikko.terminate()
end


local function all_same (result)
  for i = 2, #result, 1 do
    if utf8.ncasecmp (result[1],result[i]) ~= 0 then
      return false
    end
  end
  return true
end


local function get_strict_result (word, result)
  for i = 1, #result do logfile:write (result[i] .. "\n") end

  if #result == 0 then
    logfile:write (word .. ": ei perusmuotoa A.\n")
    return nil
  elseif #result > 1 then
    if all_same (result) then
      logfile:write (word .. ": perusmuoto: " .. result[1] .. " B.\n")
      return result[1]
    else
      logfile:write (word .. ": useampi kuin yksi perusmuoto C.\n")
      return nil
    end
  else
    logfile:write (word .. ": perusmuoto: " .. result[1] .. ".\n")
    return result[1]
  end
end


function u.get_baseform (word)
  local analysis = Voikko.analyse_word (word)
  local result = Voikko.get_analysis_property_value (analysis, "BASEFORM")
  return get_strict_result (word, result)
end


function u.get_baseform2 (word, f)
  logfile:write ("get_baseform2 " .. word .. "\n")
  local analysis = Voikko.analyse_word (word)
  local result = Voikko.get_analysis_result (analysis, f, "BASEFORM")
  return get_strict_result (word, result)
end


function u.get_surname (word)
  function f(a)
    return a["CLASS"] == "sukunimi"
  end
  logfile:write ("get_surname a " .. word .. "\n")
  local w = cleanup (word)
  logfile:write ("get_surname b " .. w .. "\n")
  local s = find_baseform (w, surname_index, extra_surname, f)
  if s == nil then
    logfile:write ("get_surname: " .. word .. ": ei perusmuotoa\n")
     return nil
  end
  logfile:write ("get_surname c " .. s .. "\n")
  local u = utf8.gsub (s, "(%a+)", capitalize)
  return u
end


function u.get_place_name (word)
  logfile:write ("get_place_name a " .. word .. "\n")
  function f(a)
    return a["CLASS"] == "paikannimi" or a["POSSIBLE_GEOGRAPHICAL_NAME"] == "true"
  end
  local w = cleanup (word)
  local s = find_baseform (w, place_name_index, extra_place_name, f)

  if s ~= nil then
    logfile:write ("get_place_name b " .. w .. " " .. s .. "\n")
    local u = utf8.gsub (s, "(%a+)", capitalize)
    logfile:write ("get_place_name c " .. w .. " " .. u .. "\n")
    return u
  end

  return s
end


----------------------------------------------------------------------

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


-- Palautaan 'u':n ja 'v':n yhteinen alkuosa.
-- Esim. ('abcd" 'abcxyx') -> abc
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


local function beautify (s, t)
  if s == nil or t == nil then
    error ("beautify: s == nil or t ==  nil")
  end
  local n = common_prefix_index (s, t)
  if n == 0 then
    return ""
  end
  local x = utf8.sub (s, 1, n)
  local y = utf8.sub (t, n+1)
  local z = x .. y
  assert (z ~= nil)
--  --logfile:write ("beautify " .. s .. " " .. t .. "\n")
  return z
end


-- Muutetaan merkkijono 'word' merkkijonoksi, joka voidaan laittaa hakemistoon.
--
local function get_indexed_word_f (word, extra_word, classf)
  --logfile:write ("get_indexed_word a [" .. word .. "]\n")
  local w = cleanup (word)
  --logfile:write ("get_indexed_word b [" .. w .. "]\n")

  local list = split (w, "%S+")

  --logfile:write ("get_indexed_word c [" .. w .. "]\n")

  logfile:write ("get_indexed_word c [" .. list[#list] .. "]\n")

  local s = find_baseform (list[#list], word_index, extra_word, classf)

  if s ~= nil then
    logfile:write ("get_indexed_word d [" .. s .. "]\n")
    if #list > 1 then
      local u = table.concat(list," ",1,#list-1) .. " " .. beautify (list[#list], s)
      logfile:write ("get_indexed_word e [" .. u .. "]\n")
      return u
    else
      local u =  beautify (list[#list], s)
      logfile:write ("get_indexed_word f [" .. u .. "]\n")
      return u
    end
  end

  if #list == 1 then
    local baseform = decolon (w)
    if baseform ~= nil then
       return baseform
    end
  end

  return nil
end


function u.get_indexed_word (word, extra_word)
  local function classf (a)
    return a["CLASS"] == "nimisana" or a["CLASS"] == "laatusana" or a["CLASS"] == "nimisana_laatusana"
  end
  return get_indexed_word_f (word, extra_word, classf)
end

----------------------------------------------------------------------


function u.print_baseform (word)
  local w = cleanup (word)
  local baseform = u.get_baseform (w)
  if baseform ~= nil then
    tex.sprint (baseform)
  else
    error (word .. ": ei perusmuotoa.")
  end
end


function u.print_surname (word)
  local baseform = u.get_surname (word)
  if baseform ~= nil then
    tex.sprint (baseform)
  else
    error (word .. ": ei perusmuotoa.")
  end
--  tex.print (baseform)
end


function u.print_place_name (word)
  local baseform = u.get_place_name (word)
  if baseform ~= nil then
    tex.sprint (baseform)
  else
    error (word .. ": ei perusmuotoa.")
  end
--  tex.print (baseform)
end



function u.print_word (word)
  logfile:write ("print_word a [" .. word .. "]\n")
  local baseform = u.get_indexed_word (word, extra_word)
  if baseform ~= nil then
    logfile:write ("print_word b [" .. baseform .. "]\n")
    tex.sprint (baseform)
  else
    error ("word " .. word .. ": ei perusmuotoa.")
  end
end


function u.print_word_lowercase (word)
  local w = utf8.lower (word)
  local baseform = u.get_indexed_word (w, extra_word)
  if baseform ~= nil then
    local b = utf8.lower (baseform)
    tex.sprint (b)
  else
    error ("word " .. word .. ": ei perusmuotoa.")
  end
end


function u.print_word_uppercase (word)
  local w = utf8.lower (word)
  local baseform = u.get_indexed_word (w, extra_word)
  if baseform ~= nil then
    local b = utf8.upper (baseform)
    tex.sprint (b)
  else
    error ("word " .. word .. ": ei perusmuotoa.")
  end
end


-- Perusmuodossa eka kirjain isolla, muut pienellä, esim: sUoMelle -> Suomi
--
function u.print_word_capitalize (word)
  local baseform = u.get_indexed_word (word, extra_word)
  if baseform ~= nil then
    local b = utf8.lower (baseform)
    b = utf8.gsub (b, "(%a+)", capitalize)
    tex.sprint (b)
  else
    error ("word " .. word .. ": ei perusmuotoa.")
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


local function get_bf_value (word, extra_word, klass)
  local function f1(a) return a["CLASS"] == "nimisana" or a["CLASS"] == "nimilaatusana" end
  local function f2(a) return a["CLASS"] == "laatusana" or a["CLASS"] == "nimilaatusana" end
  local function f3(a) return a["CLASS"] == "nimisana" or a["CLASS"] == "laatusana" or a["CLASS"] == "nimilaatusana" end

  if klass == "N" then
    return get_indexed_word_f (word, extra_word, f1)
  elseif klass == "L" then
    return get_indexed_word_f (word, extra_word, f2)
  else
    return get_indexed_word_f (word, extra_word, f3)
  end
end


local function get_bf (word, format)
  local function fun1(a) return a["CLASS"] == "nimisana" or a["CLASS"] == "nimilaatusana" end

  if format == "=" then
    -- Jos sanaa ei formatoida, sitä ei tarvitse muuttaa perusmuotoon.
    --
    return word
  elseif utf8.sub (format, 1, 1) == "p" then
    return u.get_place_name (word)
  else
--    local p = get_indexed_word_f (word, extra_word, fun1)
    local p = get_bf_value (word, extra_word, utf8.sub(format,#format))
--logfile:write ("get_bf A " .. p .. " " .. format .. " " .. #format .. " " .. utf8.sub(format,#format) .. "\n")
    if p == nil then
      p = u.get_surname (word)
    end
    if p == nil then
      p = u.get_place_name (word)
    end
    return p
  end
end


function u.print_formatted (word, format, after, n)
  logfile:write ("print_formatted A [" .. word .. "] [" .. format .. "] [" .. after .. "] [" .. n .. "]\n")
  local uu = cleanup (word)
  local wo = split (uu,  "([%a-]+)")
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
    logfile:write ("print_formatted B " .. w .. " " .. f .. "\n")
    local baseform = get_bf (w, f)
    logfile:write ("print_formatted B " .. baseform .. " " .. utf8.sub (f, 1, 1) .. "\n")
    local g = utf8.sub (f, #f)
--logfile:write ("print formatted 1 " .. word .. " " .. format .. " " .. g .. "\n")
    if g == "N" or g == "L" then
      g = utf8.sub (f, #f-1, #f-1)
    end
--logfile:write ("print formatted 2 " .. word .. " " .. format .. " " .. g .. "\n")
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
    else error ("Väärä muotoilukoodi '" .. g .. "'.")
    end
  end
  local orig = table.concat (text, " ")
  local result = table.concat (list, " ")
--  logfile:write ("print_formatted C " .. result .. "\n")
--  logfile:write ("print_formatted D " .. orig .. "\n")
--  for i = 1, #list do
--    logfile:write ("print_formatted E " .. list[i] .."\n")
--  end
  if after == "-NoValue-" then
    tex.sprint (orig .. "\\sindex[sanat]{" .. result .. "}")
  else
    tex.sprint (orig .. after .. "\\sindex[sanat]{" .. result .. "}")
  end
end

----------------------------------------------------------------------

local separator = "|"

local function set_extra (word, extra, count)
  --logfile:write ("set_extra a " .. word .. " " .. count[1] .. "\n")
  local n = utf8.find (word, separator, 1, true)
  if n == nil then
    --logfile:write ("set_extra b " .. word .. " " .. word .. " " .. count[1] .. "\n")
    extra[count[1]] = {word, word}
  else
    --logfile:write ("set_extra c " .. utf8.sub(word,1,n-1) .. " " ..  utf8.gsub (word, separator, "") .. "\n")
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

----------------------------------------------------------------------

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

return u
