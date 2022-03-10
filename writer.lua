require 'pandoc.utils'

local OUTPUT_FORMAT = PANDOC_DOCUMENT.meta.custom_writer_format or "html"
local notes = {}

-- Helpers
local function attributes(attr)
  -- Converts to pandoc.Attr from AttributeList 
  -- AttributeList is in the form of [("id", "foo"), ("class", "a b"), ...]
  local identifier = table.remove(attr, 1)[2]
  local classes = {}
  for _v in string.gmatch(table.remove(attr, 1)[2], "[^%s]+") do
    table.insert(classes, _v) 
  end
  return pandoc.Attr(identifier, classes, attr)
end

local function raw_inline(x)
  return pandoc.RawInline(OUTPUT_FORMAT, x)
end

local function write(blocks, kwargs)
  -- Write a block or list of blocks into the OUTPUT_FORMAT
  -- If a inline of list of inlines are given, pandoc coverts them to a list of
  -- inlines in a Plain block
  local kwargs = kwargs or {}
  local buffer = pandoc.write(
    pandoc.Pandoc(blocks, kwargs.meta or PANDOC_DOCUMENT.meta),
    kwargs.format or OUTPUT_FORMAT, 
    kwargs.writer_options or PANDOC_WRITER_OPTIONS
  )
  return string.gsub(buffer, '\n$', '')
end

-- Special writers
function Blocksep()
  -- separater of block elements.
  return '\n\n'
end

function Doc(body, metadata, variables)
  -- output
  if #notes == 0 then return body .. '\n' end
  local footnotes = #notes == 0 and '' or (
    '\n\n' .. write(pandoc.Div(
    pandoc.OrderedList(notes), {class = 'footnotes'}
  )))
  return body .. footnotes .. '\n'
end

--[[
The functions that follow render corresponding pandoc elements.
s: string
items: array of strings
attr: table of attributes (AttributeList)
]]


-- Define writers for types whose constructors only needs the list of elements.
-- The defined functions internally treat input string as a raw inline to avoid
-- recursive escaping of characters. Exceptionally, Str and Note have their own
-- definitions because Str escapes characters, and Note does complex things.
local function define_raw_writer(t)
  return function(s)
    return write(pandoc[t](raw_inline(s)))
  end
end

for _, _t in ipairs({
  -- block
  "Para", "BlockQuote", "Plain",
  -- inline
  "Emph", "Strong", "Subscript", "Superscript", "SmallCaps", "Strikeout"
}) do
  _G[_t] = define_raw_writer(_t)
end

-- Inlines
function Str(s)
  return write(pandoc.Str(s))
end

function Note(s)
  local num = #notes + 1
  -- add a list item with the note to the note table.
  table.insert(
    notes,
    pandoc.Link(raw_inline(s), '#fnref' .. num, nil, {id = 'fn' .. num})
  )
  -- return the footnote reference, linked to the note.
  return write(pandoc.Superscript(pandoc.Link(
    tostring(num), '#fn' .. num, nil, {id = 'fnref' .. num}
  )))
end

function SingleQuoted(s)
  return write(pandoc.SingleQuoted("DoubleQuote", raw_inline(s)))
end

function DoubleQuoted(s)
  return write(pandoc.Quoted("DoubleQuote", raw_inline(s)))
end

function InlineMath(s)
  return write(pandoc.Math("InlineMath", s))
end

function DisplayMath(s)
  return write(pandoc.Math("DisplayMath", s))
end

function Space()
  return ' '
end

function SoftBreak()
  -- pandoc.SoftBreak()を返すと空白がなくなる
  -- {Str(''), SoftBreak(), Str('')}でもだめ
  -- return write(pandoc.Space())
  return "\n"
end

function LineBreak()
  return write(pandoc.LineBreak())
end

function Link(s, tgt, tit, attr)
  return write(pandoc.Link(raw_inline(s), tgt, tit, attributes(attr)))
end

function Image(s, src, tit, attr)
  return write(pandoc.Image(raw_inline(s), src, tit, attributes(attr)))
end

function Code(s, attr)
  return write(pandoc.Code(s, attributes(attr)))
end

function Span(s, attr)
  return write(pandoc.Span(raw_inline(s), attributes(attr)))
end

function RawInline(format, str)
  return write(pandoc.RawInline(format, str))
end

function Cite(s, cs)
  return write(pandoc.Cite(raw_inline(s), cs))
end

-- Blocks
function Header(lev, s, attr)
  return write(pandoc.Header(lev, raw_inline(s), attributes(attr)))
end

function HorizontalRule()
  return write(pandoc.HorizontalRule())
end

function LineBlock(items)
  return write(pandoc.LineBlock(raw_inline(table.concat(items, '\n'))))
end

function CodeBlock(s, attr)
  return write(pandoc.CodeBlock(s, attributes(attr)))
end

local function itemize(items)
  -- convert table of strings into table of RawInlines
  raw_items = {}
  for _, item in ipairs(items) do
    table.insert(raw_items, raw_inline(item))
  end
  return raw_items
end

function BulletList(items)
  return write(pandoc.BulletList(itemize(items)))
end

function OrderedList(items, list_attributes)
  return write(pandoc.OrderedList(itemize(raw_items), list_attributes))
end

function DefinitionList(items)
  return write(pandoc.DefinitionList(itemize(items)))
end

function CaptionedImage(src, tit, caption, attr)
  -- TODO: figcaptionにaria-hidden="true"が入らない
  local attr = attributes(attr)
  if not attr.attributes.attr then
    -- これがないとなぜかaltが空になる
    -- captionはOUTPUT_FORMATに従うので文字列に戻す必要あり
    attr.attributes.alt = pandoc.utils.stringify(
      pandoc.read(caption, OUTPUT_FORMAT)
    )
  end 
  return write(pandoc.Para(pandoc.Image(raw_inline(caption), src, tit, attr)))
end

function Table(caption, aligns, widths, headers, rows)
  raw_headers = {}
  for _, _h in ipairs(headers) do
    table.insert(raw_headers, raw_inline(_h))
  end
  raw_rows = {}
  raw_cells = {}
  for _, _cells in ipairs(rows) do
    raw_cells = {}
    for _, _cell in ipairs(_cells) do
      table.insert(raw_cells, raw_inline(_cell))
    end
    table.insert(raw_rows, raw_cells)
  end
  local tbl = pandoc.SimpleTable(
    raw_inline(caption),
    aligns,
    widths,
    raw_headers,
    raw_rows
  )
  return write(pandoc.utils.from_simple_table(tbl))
end

function RawBlock(format, str)
  return write(pandoc.RawBlock(format, str))
end

function Div(s, attr)
  return write(pandoc.Div(raw_inline(s), attributes(attr)))
end

-- The following code will produce runtime warnings when you haven't defined
-- all of the functions you need for the custom writer, so it's useful
-- to include when you're working on a writer.
local meta = {}
meta.__index =
  function(_, key)
    io.stderr:write(string.format("WARNING: Undefined function '%s'\n",key))
    return function() return '' end
  end
setmetatable(_G, meta)
