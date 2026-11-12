extends RefCounted
## Everything a player can own or buy: planet skins, hats, trails, moon
## styles and coin packs. Add an entry to a list and it shows up in the shop.
## Ids start with their kind ("skin_", "hat_", "trail_", "moon_", "pack_").

# Skins. The free ones only differ in colour. Paid skins trade one small
# advantage for one small drawback, so no skin is simply the best.
# Possible stats:  speed, pull, dash_cd, shield, orbit, coins  (multipliers)
#                  max_moons, start_moons, dust_per_moon       (added)
const SKINS: Array[Dictionary] = [
	{"id": "skin_pink", "name": "Bubblegum", "price": 0, "color": Color("ff7eb6"), "style": "plain"},
	{"id": "skin_orange", "name": "Tangerine", "price": 0, "color": Color("ffa552"), "style": "plain"},
	{"id": "skin_yellow", "name": "Banana", "price": 0, "color": Color("ffd93d"), "style": "plain"},
	{"id": "skin_green", "name": "Lime", "price": 0, "color": Color("6be39a"), "style": "plain"},
	{"id": "skin_teal", "name": "Minty", "price": 0, "color": Color("4dd9d0"), "style": "plain"},
	{"id": "skin_blue", "name": "Sky", "price": 0, "color": Color("5cb8ff"), "style": "plain"},
	{"id": "skin_purple", "name": "Grape", "price": 0, "color": Color("a98bff"), "style": "plain"},
	{"id": "skin_coral", "name": "Coral", "price": 0, "color": Color("ff7b6b"), "style": "plain"},
	{"id": "skin_comet", "name": "Comet", "price": 600, "color": Color("9fdcff"), "style": "comet",
		"good": "+8% speed", "bad": "1 moon fewer",
		"stats": {"speed": 1.08, "max_moons": -1}},
	{"id": "skin_boulder", "name": "Boulder", "price": 600, "color": Color("c2ab8e"), "style": "rocky",
		"good": "1 extra moon", "bad": "-7% speed",
		"stats": {"max_moons": 1, "speed": 0.93}},
	{"id": "skin_bubble", "name": "Bubble", "price": 650, "color": Color("86f0e2"), "style": "bubble",
		"good": "+40% shield time", "bad": "Moons 12% slower",
		"stats": {"shield": 1.4, "orbit": 0.88}},
	{"id": "skin_twister", "name": "Twister", "price": 650, "color": Color("c596ff"), "style": "swirl",
		"good": "Moons 18% faster", "bad": "5 stardust per moon",
		"stats": {"orbit": 1.18, "dust_per_moon": 1}},
	{"id": "skin_magnet", "name": "Magnet", "price": 700, "color": Color("ff6464"), "style": "magnet",
		"good": "+40% stardust pull", "bad": "Dash 15% slower",
		"stats": {"pull": 1.4, "dash_cd": 1.15}},
	{"id": "skin_zippy", "name": "Zippy", "price": 700, "color": Color("ffe45c"), "style": "zippy",
		"good": "Dash 20% faster", "bad": "Starts with 1 moon",
		"stats": {"dash_cd": 0.8, "start_moons": -1}},
	{"id": "skin_goldie", "name": "Goldie", "price": 900, "color": Color("ffc83d"), "style": "gold",
		"good": "+15% coins", "bad": "-5% speed",
		"stats": {"coins": 1.15, "speed": 0.95}},
]

# Cosmetics: looks only, no effect on the game.
const HATS: Array[Dictionary] = [
	{"id": "hat_none", "name": "No hat", "price": 0},
	{"id": "hat_bow", "name": "Bow", "price": 150},
	{"id": "hat_party", "name": "Party Hat", "price": 200},
	{"id": "hat_cat", "name": "Cat Ears", "price": 250},
	{"id": "hat_bobble", "name": "Bobble", "price": 250},
	{"id": "hat_flower", "name": "Daisy", "price": 250},
	{"id": "hat_top", "name": "Top Hat", "price": 350},
	{"id": "hat_halo", "name": "Halo", "price": 400},
]
const TRAILS: Array[Dictionary] = [
	{"id": "trail_none", "name": "No trail", "price": 0},
	{"id": "trail_bubbles", "name": "Bubbles", "price": 300},
	{"id": "trail_stars", "name": "Star Dust", "price": 350},
	{"id": "trail_rainbow", "name": "Rainbow", "price": 500},
]
const MOONS: Array[Dictionary] = [
	{"id": "moon_round", "name": "Round", "price": 0},
	{"id": "moon_donut", "name": "Donuts", "price": 300},
	{"id": "moon_star", "name": "Stars", "price": 350},
	{"id": "moon_gem", "name": "Gems", "price": 400},
]

# Real-money packs. The prices shown here are placeholders: a real store
# build shows the price Google Play reports for the player's country.
const PACKS: Array[Dictionary] = [
	{"id": "pack_small", "name": "600 coins", "coins": 600, "price": "$0.99", "blurb": "A handful"},
	{"id": "pack_medium", "name": "2,000 coins", "coins": 2000, "price": "$2.99", "blurb": "Most popular"},
	{"id": "pack_large", "name": "5,000 coins", "coins": 5000, "price": "$5.99", "blurb": "Best value"},
	{"id": "pack_no_ads", "name": "No Ads", "no_ads": true, "price": "$2.99", "blurb": "No more ads between rounds"},
]

