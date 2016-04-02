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

class ZeroConfig
  #needs a working ZeroFrame instance
  constructor: (@zf) ->
    #@log = @zf.log
    #@cmd = @zf.cmd
    #@site_info = @zf.site_info


  defaultConfig: =>
    @config = { "license": 0, "encrypted": true }
    @zf.log "config", "Default Configuration loaded."

  load: =>
    #we encrypt with user key -> therefore need an account
    if not @zf.site_info.cert_user_id  # No account selected, display error
      @zf.cmd "wrapperNotification", ["info", "Please, select your account."]
      @defaultConfig()
      return false
    inner_path = "data/users/#{@zf.site_info.auth_address}/config.encrypted.json"
    @zf.cmd "fileGet", {"inner_path": inner_path, "required": false}, (data) =>
      if data  # Parse and encrypt if already exits
        @zf.cmd "eciesDecrypt", [data], (decrypted) =>
          @config = JSON.parse(decrypted)
          @zf.log "config", "Configuration successfully loaded."
      else  # Does not exist yet, use default data
        @defaultConfig()

  store: =>
    inner_path = "data/users/#{@zf.site_info.auth_address}/config.encrypted.json"
    json_raw = unescape(encodeURIComponent(JSON.stringify(@config, undefined, '\t')))
    #encrypt json and write file
    @zf.cmd "eciesEncrypt", [json_raw], (encrypted) =>
      @zf.cmd "fileWrite", [inner_path, btoa(encrypted)], (res) =>
          if res == "ok"
            @zf.log "config", "Configuration successfully stored."
          else
            @zf.cmd "wrapperNotification", ["error", "File write error: #{res}"]

  #route: (cmd, message) ->
    #if cmd == "setSiteInfo"
      #@site_info = message.params  # Save site info data to allow access it later

  #onOpenWebsocket: (e) =>
    #@cmd "siteInfo", {}, (site_info) =>
      #@site_info = site_info  # Save site info data to allow access it later
      #@load()

#window.Config = new ZeroConfig();
