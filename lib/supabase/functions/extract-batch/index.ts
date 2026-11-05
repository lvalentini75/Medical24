import { createHandler, defaultDeps } from "./handler.ts";

Deno.serve(createHandler(defaultDeps()));
