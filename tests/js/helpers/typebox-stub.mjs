// Recording stand-in for the parts of "typebox" used by pi-five-tool-stack.ts:
// every constructor returns a plain descriptor so tests can assert the schema
// that a JSON-Schema input was translated into.
const node = (t, fields) => ({ t, ...fields });

export const Type = {
  Literal: (value) => node("Literal", { value }),
  Union: (items, options) => node("Union", { items, options }),
  Number: (options) => node("Number", { options }),
  Boolean: (options) => node("Boolean", { options }),
  String: (options) => node("String", { options }),
  Unknown: () => node("Unknown", {}),
  Array: (items, options) => node("Array", { items, options }),
  Optional: (inner) => node("Optional", { inner }),
  Object: (fields, options) => node("Object", { fields, options }),
  Record: (key, value, options) => node("Record", { key, value, options }),
};
