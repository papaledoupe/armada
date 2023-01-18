narratives = narratives or {}

-- annoyingly have to have them all present in the source as direct imports because pdc
-- is doing something "clever" which means dynamic imports don't work
-- TODO: generate this.
narratives.all = {
    ['narratives/example'] = import('narratives/example'),
}
