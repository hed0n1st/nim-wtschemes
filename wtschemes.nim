
when defined(cpu64):
  {.link: "resources/wtschemes64.res".}
else:
  {.link: "resources/wtschemes32.res".}

import
  os,
  docopt,
  json,
  strutils,
  strformat,
  httpclient,
  htmlparser,
  xmltree

const
  wtFolder = joinPath(
    getHomeDir(),
    "AppData\\Local\\Packages\\Microsoft.WindowsTerminal_8wekyb3d8bbwe\\LocalState"
  )
  wtProfiles = joinPath(
    wtFolder,
    "profiles.json"
  )
  wtSchemesUrl = "https://github.com/mbadolato/iTerm2-Color-Schemes/tree/master/windowsterminal"
  githubRawUrl = "https://raw.githubusercontent.com$1"

type
  Profiles = object
    names: seq[string]
    colorSchemes : seq[string]
    schemes: seq[string]
    schemesNode: JsonNode

  OnlineSchemes = object
    names: seq[string]
    hrefs: seq[string]

let doc = """
wtschemes: manage schemes in your windows terminal profiles.

Usage:
  wtschemes profiles
  wtschemes schemes [--local | --online]
  wtschemes search <name>
  wtschemes install <name>
  wtschemes remove <name>
  wtschemes set <profile> <scheme>

Options:
  -l, --local      List installed schemes.
  -o, --online     List online available schemes.
"""

let args = docopt(doc, version="0.1")

let client = newHttpClient()

proc parseProfiles(): Profiles =
  let data = parseFile(wtProfiles)
  let schemes = data["schemes"]

  result.schemesNode = schemes

  for scheme in schemes:
    result.schemes.add(scheme["name"].getStr())

  let profiles = data["profiles"]["list"]
  for profile in profiles:
    result.names.add(profile["name"].getStr())
    try:
      result.colorSchemes.add(profile["colorScheme"].getStr())
    except KeyError:
      result.colorSchemes.add("none")

proc onlineSchemes(): OnlineSchemes =
  let html = client.getContent(wtSchemesUrl)
  let data = parseHtml(html)

  for td in data.findAll("td"):
    if td.attr("class") == "content":
      for a in td.findAll("a"):
        var name = a.innerText
        removeSuffix(name, ".json")
        var href = githubRawUrl % [a.attr("href").replace("/blob/", "/")]
        result.names.add(name)
        result.hrefs.add(href)

proc updateProfiles(data: JsonNode) =
  copyFile(wtProfiles, joinPath(wtFolder, "profiles.json.bck"))
  var f = open(wtProfiles, fmWrite)
  defer: f.close()
  f.write(pretty(data, indent = 4))

proc installScheme(iScheme: string) =
  let data = parseFile(wtProfiles)
  let schemes = onlineSchemes()
  let profiles = parseProfiles()

  for scheme in profiles.schemes:
    if scheme == iScheme:
      echo fmt"{iScheme} seems already installed!"
      quit()

    var href: string
    for n, name in schemes.names.pairs:
      if iScheme == name:
        href = schemes.hrefs[n]
        break

    case href
    of "":
      echo fmt"{iScheme} not found online!"
      quit()
    else:
      let newData = parseJson(client.getContent(href))
      data["schemes"].add(newData)
      updateProfiles(data)
      echo fmt"{iScheme} correctly added! You can now use set <profile> {iScheme}"

proc removeScheme(rScheme: string) =
  let data = parseFile(wtProfiles)
  let profiles = parseProfiles()

  for scheme in profiles.schemes:
    if scheme == rScheme:

      var newSchemes = newJArray() #: JsonNode = %* []
      for n in profiles.schemesNode:
        if n["name"].getStr() != rScheme:
          newSchemes.add(n)

      data["schemes"] = newSchemes
      updateProfiles(data)
      echo fmt"{rScheme} correctly removed!"

proc setColorScheme(profile: string, scheme: string) =
  let profiles = parseProfiles()

  if not profiles.names.contains(profile):
    echo "error: profile not found"
    quit()

  if not profiles.schemes.contains(scheme):
    echo "error: scheme not installed"
    quit()

  let data = parseFile(wtProfiles)

  var p = 0
  for list in data["profiles"]["list"]:
    if list["name"].getStr() == profile:
      data["profiles"]["list"][p]["colorScheme"] = newJString(scheme)
    inc p
  updateProfiles(data)
  echo fmt"{profile} new colorScheme: {scheme}. Enjoy!"

when isMainModule:

  if args["profiles"]:
    let profiles = parseProfiles()
    for p, profile in profiles.names.pairs:
      echo "profile: " & profile & " - colorscheme: " & profiles.colorSchemes[p]

  if args["schemes"] and args["--local"]:
    let profiles = parseProfiles()
    for scheme in profiles.schemes:
      echo scheme

  if args["schemes"] and args["--online"]:
    let schemes = onlineSchemes()
    for name in schemes.names:
      echo name

  if args["search"]:
    let search = $args["<name>"]
    let schemes = onlineSchemes()
    for n, name in schemes.names.pairs:
      if name.contains(search):
        let href = schemes.hrefs[n]
        echo fmt"name: {name} - url: {href}"

  if args["install"]:
    let scheme = $args["<name>"]
    installScheme(scheme)

  if args["remove"]:
    let scheme = $args["<name>"]
    removeScheme(scheme)

  if args["set"]:
    let profile = $args["<profile>"]
    let scheme = $args["<scheme>"]
    setColorScheme(profile, scheme)