const _COUNTRIES := "AF=Afghanistan;AL=Albania;DZ=Algeria;AD=Andorra;AO=Angola;AG=Antigua and Barbuda;AR=Argentina;AM=Armenia;AU=Australia;AT=Austria;AZ=Azerbaijan;BS=Bahamas;BH=Bahrain;BD=Bangladesh;BB=Barbados;BY=Belarus;BE=Belgium;BZ=Belize;BJ=Benin;BT=Bhutan;BO=Bolivia;BA=Bosnia and Herzegovina;BW=Botswana;BR=Brazil;BN=Brunei;BG=Bulgaria;BF=Burkina Faso;BI=Burundi;CV=Cabo Verde;KH=Cambodia;CM=Cameroon;CA=Canada;CF=Central African Republic;TD=Chad;CL=Chile;CN=China;CO=Colombia;KM=Comoros;CG=Congo;CD=DR Congo;CR=Costa Rica;HR=Croatia;CU=Cuba;CY=Cyprus;CZ=Czechia;DK=Denmark;DJ=Djibouti;DM=Dominica;DO=Dominican Republic;EC=Ecuador;EG=Egypt;SV=El Salvador;GQ=Equatorial Guinea;ER=Eritrea;EE=Estonia;SZ=Eswatini;ET=Ethiopia;FJ=Fiji;FI=Finland;FR=France;GA=Gabon;GM=Gambia;GE=Georgia;DE=Germany;GH=Ghana;GR=Greece;GD=Grenada;GT=Guatemala;GN=Guinea;GW=Guinea-Bissau;GY=Guyana;HT=Haiti;HN=Honduras;HK=Hong Kong;HU=Hungary;IS=Iceland;IN=India;ID=Indonesia;IR=Iran;IQ=Iraq;IE=Ireland;IL=Israel;IT=Italy;CI=Ivory Coast;JM=Jamaica;JP=Japan;JO=Jordan;KZ=Kazakhstan;KE=Kenya;KI=Kiribati;XK=Kosovo;KW=Kuwait;KG=Kyrgyzstan;LA=Laos;LV=Latvia;LB=Lebanon;LS=Lesotho;LR=Liberia;LY=Libya;LI=Liechtenstein;LT=Lithuania;LU=Luxembourg;MG=Madagascar;MW=Malawi;MY=Malaysia;MV=Maldives;ML=Mali;MT=Malta;MH=Marshall Islands;MR=Mauritania;MU=Mauritius;MX=Mexico;FM=Micronesia;MD=Moldova;MC=Monaco;MN=Mongolia;ME=Montenegro;MA=Morocco;MZ=Mozambique;MM=Myanmar;NA=Namibia;NR=Nauru;NP=Nepal;NL=Netherlands;NZ=New Zealand;NI=Nicaragua;NE=Niger;NG=Nigeria;KP=North Korea;MK=North Macedonia;NO=Norway;OM=Oman;PK=Pakistan;PW=Palau;PS=Palestine;PA=Panama;PG=Papua New Guinea;PY=Paraguay;PE=Peru;PH=Philippines;PL=Poland;PT=Portugal;PR=Puerto Rico;QA=Qatar;RO=Romania;RU=Russia;RW=Rwanda;KN=Saint Kitts and Nevis;LC=Saint Lucia;VC=Saint Vincent;WS=Samoa;SM=San Marino;ST=Sao Tome and Principe;SA=Saudi Arabia;SN=Senegal;RS=Serbia;SC=Seychelles;SL=Sierra Leone;SG=Singapore;SK=Slovakia;SI=Slovenia;SB=Solomon Islands;SO=Somalia;ZA=South Africa;KR=South Korea;SS=South Sudan;ES=Spain;LK=Sri Lanka;SD=Sudan;SR=Suriname;SE=Sweden;CH=Switzerland;SY=Syria;TW=Taiwan;TJ=Tajikistan;TZ=Tanzania;TH=Thailand;TL=Timor-Leste;TG=Togo;TO=Tonga;TT=Trinidad and Tobago;TN=Tunisia;TR=Turkey;TM=Turkmenistan;TV=Tuvalu;UG=Uganda;UA=Ukraine;AE=United Arab Emirates;GB=United Kingdom;US=United States;UY=Uruguay;UZ=Uzbekistan;VU=Vanuatu;VA=Vatican City;VE=Venezuela;VN=Vietnam;YE=Yemen;ZM=Zambia;ZW=Zimbabwe"


## "skin", "hat", "trail", "moon" or "pack".
static func kind_of(id: String) -> String:
	return id.get_slice("_", 0)


static func list_of(kind: String) -> Array[Dictionary]:
	match kind:
		"skin":
			return SKINS
		"hat":
			return HATS
		"trail":
			return TRAILS
		"moon":
			return MOONS
	return PACKS


## The catalog entry for an id (the first entry of its list if unknown).
static func item(id: String) -> Dictionary:
	var list := list_of(kind_of(id))
	for entry in list:
		if entry.id == id:
			return entry
	return list[0]


static func exists(id: String) -> bool:
	return item(id).id == id


## All countries as [code, name] pairs, sorted by name.
static func countries() -> Array:
	var out: Array = []
	for part in _COUNTRIES.split(";"):
		out.append([part.get_slice("=", 0), part.get_slice("=", 1)])
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
	return out


static func country_name(code: String) -> String:
	for part in _COUNTRIES.split(";"):
		if part.get_slice("=", 0) == code:
			return part.get_slice("=", 1)
	return ""
