use serde::Serialize;
use std::fs;
use std::process;

#[derive(Serialize)]
struct BindEntry {
    category: String,
    keys: String,
    description: String,
    cmd: Option<String>,
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: parse_binds <binds.lua>");
        process::exit(1);
    }

    let input = match fs::read_to_string(&args[1]) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("Error reading {}: {}", args[1], e);
            process::exit(1);
        }
    };

    let binds = parse_binds(&input);
    println!("{}", serde_json::to_string_pretty(&binds).unwrap());
}

fn parse_binds(input: &str) -> Vec<BindEntry> {
    let expanded = expand_for_loops(input);
    let mut binds = Vec::new();
    let mut category = "General".to_string();
    let bytes = expanded.as_bytes();
    let len = bytes.len();
    let mut i = 0;

    while i < len {
        // Skip whitespace and newlines
        if bytes[i].is_ascii_whitespace() {
            i += 1;
            continue;
        }

        // Category comment: -- Text
        if i + 2 < len && bytes[i] == b'-' && bytes[i + 1] == b'-' && bytes[i + 2] == b' ' {
            let start = i + 3;
            let end = find_line_end(bytes, start);
            category = expanded[start..end].trim().to_string();
            i = end;
            continue;
        }

        // hl.bind(
        if starts_with(bytes, i, "hl.bind(") {
            let body_start = i + 8;
            match find_closing_paren(bytes, body_start) {
                Some(body_end) => {
                    let body = &expanded[body_start..body_end];
                    if let Some(entry) = parse_bind_body(body, &category) {
                        binds.push(entry);
                    }
                    i = body_end + 1;
                    continue;
                }
                None => {
                    i += 1;
                    continue;
                }
            }
        }

        // Skip everything else (comments, function defs, etc)
        // Skip to next line
        let next = find_line_end_or_pipe(bytes, i);
        i = next;
    }

    binds
}

fn find_line_end(bytes: &[u8], start: usize) -> usize {
    let mut pos = start;
    while pos < bytes.len() && bytes[pos] != b'\n' {
        pos += 1;
    }
    pos
}

fn find_line_end_or_pipe(bytes: &[u8], start: usize) -> usize {
    let mut pos = start;
    while pos < bytes.len() && bytes[pos] != b'\n' {
        pos += 1;
    }
    if pos < bytes.len() {
        pos + 1
    } else {
        pos
    }
}

fn starts_with(bytes: &[u8], pos: usize, s: &str) -> bool {
    let sb = s.as_bytes();
    if pos + sb.len() > bytes.len() {
        return false;
    }
    &bytes[pos..pos + sb.len()] == sb
}

fn find_closing_paren(bytes: &[u8], start: usize) -> Option<usize> {
    let mut depth = 1;
    let mut pos = start;
    while pos < bytes.len() {
        match bytes[pos] {
            b'(' => depth += 1,
            b')' => {
                depth -= 1;
                if depth == 0 {
                    return Some(pos);
                }
            }
            b'"' | b'\'' => {
                // Skip string literals
                let quote = bytes[pos];
                pos += 1;
                while pos < bytes.len() && bytes[pos] != quote {
                    if bytes[pos] == b'\\' {
                        pos += 1;
                    }
                    pos += 1;
                }
            }
            b'-' if pos + 1 < bytes.len() && bytes[pos + 1] == b'-' => {
                // Skip line comments
                pos = find_line_end(bytes, pos);
                continue;
            }
            _ => {}
        }
        pos += 1;
    }
    None
}

