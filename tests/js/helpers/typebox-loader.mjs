// Module-resolution hook for tests: the "typebox" package is a dependency of the
// Pi host and is not installed in this repository, so map it to a recording stub.
const stub = new URL("./typebox-stub.mjs", import.meta.url).href;

export async function resolve(specifier, context, nextResolve) {
  if (specifier === "typebox") return { url: stub, shortCircuit: true };
  return nextResolve(specifier, context);
}
