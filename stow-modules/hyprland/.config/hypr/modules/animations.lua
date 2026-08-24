-- Animation curves (https://easings.net/) + animation config.
--
-- Each curve is a cubic-bezier easing function. CSS syntax
-- cubic-bezier(x1, y1, x2, y2) maps to points = { {x1, y1}, {x2, y2} }.
-- Reference a curve by name with hl.animation({ ..., bezier = "name" }).

-- Sine
hl.curve("easeInSine", { type = "bezier", points = { { 0.12, 0 }, { 0.39, 0 } } })
hl.curve("easeOutSine", { type = "bezier", points = { { 0.61, 1 }, { 0.88, 1 } } })
hl.curve("easeInOutSine", { type = "bezier", points = { { 0.37, 0 }, { 0.63, 1 } } })

-- Quad
hl.curve("easeInQuad", { type = "bezier", points = { { 0.11, 0 }, { 0.5, 0 } } })
hl.curve("easeOutQuad", { type = "bezier", points = { { 0.5, 1 }, { 0.89, 1 } } })
hl.curve("easeInOutQuad", { type = "bezier", points = { { 0.45, 0 }, { 0.55, 1 } } })

-- Cubic
hl.curve("easeInCubic", { type = "bezier", points = { { 0.32, 0 }, { 0.67, 0 } } })
hl.curve("easeOutCubic", { type = "bezier", points = { { 0.33, 1 }, { 0.68, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0 }, { 0.35, 1 } } })

-- Quart
hl.curve("easeInQuart", { type = "bezier", points = { { 0.5, 0 }, { 0.75, 0 } } })
hl.curve("easeOutQuart", { type = "bezier", points = { { 0.25, 1 }, { 0.5, 1 } } })
hl.curve("easeInOutQuart", { type = "bezier", points = { { 0.76, 0 }, { 0.24, 1 } } })

-- Quint
hl.curve("easeInQuint", { type = "bezier", points = { { 0.64, 0 }, { 0.78, 0 } } })
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.22, 1 }, { 0.36, 1 } } })
hl.curve("easeInOutQuint", { type = "bezier", points = { { 0.83, 0 }, { 0.17, 1 } } })

-- Expo
hl.curve("easeInExpo", { type = "bezier", points = { { 0.7, 0 }, { 0.84, 0 } } })
hl.curve("easeOutExpo", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })
hl.curve("easeInOutExpo", { type = "bezier", points = { { 0.87, 0 }, { 0.13, 1 } } })

-- Circ
hl.curve("easeInCirc", { type = "bezier", points = { { 0.55, 0 }, { 1, 0.45 } } })
hl.curve("easeOutCirc", { type = "bezier", points = { { 0, 0.55 }, { 0.45, 1 } } })
hl.curve("easeInOutCirc", { type = "bezier", points = { { 0.85, 0 }, { 0.15, 1 } } })

-- Back (overshoot)
hl.curve("easeInBack", { type = "bezier", points = { { 0.36, 0 }, { 0.66, -0.56 } } })
hl.curve("easeOutBack", { type = "bezier", points = { { 0.34, 1.56 }, { 0.64, 1 } } })
hl.curve("easeInOutBack", { type = "bezier", points = { { 0.68, -0.6 }, { 0.32, 1.6 } } })

-- Master switch (was animations:enabled in hl.config).
hl.config({ animations = { enabled = true } })

-- Animation defaults. speed is in deciseconds (1 = 100ms).
-- Pick any curve defined above by name.
hl.animation({ leaf = "windows", enabled = true, speed = 4, bezier = "easeOutCubic" })
hl.animation({ leaf = "fade", enabled = true, speed = 4, bezier = "easeOutCubic" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "easeInOutCubic" })