fn expand_for_loops(input: &str) -> String {
    let mut result = String::new();
    let bytes = input.as_bytes();
    let len = bytes.len();
    let mut i = 0;

    while i < len {
        // Skip whitespace
        if bytes[i].is_ascii_whitespace() {
            result.push(bytes[i] as char);
            i += 1;
            continue;
        }

        // Skip `--` comments (but preserve them for category parsing)
        if i + 2 < len && bytes[i] == b'-' && bytes[i + 1] == b'-' {
            let end = find_line_end(bytes, i);
            result.push_str(&input[i..end]);
            result.push('\n');
            i = end + 1;
            continue;
        }

        // for _, VAR in ipairs({...}) do
        if let Some((var, values, body_start, body_end)) = try_parse_ipairs_for(bytes, i) {
            let body = &input[body_start..body_end];
            let body = expand_for_loops(body);
            for value in &values {
                let replaced = body.replace(&format!(" {}", var), &format!(" \"{}\"", value));
                result.push_str(&replaced);
                result.push('\n');
            }
            i = body_end;
            // skip the `end` keyword and any trailing content on that line
            while i < len && bytes[i] != b'\n' {
                i += 1;
            }
            if i < len {
                i += 1;
            }
            continue;
        }

        // for VAR = START, END do
        if let Some((var, start_val, end_val, body_start, body_end, alias)) =
            try_parse_range_for(bytes, i)
        {
            let body = &input[body_start..body_end];
            let body = expand_for_loops(body);
            for n in start_val..=end_val {
                let s = n.to_string();
                let mut replaced = body.replace(&format!(" {}", var), &format!(" {}", s));
                if let Some((alias_var, alias_fn)) = &alias {
                    if alias_fn == "tostring" {
                        let alias_val = format!("\"{}\"", s);
                        replaced = replaced.replace(&format!(" {}", alias_var), &format!(" {}", alias_val));
                    }
                }
                result.push_str(&replaced);
                result.push('\n');
            }
            i = body_end;
            while i < len && bytes[i] != b'\n' {
                i += 1;
            }
            if i < len {
                i += 1;
            }
            continue;
        }

        result.push(bytes[i] as char);
        i += 1;
    }

    result
}

fn try_parse_ipairs_for(
    bytes: &[u8],
    start: usize,
) -> Option<(String, Vec<String>, usize, usize)> {
    // Match: for _, VAR in ipairs({VAL1, VAL2, ...}) do
    let s = std::str::from_utf8(&bytes[start..]).ok()?;
    let s_trimmed = s.trim_start();

    if !s_trimmed.starts_with("for _, ") {
        return None;
    }

    let after_for = s_trimmed.strip_prefix("for _, ")?;
    let var_end = after_for.find(' ')?;
    let var = after_for[..var_end].to_string();

    let rest = after_for[var_end..].trim_start();
    if !rest.starts_with("in ipairs(") {
        return None;
    }

    let after_ipairs = rest.strip_prefix("in ipairs(")?;

    let abs_ipairs_start = start + (s.len() - after_ipairs.len());
    let paren_end = find_closing_paren(bytes, abs_ipairs_start)?;
    let values_str = &s_trimmed[s_trimmed.len() - after_ipairs.len()..paren_end - start];

    // Parse the values
    let values_content = values_str
        .trim()
        .strip_prefix('{')
        .and_then(|s| s.strip_suffix('}'))
        .unwrap_or(values_str);

    let values: Vec<String> = values_content
        .split(',')
        .map(|v| {
            v.trim()
                .trim_matches('"')
                .trim()
                .trim_matches('\'')
                .to_string()
        })
        .filter(|v| !v.is_empty())
        .collect();

    if values.is_empty() {
        return None;
    }

    // Find `do`
    let _after_ipairs_paren = start + (values_str.len() + values_str.as_ptr() as usize - s.as_ptr() as usize);
    let do_pos = find_word(bytes, abs_ipairs_start + values_str.len(), "do")?;
    let body_start = do_pos + 2;

    // Find `end`
    let end_pos = find_word_at_level(bytes, body_start, "end", 0)?;
    let body_end = end_pos;

    Some((var, values, body_start, body_end))
}

fn try_parse_range_for(
    bytes: &[u8],
    start: usize,
) -> Option<(String, i32, i32, usize, usize, Option<(String, String)>)> {
    let s = std::str::from_utf8(&bytes[start..]).ok()?;
    let s_trimmed = s.trim_start();

    if !s_trimmed.starts_with("for ") {
        return None;
    }

    let after_for = s_trimmed.strip_prefix("for ")?;
    let var_end = after_for.find(' ')?;
    let var = after_for[..var_end].to_string();

    let rest = after_for[var_end..].trim_start();
    if !rest.starts_with("= ") {
        return None;
    }

    let after_eq = rest.strip_prefix("= ")?;
    let range_parts: Vec<&str> = after_eq.splitn(2, ',').collect();
    if range_parts.len() < 2 {
        return None;
    }
    let start_val: i32 = range_parts[0].trim().parse().ok()?;
    let end_str = range_parts[1].trim().split_whitespace().next()?;
    let end_val: i32 = end_str.parse().ok()?;

    // Find `do`
    let abs_start = start + (s.len() - s_trimmed.len());
    let do_pos = find_word(bytes, abs_start, "do")?;
    let body_start = do_pos + 2;

    // Read body to find `end`
    let end_pos = find_word_at_level(bytes, body_start, "end", 0)?;
    let body = &input_to_str(bytes)[body_start..end_pos];

    // Check for local alias = tostring(var)
    let mut alias: Option<(String, String)> = None;
    for line in body.lines() {
        let line = line.trim();
        if let Some(rest) = line.strip_prefix("local ") {
            if let Some(eq_pos) = rest.find(" = ") {
                let alias_var = rest[..eq_pos].trim().to_string();
                let rhs = rest[eq_pos + 3..].trim();
                // tostring(VAR)
                if rhs.starts_with("tostring(") && rhs.ends_with(')') {
                    let inner = &rhs[9..rhs.len() - 1];
                    if inner.trim() == var {
                        alias = Some((alias_var, "tostring".to_string()));
                    }
                }
            }
        }
    }

    Some((var, start_val, end_val, body_start, end_pos, alias))
}

