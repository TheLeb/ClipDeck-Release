extends RefCounted
## Checks the names players type in. This is a basic filter that runs on the
## device: it limits length and characters and rejects common rude words.
## An online leaderboard additionally needs a check on the server.

const MAX_LENGTH := 12
const MIN_LENGTH := 2

# Rude words, stored scrambled (ROT13) so they are not readable in the code.
const _BLOCKED: Array[String] = [
	"shpx", "fuvg", "ovgpu", "phag", "qvpx", "pbpx", "chffl", "nffubyr",
	"onfgneq", "fyhg", "juber", "avtt", "sntt", "ergneq", "encr", "anmv",
	"uvgyre", "cravf", "intvan", "cbea", "frkl", "nany", "gvgf", "obbo",
	"jnax", "gjng", "cvff", "qvyqb", "wrexbss", "oybjwbo", "unaqwbo", "phz",
	"frk", "snt", "xxx", "fpurvff", "fpurvf", "nefpu", "svpx", "sbgmr",
	"uher", "jvpuf", "fpuynzcr", "ahggr", "fpujhpugry", "fcnfg", "zvfftroheg", "uherafbua",
	"xnanxr", "artre", "fpujnam", "gvggra",
	"qvpxurnq", "pbpxfhpx",
]
# These sit inside many harmless names (Grape, Dickens, Canal), so they only
# count when they are a whole word.
const _WHOLE_WORD_ONLY: Array[String] = ["nany", "encr", "qvpx", "pbpx"]
const _LOOKALIKES := {"0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "@": "a", "$": "s", "!": "i"}


## Removes characters that are not allowed and trims the name to length.
static func clean(raw: String) -> String:
	var out := ""
	for ch in raw.strip_edges():
		var code := ch.unicode_at(0)
		var is_letter := ch.to_lower() != ch.to_upper() and code < 0x250
		var is_digit := code >= 48 and code <= 57
		if is_letter or is_digit or ch == " " or ch == "_" or ch == "-":
			out += ch
	while out.contains("  "):
		out = out.replace("  ", " ")
	return out.substr(0, MAX_LENGTH).strip_edges()


## True if the (already cleaned) name may be used.
static func is_ok(name: String) -> bool:
	if name.replace(" ", "").length() < MIN_LENGTH:
		return false
	var plain := ""       # letters only, look-alike digits turned into letters
	for ch in name.to_lower():
		var c: String = _LOOKALIKES.get(ch, ch)
		if c.to_lower() != c.to_upper():
			plain += c
	var squeezed := ""    # "heeello" -> "helo"
	for ch in plain:
		if not squeezed.ends_with(ch):
			squeezed += ch
	var words := name.to_lower().replace("_", " ").replace("-", " ").split(" ", false)
	for scrambled in _BLOCKED:
		var bad := _unscramble(scrambled)
		if bad.length() <= 3 or scrambled in _WHOLE_WORD_ONLY:
			if plain == bad or bad in words:
				return false
		elif plain.contains(bad) or squeezed.contains(bad):
			return false
	return true


static func _unscramble(text: String) -> String:
	var out := ""
	for ch in text:
		var code := ch.unicode_at(0)
		if code >= 97 and code <= 122:
			code = (code - 97 + 13) % 26 + 97
		out += String.chr(code)
	return out
