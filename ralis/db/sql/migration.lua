-- init and get db
require 'ralis.core.init'

-- settings
local migrations_table_name = 'schema_migrations'

local migrations_table_sql = [[
CREATE TABLE ]] .. migrations_table_name .. [[ (
    version varchar(14) NOT NULL,
    PRIMARY KEY (version)
);
]]

local function ensure_schema_migrations_exists(db)
    local tables = db:tables()
    -- chech if exists
    for _, table_name in pairs(tables) do
        if table_name == migrations_table_name then
            -- table found, exit
            return
        end
    end
    -- table does not exist, create
    db:execute(migrations_table_sql)
end

local function version_already_run(db, version)
    local res = db:execute("SELECT version FROM " .. migrations_table_name .. " WHERE version = '" .. version .. "';")
    return #res > 0
end

local function add_version(db, version)
    db:execute("INSERT INTO " .. migrations_table_name .. " (version) VALUES ('" .. version .. "');")
end

local function remove_version(db, version)
    db:execute("DELETE FROM " .. migrations_table_name .. " WHERE version = '" .. version .. "';")
end

local function version_from(module_name)
    return string.match(module_name, ".*/(.*)")
end


local Migration = {}

function Migration.run(ngx, direction, module_name)
    -- load migration module
    local migration_module = require(module_name)
    local db = migration_module.db
    local version = version_from(module_name)

    ensure_schema_migrations_exists(db)

    if direction == "up" then
        -- exit if version already run
        if version_already_run(db, version) == true then return ngx.exit(202) end

        -- run up migration
        migration_module.up()

        -- add migration
        add_version(db, version)

        return ngx.exit(ngx.HTTP_CREATED)

    elseif direction == "down" then
        -- exit if version not run
        if version_already_run(db, version) == false then return ngx.exit(ngx.HTTP_NOT_FOUND) end

        -- run down migration
        migration_module.down()

        -- remove migration
        remove_version(db, version)

        return ngx.exit(ngx.HTTP_OK)
    end
end

return Migration