fn input_to_str<'a>(bytes: &'a [u8]) -> &'a str {
    unsafe { std::str::from_utf8_unchecked(bytes) }
}

fn find_word(bytes: &[u8], start: usize, word: &str) -> Option<usize> {
    let mut pos = start;
    let wb = word.as_bytes();
    while pos < bytes.len() {
        if bytes[pos] == b'"' || bytes[pos] == b'\'' {
            let quote = bytes[pos];
            pos += 1;
            while pos < bytes.len() && bytes[pos] != quote {
                if bytes[pos] == b'\\' {
                    pos += 1;
                }
                pos += 1;
            }
            pos += 1;
            continue;
        }
        // Skip comments
        if bytes[pos] == b'-' && pos + 1 < bytes.len() && bytes[pos + 1] == b'-' {
            pos = find_line_end(bytes, pos) + 1;
            continue;
        }
        if pos + wb.len() <= bytes.len() && &bytes[pos..pos + wb.len()] == wb {
            // Check word boundary (not preceded by alphanumeric/underscore)
            let prev_ok = pos == 0 || !bytes[pos - 1].is_ascii_alphanumeric() && bytes[pos - 1] != b'_';
            if prev_ok {
                return Some(pos);
            }
        }
        pos += 1;
    }
    None
}

fn find_word_at_level(bytes: &[u8], start: usize, word: &str, level: usize) -> Option<usize> {
    // For simple cases, 'end' is just a word on its own line
    // We look for `end` not inside nested do/end blocks
    let mut depth = 0i32;
    let mut pos = start;
    let _wb = word.as_bytes();
    while pos < bytes.len() {
        // Skip strings
        if bytes[pos] == b'"' || bytes[pos] == b'\'' {
            let quote = bytes[pos];
            pos += 1;
            while pos < bytes.len() && bytes[pos] != quote {
                if bytes[pos] == b'\\' {
                    pos += 1;
                }
                pos += 1;
            }
            pos += 1;
            continue;
        }
        // Skip comments
        if bytes[pos] == b'-' && pos + 1 < bytes.len() && bytes[pos + 1] == b'-' {
            pos = find_line_end(bytes, pos) + 1;
            continue;
        }
        if bytes[pos] == b'{' || bytes[pos] == b'(' {
            depth += 1;
            pos += 1;
            continue;
        }
        if bytes[pos] == b'}' || bytes[pos] == b')' {
            depth -= 1;
            pos += 1;
            continue;
        }
        if depth >= level as i32 {
            if pos + 2 < bytes.len() && &bytes[pos..pos + 3] == b"end" {
                // Check word boundary
                let prev_ok = pos == 0
                    || !bytes[pos - 1].is_ascii_alphanumeric() && bytes[pos - 1] != b'_';
                let after = pos + 3;
                let next_ok = after >= bytes.len()
                    || !bytes[after].is_ascii_alphanumeric() && bytes[after] != b'_';
                if prev_ok && next_ok {
                    return Some(pos);
                }
            }
        }
        pos += 1;
    }
    None
}

fn parse_bind_body(body: &str, category: &str) -> Option<BindEntry> {
    let body = body.trim();

    // Split by top-level commas (not inside parens, braces, strings, or tables)
    // We need to handle that `hl.dsp.focus({ direction = dir })` contains commas inside braces
    let args = split_top_level_commas(body);

    if args.len() < 3 {
        return None;
    }

    let keys_expr = args[0].trim();
    let action_expr = args[1].trim();
    let options_expr = args[2..].join(","); // Rejoin in case of extra commas

    let keys = resolve_keys(keys_expr);
    let description = extract_description(&options_expr);
    let cmd = extract_cmd(action_expr);

    if keys.is_empty() {
        return None;
    }

    Some(BindEntry {
        category: category.to_string(),
        keys,
        description: description.unwrap_or_default(),
        cmd,
    })
}

