##PastePr - encrypted paste zite
##Copyright (C) 2016 by Basxto
#
##This program is free software: you can redistribute it and/or modify
##it under the terms of the GNU General Public License as published by
##the Free Software Foundation, either version 3 of the License, or
##(at your option) any later version.
#
##This program is distributed in the hope that it will be useful,
##but WITHOUT ANY WARRANTY; without even the implied warranty of
##MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##GNU General Public License for more details.
#
##You should have received a copy of the GNU General Public License
##along with this program.  If not, see <http://www.gnu.org/licenses/>.

class Paste extends ZeroFrame
  licenses: [
    "GPLv3",
    "GPLv2",
    "AGPLv3",
    "Apache License 2.0",
    "MPL 2.0",
    "CC0 1.0 Universal",
    "CC BY 4.0 International",
    "CC BY 3.0 International",
    "CC BY-SA 4.0 International",
    "CC BY-SA 3.0 International",
    "LGPLv3",
    "LGPLv2.1",
    "FDLv1.3",
    "FDLv1.2",
    "X11 License",
    "Artistic License 2.0",
    "custom"
  ]
  init: ->
    @cmd "wrapperNotification", ["info", "Welcome to PastePrimitively"]
    for license in @licenses
      document.getElementById("license").add(new Option(license))
    document.getElementById("license").selectedIndex = 0
    #@cmd "innerLoaded", true
  selectUser: =>
    this.cmd "certSelect", [["zeroid.bit","zeroverse.bit"]]
    return false
  routeUrl: (url, hash) ->
    # http://127.0.0.1:43110/ZeroPolls.bit/?Poll:15-1Mk5sVKeCrwMc3wSD11jM7DZTiqF5D9BaD
    @log "Routing url:", url
    if match = url.match /Paste:([0-9]+-[^#&]*)/
        @log "Matched Paste:", match[1]
        @log "Key:", hash
        #@vm.showPoll = match[1]
        id = match[1].split('-')
        iv = ""
        if match = hash.match /iv:([^#&]*)/
          iv = match[1]
        key = ""
        if match = hash.match /key:([^#&]*)/
          key = match[1]
        @load(id[0], id[1], iv, key)
    #else
        #@vm.showPoll = null
  load: (id, address, iv, key) ->
    query = """
      SELECT paste.*, keyvalue.value AS cert_user_id, data_json.directory AS dir FROM paste
      LEFT JOIN json AS data_json USING (json_id)
      LEFT JOIN json AS content_json ON (
        data_json.directory = content_json.directory AND content_json.file_name = 'content.json'
      )
      LEFT JOIN keyvalue ON (keyvalue.key = 'cert_user_id' AND keyvalue.json_id = content_json.json_id)
      WHERE id = '#{id}' AND dir = 'users/1#{address}'
      ORDER BY id
    """
    @log "You requested:", "id:#{id};address:#{address};iv:#{iv};key:#{key};"
  #SELECT * FROM paste LEFT JOIN json USING(json_id) WHERE date_added = '1458400956596' AND directory = 'users/1PVcdu7USZH2kHMETbqDYLPjJZKCDWM52k' ORDER BY date_added
    #@log "sql", "SELECT * FROM paste LEFT JOIN json USING(json_id) LEFT JOIN keyvalue USING(json_id) WHERE date_added = '" +date+"' AND directory = 'users/1"+address+"' ORDER BY date_added"
    #@cmd "dbQuery", ["SELECT * FROM paste LEFT JOIN json USING(json_id) WHERE date_added = '" +date+"' AND directory = 'users/1"+address+"' ORDER BY date_added"], (pastes) =>
    @log "sql", query
    @cmd "dbQuery", [query], (pastes) =>
      @log "sql return", pastes
      if pastes && pastes.length == 1
        paste = pastes[0]
        document.getElementById("paste").value = paste.content
        document.getElementById("title").value = paste.title
        document.getElementById("license").selectedIndex = paste.license
        document.getElementById("author").innerHTML = " by #{paste.cert_user_id}";
        if paste.encrypted == 1
          document.getElementById("encrypt").checked = true
          if iv != "" && key != ""
            @cmd "aesDecrypt", [iv, paste.title, key], (decrypted) =>
              @log "decrypted: ", decrypted
              document.getElementById("title").value = decrypted
            @cmd "aesDecrypt", [iv, paste.content, key], (decrypted) =>
              @log "decrypted: ", decrypted
              document.getElementById("paste").value = decrypted
          else
            @cmd "wrapperNotification", ["error", "Can't encrypt, key or iv missing."]
      else
        @cmd "wrapperNotification", ["error", "Can't find requested paste."]

  route: (cmd, message) ->
    if cmd == "setSiteInfo"
      if message.params.cert_user_id
        document.getElementById("select_user").innerHTML = message.params.cert_user_id
      else
         document.getElementById("select_user").innerHTML = "Sign in..."
      @site_info = message.params  # Save site info data to allow access it later

  onOpenWebsocket: (e) =>
    @cmd "siteInfo", {}, (site_info) =>
    # Update currently selected username
      if site_info.cert_user_id
        document.getElementById("select_user").innerHTML = site_info.cert_user_id
      @site_info = site_info  # Save site info data to allow access it later
      @log "location:", window.location.search
      @log "hash:", window.location.hash
      @routeUrl(window.location.search.substring(1),window.location.hash.substring(1))
      @cmd "innerLoaded", true
      if not @config
        @config = new ZeroConfig(@);
        @config.load()

  crpytUpload: =>
    if document.getElementById("encrypt").checked
      #encrypted = @aesEncrypt document.getElementById("paste").value
      @cmd "aesEncrypt", [document.getElementById("title").value], (encrypted) =>
        @log "encrypted: ", encrypted
        document.getElementById("title").value = encrypted[2];
        @cmd "aesEncrypt", [document.getElementById("paste").value, encrypted[0], encrypted[1]], (encrypted) =>
          @log "encrypted: ", encrypted
          @upload encrypted
    else
      @upload false

  upload: (encrypted) =>
    if not Pastepr.site_info.cert_user_id  # No account selected, display error
      Pastepr.cmd "wrapperNotification", ["info", "Please, select your account."]
      return false

    inner_path = "data/users/#{@site_info.auth_address}/data.json"  # This is our data file

    # Load our current messages
    @cmd "fileGet", {"inner_path": inner_path, "required": false}, (data) =>
      if data  # Parse if already exits
        data = JSON.parse(data)
      else  # Not exits yet, use default data
        data = { "paste": [] }

      now = (+new Date)
      text = document.getElementById("paste").value
      if encrypted
        text = encrypted[2]

#      if document.getElementById("encrypt").checked
#        #encrypted = @aesEncrypt document.getElementById("paste").value
#        @cmd "aesEncrypt", [text], (res) => 
#          text = res[2]
#          encrypted = res

      if not data.next_id?
        data.next_id = 0

      # Add the message to data
      data.paste.push({
        "id": data.next_id++,
        "title": document.getElementById("title").value,
        "content": text,
        "license": document.getElementById("license").selectedIndex,
        "encrypted": !!encrypted
        "date_added": now
      })

      # Encode data array to utf8 json text
      json_raw = unescape(encodeURIComponent(JSON.stringify(data, undefined, '\t')))

      # Write file to disk
      @cmd "fileWrite", [inner_path, btoa(json_raw)], (res) =>
        if res == "ok"
          # Publish the file to other users
          @cmd "sitePublish", {"inner_path": inner_path}, (res) =>
            document.getElementById("paste").value = text  # Reset the message input
            url = "http://127.0.0.1:43110/1PasteprZgQiYNcGGrAYrTwmTxsAAqxx6A?Paste:#{data.next_id-1}-#{@site_info.auth_address.substr(1)}"
            if encrypted
              #url += "&key:#{encrypted[1]}##{encrypted[0]}"
              url += "#iv:#{encrypted[1]}&key:#{encrypted[0]}"
            document.getElementById("permalink").innerHTML = "Your permalink: <a href=\"#{url}\">#{url}</a>";
        else
          @cmd "wrapperNotification", ["error", "File write error: #{res}"]

    return false


window.Pastepr = new Paste();


window.onhashchange = (e) => # On hash change
  Pastepr.routeUrl(window.location.search.substring(1),window.location.hash.substring(1))
