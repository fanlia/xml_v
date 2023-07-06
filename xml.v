
fn is_space(r rune) bool { return u8(r).is_space() }

struct Parser {
  source string
mut:
  index int
}

fn (mut p Parser) skip_whitespace() {
  for p.match_char(is_space, true) {}
}

fn (mut p Parser) parse_until(predict fn(rune) bool) string {
  start := p.index
  for p.match_char(predict, true) {}
  return p.source[start .. p.index]
}

fn (mut p Parser) is_char(ch rune, advance bool) bool {
  return p.match_char(fn [ch] (r rune) bool { return ch == r }, advance)
}

fn (mut p Parser) match_char(predict fn(rune) bool, advance bool) bool {
  if ch, index := p.peek_char() {
    if predict(ch) {
      if advance {
        p.index = index
      }
      return true
    }
    return false
  } else {
    return false
  }
}

fn (mut p Parser) next_char() ?rune {
  if ch, index := p.peek_char() {
    p.index = index
    return ch
  } else {
    return none
  }
}

fn (mut p Parser) peek_char() ?(rune, int) {
  if p.index >= p.source.len {
    return none
  }
  start := p.index
  char_len := utf8_char_len(unsafe { p.source.str[start] })
  end := if p.source.len - 1 >= p.index + char_len { p.index + char_len } else { p.source.len }
  r := unsafe { p.source[start .. end] }
  ch := r.utf32_code()
  return ch, end
}

struct XMLParser {
  Parser
  on_open_tag fn(tag Tag)
  on_text fn(text string)
  on_close_tag fn(name string)
}

fn (mut p XMLParser) parse() {
  for p.parse_tag() {}
  println('index=${p.index}, len=${p.source.len}')
}

fn (mut p XMLParser) parse_tag() bool {
  p.skip_whitespace()
  start := p.index

  if ch := p.next_char() {
    match ch {
      `<` {
        for p.match_char(fn (r rune) bool { return r != `>` }, true) {}
        // consume >
        p.next_char()
        tag_str := p.source[start .. p.index]

        tag := build_tag(tag_str)

        if tag.is_close {
          p.on_close_tag(tag.name)
        } else {
          p.on_open_tag(tag)
          if tag.is_self_close {
            p.on_close_tag(tag.name)
          }
        }
      }
      else {
        for p.match_char(fn (r rune) bool { return r != `<` }, true) {}
        text := p.source[start .. p.index].trim_space()
        p.on_text(text)
      }
    }
    return true
  } else {
    return false
  }
}

struct TagParser {
  Parser
}

struct Tag {
pub:
  name string
  attributes map[string]string
  is_close bool
  is_self_close bool
}

fn (mut p TagParser) parse() Tag {
  // consume <
  p.next_char()

  p.skip_whitespace()

  is_close := p.is_char(`/`, true)

  p.skip_whitespace()

  name := p.parse_until(fn (r rune) bool { return !(is_space(r) || r == `/` || r == `>`) })

  mut attributes := map[string]string{}

  for p.match_char(fn (r rune) bool { return !(r == `/` || r == `>`) }, false) {
    p.skip_whitespace()

    if p.match_char(fn (r rune) bool { return r == `/` || r == `>` }, false) {
      break
    }

    attribute_name := p.parse_until(fn (r rune) bool { return r != `=` })

    // consume =
    p.next_char()

    p.skip_whitespace()

    attribute_value := p.parse_until(fn (r rune) bool { return !(is_space(r) || r == `/` || r == `>`) })

    attributes[attribute_name] = attribute_value.trim('"')
  }

  is_self_close := p.is_char(`/`, true)

  // consume >
  p.next_char()

  return Tag {
    name: name,
    attributes: attributes,
    is_close: is_close,
    is_self_close: is_self_close,
  }
}

fn build_tag(source string) Tag {
  mut parser := TagParser { source: source }
  return parser.parse()
}

fn main() {
xml := '
<root>
  abc
  <item ok="true">999</item>
  <status ok="false" />
</root>
'
//   xml := '
// <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
// <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><fileVersion appName="xl" lastEdited="3" lowestEdited="5" rupBuild="9302"/><workbookPr/><bookViews><workbookView windowWidth="25200" windowHeight="12090"/></bookViews><sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets><definedNames><definedName name="_xlnm._FilterDatabase" localSheetId="0" hidden="1">Sheet1!\$A\$1:\$N\$1000</definedName></definedNames><calcPr calcId="144525"/></workbook>
// '

  mut parser := XMLParser {
    source: xml,
    on_open_tag: on_open_tag,
    on_text: on_text,
    on_close_tag: on_close_tag,
  }

  parser.parse()

}

fn on_open_tag(tag Tag) {
  println('on_open_tag: ${tag}')
}

fn on_text(text string) {
  println('on_text: ${text}')
}

fn on_close_tag(name string) {
  println('on_close_tag: ${name}')
}
