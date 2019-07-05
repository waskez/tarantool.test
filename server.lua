local http = require('http.server')
local json = require("json")
local log = require('log')

local function unauthorized()
    return {
        status = 401,
        headers = { ['content-type'] = 'application/json' },
        body = json.encode({ message='Piekļuve liegta' })            
    }
end

local function authorize(req)
    local apikey = req.headers['x-apikey']

    if apikey == nil then
        log.error('[%s] Nav norādīts ApiKey', req.peer.host)
        return unauthorized()
    end

    local client = box.execute("SELECT * FROM clients WHERE apikey=?", { apikey })
    
    if client.rows[1] == nil then
        log.error('[%s] ApiKey %s neeksistē', req.peer.host, apikey)
        return unauthorized()
    end

    if client.rows[1][3] == 0 then
        log.error('[%s] Klients %s ir atspējots', req.peer.host, client.rows[1][2])
        return unauthorized()
    end

    return { 
        status = 200, 
        client = client.rows[1] 
    }
end

local function home_handler(req)
    local auth_result = authorize(req)
    if auth_result.status ~= 200 then
        return auth_result
    end
    local result = { dati = auth_result }
    local resp = req:render({ json = result })
    return resp
end

local httpd = http.new('localhost', 8080, { log_requests = false })
httpd:route({ path = '/', method = 'GET' }, home_handler)
httpd:start()