fn split_top_level_commas(s: &str) -> Vec<String> {
    let mut parts = Vec::new();
    let mut depth_paren = 0i32;
    let mut depth_brace = 0i32;
    let mut depth_bracket = 0i32;
    let mut start = 0;
    let bytes = s.as_bytes();
    let mut i = 0;

    while i < bytes.len() {
        match bytes[i] {
            b'(' => depth_paren += 1,
            b')' => depth_paren -= 1,
            b'{' => depth_brace += 1,
            b'}' => depth_brace -= 1,
            b'[' => depth_bracket += 1,
            b']' => depth_bracket -= 1,
            b'"' | b'\'' => {
                let quote = bytes[i];
                i += 1;
                while i < bytes.len() && bytes[i] != quote {
                    if bytes[i] == b'\\' {
                        i += 1;
                    }
                    i += 1;
                }
            }
            b',' if depth_paren == 0 && depth_brace == 0 && depth_bracket == 0 => {
                parts.push(s[start..i].to_string());
                start = i + 1;
            }
            _ => {}
        }
        i += 1;
    }

    if start < s.len() {
        parts.push(s[start..].to_string());
    }

    parts
}

fn resolve_keys(expr: &str) -> String {
    // Replace known variables
    let s = expr
        .replace("mainMod", "SUPER")
        .replace("altMod", "ALT")
        .trim()
        .to_owned();

    // Handle Lua string concatenation: "a" .. "b" -> "ab"
    // Split by " .. " and concatenate the string parts
    let parts: Vec<&str> = s.split(" .. ").collect();
    let mut result = String::new();
    for part in parts {
        let trimmed = part.trim();
        // Remove surrounding quotes
        let inner = trimmed
            .strip_prefix('"')
            .and_then(|s| s.strip_suffix('"'))
            .or_else(|| {
                trimmed
                    .strip_prefix('\'')
                    .and_then(|s| s.strip_suffix('\''))
            })
            .unwrap_or(trimmed);
        result.push_str(inner);
    }

    result
}

fn extract_description(options_expr: &str) -> Option<String> {
    let desc_idx = options_expr.find("description = ")?;
    let after_eq = &options_expr[desc_idx + 14..];

    let mut depth_brace = 0i32;
    let mut end = 0;
    let bytes = after_eq.as_bytes();

    while end < bytes.len() {
        match bytes[end] {
            b'{' => depth_brace += 1,
            b'}' => {
                if depth_brace <= 0 {
                    break;
                }
                depth_brace -= 1;
            }
            b',' if depth_brace <= 0 => break,
            b'"' | b'\'' => {
                let quote = bytes[end];
                end += 1;
                while end < bytes.len() && bytes[end] != quote {
                    if bytes[end] == b'\\' {
                        end += 1;
                    }
                    end += 1;
                }
            }
            _ => {}
        }
        end += 1;
    }

    let value_expr = after_eq[..end].trim();
    let resolved = resolve_keys(value_expr);
    if !resolved.is_empty() {
        Some(resolved)
    } else {
        None
    }
}

fn extract_cmd(action_expr: &str) -> Option<String> {
    // Look for hl.dsp.exec_cmd("...")
    let trimmed = action_expr.trim();
    if let Some(start) = trimmed.find("hl.dsp.exec_cmd(") {
        let after = &trimmed[start + 16..];
        // Find the matching paren
        let bytes = after.as_bytes();
        let mut depth = 1;
        let mut pos = 0;
        let mut cmd_start = None;
        let mut cmd_end = None;

        while pos < bytes.len() {
            match bytes[pos] {
                b'(' => depth += 1,
                b')' => {
                    depth -= 1;
                    if depth == 0 {
                        if let (Some(cs), Some(ce)) = (cmd_start, cmd_end) {
                            return Some(after[cs..ce].to_string());
                        }
                        return None;
                    }
                }
                b'"' | b'\'' => {
                    let quote = bytes[pos];
                    if depth == 1 {
                        // This is the command string
                        cmd_start = Some(pos + 1);
                        pos += 1;
                        while pos < bytes.len() && bytes[pos] != quote {
                            if bytes[pos] == b'\\' {
                                pos += 1;
                            }
                            pos += 1;
                        }
                        cmd_end = Some(pos);
                    } else {
                        pos += 1;
                        while pos < bytes.len() && bytes[pos] != quote {
                            if bytes[pos] == b'\\' {
                                pos += 1;
                            }
                            pos += 1;
                        }
                    }
                }
                _ => {}
            }
            pos += 1;
        }
    }
    None
}
