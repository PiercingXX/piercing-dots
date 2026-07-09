-- Dynamic cursor plugin
if hl.plugin.dynamic_cursors then
    hl.config({
        plugin = {
            dynamic_cursors = {
                enabled = true,
                mode = "tilt",
                threshold = 1,
                rotate = {
                    length = 30,
                    offset = 10.0,
                },
                tilt = {
                    limit = 3000,
                    ["function"] = "negative_quadratic",
                },
                stretch = {
                    limit = 3000,
                    ["function"] = "quadratic",
                },
                shake = {
                    enabled = true,
                    nearest = true,
                    threshold = 6.0,
                    base = 4.0,
                    speed = 4.0,
                    influence = 0.0,
                    limit = 0.0,
                    timeout = 2000,
                    effects = false,
                    ipc = false,
                },
            },
        },
    })
end